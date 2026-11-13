-- 1. Constants & Locals
local addonName = ...
local isRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
local isForever = WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
-- Retail and Forever can hand us secret speeds; other Classic clients can't
local hasSecrets = isRetail or isForever
local C_PlayerInfo, GetUnitSpeed, UnitInVehicle = C_PlayerInfo, GetUnitSpeed, UnitInVehicle
local GetSpeedString
local format = format
local CreateFrame, UIParent, InCombatLockdown = CreateFrame, UIParent, InCombatLockdown
local floor, max = math.floor, math.max
local BASE_MOVEMENT_SPEED = BASE_MOVEMENT_SPEED or 7
local GetGlidingInfo = C_PlayerInfo and C_PlayerInfo.GetGlidingInfo
local AbbreviateNumbers = AbbreviateNumbers
local iconPath = "Interface\\Icons\\Inv_Pet_Speedy"
local categoryID

-- Default Settings
local defaults = {
    showFrame = true,
    locked = false,
    textAlign = "LEFT",
    background = false,
    fontSize = 16,
    position = { "CENTER", "UIParent", "CENTER", 0, 0 },
    fontFlag = "OUTLINE",
    fontFamily = "FRIZQT__.TTF",
    textColor = { r = 1, g = 1, b = 1, a = 1 },
    updateRate = 0.1,
    safeLDBInCombat = true,
}

-- 2. Helper Functions

if hasSecrets then
    -- Thanks Veyska on Curseforge, and NinjaRobot on the discord.
    -- See: https://warcraft.wiki.gg/wiki/API_AbbreviateNumbers
    -- Secret numbers can't do arithmetic, so AbbreviateNumbers does the scaling for us
    local SPEED_ABBREV_OPTIONS = {
        breakpointData = {
            {
                breakpoint = 0,
                abbreviation = "%",
                significandDivisor = 0.0699, --BASE_MOVEMENT_SPEED / 100, -- 0.07
                fractionDivisor = 1,
                abbreviationIsGlobal = false,
            },
        },
    }

    GetSpeedString = function()
        local unit = UnitInVehicle and UnitInVehicle("player") and "vehicle" or "player"
        local speed = GetUnitSpeed(unit)
        if GetGlidingInfo then
            local isGliding, _, fSpeed = GetGlidingInfo()
            if isGliding and fSpeed and fSpeed > 0 then
                speed = fSpeed
            end
        end

        return AbbreviateNumbers(speed, SPEED_ABBREV_OPTIONS)
    end
else -- Classic
    local function round(x) return floor(x + 0.5) end

    GetSpeedString = function()
        local unit = UnitInVehicle and UnitInVehicle("player") and "vehicle" or "player"
        local speed = GetUnitSpeed(unit)
        return format("%d%%", round(speed / BASE_MOVEMENT_SPEED * 100))
    end
end

-- 3. UI Setup
local backdropInfo = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileEdge = true,
    tileSize = 8,
    edgeSize = 8,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local f = CreateFrame("Frame", "MoveSpeedFrame", UIParent, "BackdropTemplate")
f:SetSize(50, 30)
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self:SetUserPlaced(false) -- position lives in MoveSpeedDB, not layout-cache.txt
    local point, _, relPoint, x, y = self:GetPoint()
    MoveSpeedDB.position = { point, "UIParent", relPoint, x, y }
end)

f.text = f:CreateFontString(nil, "ARTWORK", "GameTooltipText")
f.text:SetAllPoints(true)

local function UpdateVisuals()
    if not MoveSpeedDB.showFrame then
        f:Hide()
        return -- Stop processing visuals if hidden
    end

    f:Show()

    -- Lock & Clickthrough
    if MoveSpeedDB.locked then
        f:EnableMouse(false)
        f:SetMovable(false)
    else
        f:EnableMouse(true)
        f:SetMovable(true)
    end

    if MoveSpeedDB.background then
        f:SetBackdrop(backdropInfo)
    else
        f:SetBackdrop(nil)
    end

    -- Apply font
    local family = MoveSpeedDB.fontFamily or defaults.fontFamily
    local fontPath = "Fonts\\" .. family
    local fontFlag = MoveSpeedDB.fontFlag == "" and nil or MoveSpeedDB.fontFlag
    f.text:SetFont(fontPath, MoveSpeedDB.fontSize, fontFlag)

    -- Apply text alignment
    local align = MoveSpeedDB.textAlign or defaults.textAlign
    f.text:SetJustifyH(align)
    f.text:SetJustifyV("MIDDLE")

    -- Apply text color
    local c = MoveSpeedDB.textColor
    f.text:SetTextColor(c.r, c.g, c.b, c.a)

    -- Dynamic Height & Width
    f:SetHeight(MoveSpeedDB.fontSize + 6)
    f:SetWidth(max(50, MoveSpeedDB.fontSize * 4))

    f:ClearAllPoints()
    local pos = MoveSpeedDB.position or defaults.position
    f:SetPoint(pos[1], pos[2] or UIParent, pos[3], pos[4], pos[5])
end

local ticker
local lastFrameText -- Only used without secrets; secret strings can't be compared
local ldbShowingPlaceholder = false
local StartTicker
function StartTicker()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end

    ticker = C_Timer.NewTicker(MoveSpeedDB.updateRate or defaults.updateRate, function()
        if not (MoveSpeedDB.showFrame or f.dataobject) then return end

        local str = GetSpeedString()

        if MoveSpeedDB.showFrame then
            if hasSecrets then
                f.text:SetText(str)
            elseif str ~= lastFrameText then
                f.text:SetText(str)
                lastFrameText = str
            end
        end

        if f.dataobject then
            if MoveSpeedDB.safeLDBInCombat and InCombatLockdown() then
                -- Only push the placeholder once; each assignment fires LDB callbacks
                if not ldbShowingPlaceholder then
                    if hasSecrets then
                        f.dataobject.text = nil -- previous text may be secret; clear before assigning
                    end
                    f.dataobject.text = "---%"
                    ldbShowingPlaceholder = true
                end
            else
                if hasSecrets then
                    f.dataobject.text = nil -- always clear first to avoid LDB secret comparison
                end
                f.dataobject.text = str
                ldbShowingPlaceholder = false
            end
        end
    end)
end

-- 4. Settings Panel
local function SetupOptions()
    if not Settings or not Settings.RegisterCanvasLayoutCategory then return end

    local panel = CreateFrame("Frame", "MoveSpeedOptionsPanel")
    panel:Hide()
    -- Settings apply immediately, so the panel's commit/default/refresh hooks do nothing
    panel.OnCommit = function() end
    panel.OnDefault = function() end
    panel.OnRefresh = function() end

    local checkboxes, dropdowns = {}, {}
    local built = false
    local y = -16

    local function SetTooltip(frame, text)
        frame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(text, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    local function AddCheckbox(key, label, tooltip, onChange)
        local cb = CreateFrame("CheckButton", "MoveSpeedOptions_" .. key, panel, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 16, y)
        local text = cb.Text or cb.text or _G[cb:GetName() .. "Text"]
        text:SetText(label)
        cb:SetScript("OnClick", function(self)
            MoveSpeedDB[key] = self:GetChecked() and true or false
            if onChange then onChange() end
        end)
        SetTooltip(cb, tooltip)
        cb.key = key
        checkboxes[#checkboxes + 1] = cb
        y = y - 30
    end

    -- getChoices returns a list of { value, label }
    local function AddDropdown(key, label, getChoices, onChange)
        local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        fs:SetPoint("TOPLEFT", 20, y - 6)
        fs:SetText(label)

        local dd = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
        dd:SetPoint("TOPLEFT", 180, y)
        dd:SetWidth(220)
        dd:SetupMenu(function(_, rootDescription)
            for _, choice in ipairs(getChoices()) do
                rootDescription:CreateRadio(choice[2],
                    function(value) return MoveSpeedDB[key] == value end,
                    function(value)
                        MoveSpeedDB[key] = value
                        onChange()
                    end,
                    choice[1])
            end
        end)
        dropdowns[#dropdowns + 1] = dd
        y = y - 34
    end

    local function AddButton(label, tooltip, onClick)
        local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        b:SetPoint("TOPLEFT", 20, y)
        b:SetSize(160, 24)
        b:SetText(label)
        b:SetScript("OnClick", onClick)
        SetTooltip(b, tooltip)
        y = y - 32
    end

    local function ShowColorPicker()
        local info = {}
        local c = MoveSpeedDB.textColor or { r = 1, g = 1, b = 1, a = 1 }
        info.r = c.r or 1
        info.g = c.g or 1
        info.b = c.b or 1
        info.opacity = c.a or 1

        info.hasOpacity = true

        info.swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            MoveSpeedDB.textColor = { r = r, g = g, b = b, a = a }
            UpdateVisuals()
        end

        info.opacityFunc = info.swatchFunc

        info.cancelFunc = function(restore)
            MoveSpeedDB.textColor = { r = restore.r, g = restore.g, b = restore.b, a = restore.opacity }
            UpdateVisuals()
        end

        ColorPickerFrame:SetupColorPickerAndShow(info)
    end

    local function Build()
        local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, y)
        title:SetText("MoveSpeed")
        y = y - 30

        AddCheckbox("showFrame", "Show MoveSpeed Frame", "Toggle the MoveSpeed frame.", UpdateVisuals)
        AddCheckbox("locked", "Lock Frame", "Lock frame position and allow mouse clicks to pass through.",
            UpdateVisuals)
        AddCheckbox("background", "Enable Background", "Toggle the frame background.", UpdateVisuals)
        AddCheckbox("safeLDBInCombat", "Show ---% in LDB during combat",
            "If enabled, the LDB display (Bazooka, ButtonBin, etc.) shows '---%' during combat instead of live speed. This prevents display issues in some LDB display addons. The main MoveSpeed frame always shows live speed regardless.")
        y = y - 10

        AddDropdown("updateRate", "Update Rate", function()
            local choices = {
                { 0.1, "Fast (0.10s)" },
                { 0.2, "Normal (0.20s)" },
                { 0.5, "Slow (0.50s)" },
            }
            -- Include a custom rate set via /movespeed rate so the dropdown isn't blank
            local rate = MoveSpeedDB.updateRate
            if rate and rate ~= 0.1 and rate ~= 0.2 and rate ~= 0.5 then
                choices[#choices + 1] = { rate, format("Custom (%.2fs)", rate) }
            end
            return choices
        end, StartTicker)

        AddDropdown("fontSize", "Font Size", function()
            local choices = {}
            for size = 8, 24 do
                choices[#choices + 1] = { size, tostring(size) }
            end
            return choices
        end, UpdateVisuals)

        AddDropdown("fontFamily", "Font Family", function()
            return {
                { "ARIALN.TTF", "Arial Narrow" },
                { "FRIZQT__.TTF", "Friz Quadrata (Default)" },
                { "MORPHEUS.TTF", "Morpheus" },
                { "skurri.ttf", "Skurri" },
            }
        end, UpdateVisuals)

        AddDropdown("fontFlag", "Font Flags", function()
            return {
                { "", "None" },
                { "MONOCHROME", "Monochrome" },
                { "OUTLINE", "Outline (Default)" },
                { "THICKOUTLINE", "Thick Outline" },
            }
        end, UpdateVisuals)

        AddDropdown("textAlign", "Text Alignment", function()
            return {
                { "LEFT", "Left (Default)" },
                { "CENTER", "Center" },
                { "RIGHT", "Right" },
            }
        end, UpdateVisuals)
        y = y - 10

        AddButton("Text Color", "Choose the text color.", ShowColorPicker)
        AddButton("Reset Position", "Reset frame position.", function()
            MoveSpeedDB.position = defaults.position
            UpdateVisuals()
        end)
    end

    -- Sync widgets with MoveSpeedDB (slash commands may have changed it)
    local function Refresh()
        for _, cb in ipairs(checkboxes) do
            cb:SetChecked(MoveSpeedDB[cb.key])
        end
        for _, dd in ipairs(dropdowns) do
            dd:GenerateMenu()
        end
    end

    panel:SetScript("OnShow", function()
        if not built then
            built = true
            Build()
        end
        Refresh()
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, "MoveSpeed")
    Settings.RegisterAddOnCategory(category)
    return category
end

-- 5. Command Handler (Updated for Universal Support)
local function HandleSlashCommands(msg)
    local cmd = msg:lower():trim()

    if cmd == "reset" then
        MoveSpeedDB.position = defaults.position
        UpdateVisuals()
        print("|cFF00FF00MoveSpeed:|r Frame position reset.")
    elseif cmd == "lock" then
        MoveSpeedDB.locked = true
        UpdateVisuals()
        print("|cFF00FF00MoveSpeed:|r Frame locked (clickthrough enabled).")
    elseif cmd == "unlock" then
        MoveSpeedDB.locked = false
        UpdateVisuals()
        print("|cFF00FF00MoveSpeed:|r Frame unlocked.")
    elseif cmd == "center" or cmd == "align center" then
        MoveSpeedDB.textAlign = "CENTER"
        UpdateVisuals()
        print("|cFF00FF00MoveSpeed:|r Text alignment set to Center.")
    elseif cmd == "left" or cmd == "align left" then
        MoveSpeedDB.textAlign = "LEFT"
        UpdateVisuals()
        print("|cFF00FF00MoveSpeed:|r Text alignment set to Left.")
    elseif cmd == "right" or cmd == "align right" then
        MoveSpeedDB.textAlign = "RIGHT"
        UpdateVisuals()
        print("|cFF00FF00MoveSpeed:|r Text alignment set to Right.")
    elseif cmd == "bg" then
        MoveSpeedDB.background = true
        UpdateVisuals()
        print("|cFF00FF00MoveSpeed:|r Background enabled.")
    elseif cmd == "bgoff" then
        MoveSpeedDB.background = false
        UpdateVisuals()
        print("|cFF00FF00MoveSpeed:|r Background disabled.")
    elseif cmd == "small" then
        MoveSpeedDB.fontSize = 12
        UpdateVisuals()
        print("|cFF00FF00MoveSpeed:|r Font size set to small (12).")
    elseif cmd == "medium" then
        MoveSpeedDB.fontSize = 16
        UpdateVisuals()
        print("|cFF00FF00MoveSpeed:|r Font size set to medium (16).")
    elseif cmd == "large" then
        MoveSpeedDB.fontSize = 20
        UpdateVisuals()
        print("|cFF00FF00MoveSpeed:|r Font size set to large (20).")
    elseif cmd == "hide" then
        MoveSpeedDB.showFrame = false
        UpdateVisuals()
        print("|cFF00FF00MoveSpeed:|r Frame hidden. Use /movespeed show to restore.")
    elseif cmd == "show" then
        MoveSpeedDB.showFrame = true
        UpdateVisuals()
        print("|cFF00FF00MoveSpeed:|r Frame shown.")
    elseif cmd:match("^rate%s+[%d%.]+") then
        local num = tonumber(cmd:match("[%d%.]+"))
        if num and num >= 0.05 and num <= 1.0 then
            MoveSpeedDB.updateRate = num
            StartTicker()
            print("|cFF00FF00MoveSpeed:|r Update rate set to " .. num .. " seconds.")
        else
            print("|cFFFF0000MoveSpeed:|r Invalid rate. Use 0.05 to 1.0")
        end
    elseif cmd == "safeldb" then
        MoveSpeedDB.safeLDBInCombat = true
        print("|cFF00FF00MoveSpeed:|r LDB will show '---%' during combat (compatible with all displays).")
    elseif cmd == "liveldb" then
        MoveSpeedDB.safeLDBInCombat = false
        print("|cFF00FF00MoveSpeed:|r LDB will show live speed during combat (may break some displays like Bazooka).")
    else
        if Settings and Settings.OpenToCategory and categoryID and not InCombatLockdown() then
            Settings.OpenToCategory(categoryID)
        else
            if InCombatLockdown() then
                print("|cFF00FF00MoveSpeed:|r Options can't be opened in combat.")
            end
            print("|cFF00FF00MoveSpeed Commands:|r")
            print("  /movespeed reset   - Reset position")
            print("  /movespeed lock    - Lock frame & enable clickthrough")
            print("  /movespeed unlock  - Unlock frame for dragging")
            print("  /movespeed center  - Center text alignment")
            print("  /movespeed left    - Left text alignment")
            print("  /movespeed right   - Right text alignment")
            print("  /movespeed bg      - Show background")
            print("  /movespeed bgoff   - Hide background")
            print("  /movespeed small   - Small font")
            print("  /movespeed medium  - Medium font")
            print("  /movespeed large   - Large font")
            print("  /movespeed hide    - Hide frame")
            print("  /movespeed show    - Show frame")
            print("  /movespeed rate <seconds>  - Set update rate (0.05–1.0)")
            print("  /movespeed safeldb   - Show ---% in LDB during combat")
            print("  /movespeed liveldb   - Show live speed in LDB during combat")
        end
    end
end

-- 6. DataBroker (LDB)
local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
if ldb then
    local dataobject = ldb:NewDataObject("MoveSpeed", {
        type = "data source", icon = iconPath, label = "MoveSpeed", text = "0%", value = 0,
    })
    dataobject.OnTooltipShow = function(tooltip)
        tooltip:AddLine(GetSpeedString())
    end
    f.dataobject = dataobject
end

-- 7. Initialization & Ticker
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    if not MoveSpeedDB then MoveSpeedDB = {} end
    for k, v in pairs(defaults) do
        if MoveSpeedDB[k] == nil then MoveSpeedDB[k] = v end
    end

    UpdateVisuals()

    local category = SetupOptions()
    if category then categoryID = category:GetID() end

    SLASH_MOVESPEED1 = "/movespeed"
    SlashCmdList["MOVESPEED"] = HandleSlashCommands
    StartTicker()
end)