--[[
	Controls and HUD sizes. Sizes are in pixels for a phone-sized screen and
	scale up on bigger screens.
]]

local Controls = {}

-- Aim assist picks the target closest to the crosshair within this angle
-- (degrees from the camera's forward direction) and in reach or range.
Controls.aimAssistDegrees = 25

-- Bite button and slot buttons (pixels at 1x scale).
Controls.biteButtonSize = 110
Controls.slotButtonSize = 70
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

-- Keyboard keys for desktop playtests.
Controls.biteKey = "E"
Controls.slotKeys = table.freeze({ "One", "Two", "Three" })
Controls.rootKey = "R"

return table.freeze(Controls)
