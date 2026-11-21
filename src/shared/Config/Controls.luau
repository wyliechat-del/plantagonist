--[[
	Controls and HUD sizes. Sizes are in pixels for a phone-sized screen and
	scale up on bigger screens.
]]

local Controls = {}

-- Bites go where you click (desktop) or tap (phone). A target counts as
-- clicked when it is within this many studs of the line under the pointer.
-- Fingers are less exact than a mouse, so taps get more room.
Controls.clickSlackStuds = 1.5
Controls.tapSlackStuds = 3

-- Slot buttons (pixels at 1x scale) sit in a row left of Roblox's jump
-- button, which is in the bottom right corner on phones.
Controls.slotButtonSize = 70
Controls.slotRowRightOffset = 140
Controls.slotRowBottomOffset = 30
Controls.buttonGap = 12

-- Slot buttons show the attack type. Ranged attacks get a triangle and melee
-- attacks a square button; specials stay round. A boost shows as a dot.
Controls.kindMarks = table.freeze({ range = "▲", melee = "■" })
Controls.squareCornerScale = 0.15
Controls.boostDotSize = 18

-- The HUD scales with the screen's short side; this many pixels is 1x.
Controls.referenceShortSide = 400
Controls.maxUiScale = 1.6

-- Pop-up messages stay on screen this long.
Controls.messageSeconds = 2.5

-- Outline colours: in bite reach, and in reach of a primed power up.
Controls.reachColour = table.freeze({ 255, 255, 120 })
Controls.primedColour = table.freeze({ 255, 90, 90 })
-- Stroke round a primed slot button.
Controls.primedStroke = 5

-- How long the snap-at-the-air effect lasts, and its size in studs.
Controls.missSeconds = 0.3
Controls.missSize = 2.5

-- Keyboard keys for desktop playtests. E bites where the mouse points.
Controls.biteKey = "E"
Controls.slotKeys = table.freeze({ "One", "Two", "Three" })
Controls.rootKey = "R"

return table.freeze(Controls)
