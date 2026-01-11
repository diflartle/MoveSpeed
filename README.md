# MoveSpeed

A lightweight World of Warcraft addon to show your character's movement speed in WoW.

I do not know why they ever took this away from us.

### Features

- **Customization:** Change font size, color, decoration, and update frequency.
- **Draggable:** Click and drag the frame to position it anywhere on your screen.
- **Real-time Updates:** Displays 0% when stationary and updates instantly when moving.
- **Data Broker Support:** Compatible with LibDataBroker (LDB) displays like TitanPanel.
- **Dragonriding Support:** Accurately tracks speed while gliding.

**[Download Latest Release](https://www.curseforge.com/wow/addons/movespeed)**

### Slash Commands

Type `/movespeed` followed by a command to configure the addon without opening the settings menu.

| Command              | Description                                                                                          |
| -------------------- | ---------------------------------------------------------------------------------------------------- |
| **`reset`**          | Resets the frame to the center of the screen (0,0).                                                  |
| **`bg`**             | Enables the black background (useful for visibility/positioning).                                    |
| **`bgoff`**          | Disables the background (transparent).                                                               |
| **`small`**          | Sets font size to small (12).                                                                        |
| **`medium`**         | Sets font size to medium (16).                                                                       |
| **`large`**          | Sets font size to large (20).                                                                        |
| **`hide`**           | Hides the floating frame.                                                                            |
| **`show`**           | Shows the floating frame.                                                                            |
| **`rate <seconds>`** | Sets how often the speed updates (e.g., `/movespeed rate 0.1`). Accepts values from `0.05` to `1.0`. |
