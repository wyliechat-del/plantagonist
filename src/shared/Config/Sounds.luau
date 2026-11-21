--[[
	Placeholder sounds. These use sounds that ship with Roblox Studio
	(rbxasset://), so they work without uploading anything. Replace them with
	uploaded sound ids (rbxassetid://123...) for real chomps, burps and farts.
]]

local Sounds = {}

Sounds.ids = table.freeze({
	chomp = "rbxasset://sounds/swordslash.wav",
	burp = "rbxasset://sounds/uuhhh.mp3",
	fart = "rbxasset://sounds/uuhhh.mp3",
	rain = "rbxasset://sounds/impact_water.mp3",
	thunder = "rbxasset://sounds/snap.mp3",
	levelUp = "rbxasset://sounds/electronicpingshort.wav",
	levelDown = "rbxasset://sounds/snap.mp3",
	powerUp = "rbxasset://sounds/electronicpingshort.wav",
	choir = "rbxasset://sounds/electronicpingshort.wav",
	button = "rbxasset://sounds/button.wav",
	miss = "rbxasset://sounds/swordlunge.wav",
	toss = "rbxasset://sounds/uuhhh.mp3",
})

Sounds.volume = 0.6

-- Small changes in pitch so repeated sounds don't get boring.
Sounds.pitchMin = 0.9
Sounds.pitchMax = 1.15

return table.freeze(Sounds)
