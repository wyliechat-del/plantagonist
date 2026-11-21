--[[
	Awards and the free cosmetic each one unlocks. Progress is saved per player.

	`kind` says how an award is earned:
	- "count": the counter `stat` reaches `target`.
	- "eatCreature": eat creature `creature` `target` times.
	- "eatFamily": eat every creature in `family` at least once.
	- "useFamily": use every power up in `family` at least once.
	- "eatAll": eat every creature at least once.
]]

local Awards = {}

Awards.list = table.freeze({
	table.freeze({
		id = "FirstBite",
		name = "First Bite",
		kind = "count",
		stat = "creaturesEaten",
		target = 1,
	}),
	table.freeze({
		id = "GrowingUp",
		name = "Growing Up",
		kind = "count",
		stat = "reachedTopLevel",
		target = 1,
		cosmetic = "Rex claw feet",
	}),
	table.freeze({
		id = "Deciduous",
		name = "Deciduous",
		kind = "count",
		stat = "rooted",
		target = 1,
		cosmetic = "Golden bark tree skin",
	}),
	table.freeze({
		id = "OldGrowth",
		name = "Old Growth",
		kind = "count",
		stat = "rooted",
		target = 10,
		cosmetic = "Ancient oak tree skin",
	}),
	table.freeze({
		id = "Arachnophile",
		name = "Arachnophile",
		kind = "eatCreature",
		creature = "spider",
		target = 20,
		cosmetic = "Hairy pot",
	}),
	table.freeze({
		id = "VenomCollector",
		name = "Venom Collector",
		kind = "eatFamily",
		family = "Venom",
		cosmetic = "Purple trap colour",
	}),
	table.freeze({
		id = "Slasher",
		name = "Slasher",
		kind = "eatFamily",
		family = "BiteAndSlash",
		cosmetic = "Red trap colour",
	}),
	table.freeze({
		id = "KnotMaster",
		name = "Knot Master",
		kind = "eatFamily",
		family = "Strangle",
		cosmetic = "Orange trap colour",
	}),
	table.freeze({
		id = "ShowOff",
		name = "Show Off",
		kind = "useFamily",
		family = "SpecialMove",
		cosmetic = "Yellow trap colour",
	}),
	table.freeze({ id = "FullMenu", name = "Full Menu", kind = "eatAll", cosmetic = "Napkin bib" }),
	table.freeze({
		id = "GiantSlayer",
		name = "Giant Slayer",
		kind = "count",
		stat = "giantsEaten",
		target = 1,
		cosmetic = "Thorn crown",
	}),
	table.freeze({
		id = "PeckingOrder",
		name = "Pecking Order",
		kind = "count",
		stat = "biggerPlantPops",
		target = 10,
		cosmetic = "Beak lips",
	}),
	table.freeze({
		id = "RainDancer",
		name = "Rain Dancer",
		kind = "count",
		stat = "rainCaught",
		target = 10,
		cosmetic = "Rain cloud hat",
	}),
	table.freeze({
		id = "PooGourmet",
		name = "Poo Gourmet",
		kind = "count",
		stat = "pooEaten",
		target = 25,
		cosmetic = "Fly swarm",
	}),
	table.freeze({
		id = "Untouchable",
		name = "Untouchable",
		kind = "count",
		stat = "untouchable",
		target = 1,
		cosmetic = "Shiny leaf trail",
	}),
	table.freeze({
		id = "EscapeArtist",
		name = "Escape Artist",
		kind = "count",
		stat = "blowfishEscapes",
		target = 10,
		cosmetic = "Pufferfish pot",
	}),
})

-- An attack is a "giant" kill when the victim started this many levels higher.
Awards.giantLevelGap = 2

return table.freeze(Awards)
