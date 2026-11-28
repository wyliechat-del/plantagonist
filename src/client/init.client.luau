-- Client entry point. Keep this thin: start the HUD, controls, effects and
-- map features.

local Controllers = script:WaitForChild("Controllers")

for _, name in { "Hud", "Controls", "Effects", "World" } do
	local controller = require(Controllers:WaitForChild(name)) :: any
	local ok, err = pcall(controller.start)
	if not ok then
		warn(`[Plantagonist] {name} failed to start: {err}`)
	end
end

print("[Plantagonist] client started")
