function round(x)
   return x>=0 and math.floor(x+0.5) or math.ceil(x-0.5)
 end

function setMyFrame(f,x,y)
   f:SetSize(50,30)
   f:SetPoint("TOPLEFT",UIParent,"TOPLEFT",x,y) 
   f.text = f.text or f:CreateFontString(nil,"ARTWORK","QuestFont_Shadow_Huge")   
   f.text:SetAllPoints(true)     
end
ctotel = 0
creft = 0.1
function mySpeed(f,i)
  ctotel = ctotel + i
  if ctotel >= creft then
     speed = round(GetUnitSpeed("player")/0.07)
     speedstring = speed.."%"
     f.text:SetText(format("%s",speedstring))
     ctotel = 0
  end
end
MySpeedFrame = CreateFrame("Frame","MySpeedFrame",UIParent)
setMyFrame(MySpeedFrame, 500, 0)
MySpeedFrame:SetScript("OnUpdate", mySpeed)
MySpeedFrame:SetMovable(true)
MySpeedFrame:EnableMouse(true)
MySpeedFrame:SetScript("OnMouseDown",function() MySpeedFrame:StartMoving() end)
MySpeedFrame:SetScript("OnMouseUp",function() MySpeedFrame:StopMovingOrSizing() end)

SLASH_MOVESPEED1 = '/movespeed';
 local function handler(msg, editbox)
    msg = string.lower(msg);
   if msg == 'reset' then
      MySpeedFrame:ClearAllPoints()
      MySpeedFrame:SetPoint("CENTER",UIParent, 0, 0)
   elseif msg == 'bg' then
      MySpeedFrame:SetBackdrop({
         bgFile = "Interface/Tooltips/UI-Tooltip-Background",
         edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
         edgeSize = 16,
         insets = { left = 4, right = 4, top = 4, bottom = 4 },
      })
      f:SetBackdropColor(0, 0, 1, .5)
   elseif msg == 'bgoff' then
      MySpeedFrame:SetBackdrop(nil)
   else
		print("/movespeed reset to center the box. bg to add a frame to help see what it overlaps, bgoff to remove background.")
   end
end
SlashCmdList["MOVESPEED"] = handler;