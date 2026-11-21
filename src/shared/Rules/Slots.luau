--[[
	Power up slots on a plant.

	A plant has some attack slots and some defence slots (set by its level).
	Each slot is empty or holds one power up id. A new power up goes in the
	first free slot of its type; when they're all full, it replaces the oldest
	one of that type. Different slots can hold the same power up.

	Every power up gets an increasing `order` number when it's added, so
	"oldest" and "latest" are well defined.

	An attack slot can also carry one boost (bee, mantis, bombardier beetle):
	the boost is used with that slot's power up, and is lost if the slot is
	emptied or replaced.

	These functions change the `Slots` table they are given.
]]

local Slots = {}

export type SlotType = "attack" | "defence"
export type Slot = { id: string?, order: number, boost: string? }
export type Slots = {
	attack: { Slot },
	defence: { Slot },
	nextOrder: number,
}

local function makeSlots(count: number): { Slot }
	local list = table.create(count)
	for index = 1, count do
		list[index] = { id = nil, order = 0 }
	end
	return list
end

function Slots.new(attackCount: number, defenceCount: number): Slots
	return { attack = makeSlots(attackCount), defence = makeSlots(defenceCount), nextOrder = 1 }
end

-- Adds a power up. Returns the slot index it went into (nil when the plant has
-- no slot of that type) and the id it pushed out, if any.
function Slots.add(slots: Slots, slotType: SlotType, id: string): (number?, string?)
	local list = slots[slotType]
	if #list == 0 then
		return nil, nil
	end
	local target = nil
	for index, slot in list do
		if slot.id == nil then
			target = index
			break
		end
	end
	if target == nil then
		target = 1
		for index, slot in list do
			if slot.order < list[target].order then
				target = index
			end
		end
	end
	local replaced = list[target].id
	list[target] = { id = id, order = slots.nextOrder }
	slots.nextOrder += 1
	return target, replaced
end

-- Puts boost `boostId` on the oldest attack slot whose power up passes
-- `matches(id)` and has no boost yet. Returns the slot index, or nil when
-- no slot fits (the boost is then lost).
function Slots.addBoost(slots: Slots, boostId: string, matches: (string) -> boolean): number?
	local bestIndex: number? = nil
	local bestOrder = math.huge
	for index, slot in slots.attack do
		if slot.id and slot.boost == nil and matches(slot.id) and slot.order < bestOrder then
			bestIndex, bestOrder = index, slot.order
		end
	end
	if bestIndex then
		slots.attack[bestIndex].boost = boostId
	end
	return bestIndex
end

-- Removes and returns the boost on an attack slot, if any.
function Slots.takeBoost(slots: Slots, index: number): string?
	local slot = slots.attack[index]
	if slot == nil then
		return nil
	end
	local boost = slot.boost
	slot.boost = nil
	return boost
end

-- Empties one slot and returns what it held (its boost is lost).
function Slots.take(slots: Slots, slotType: SlotType, index: number): string?
	local slot = slots[slotType][index]
	if slot == nil or slot.id == nil then
		return nil
	end
	local id = slot.id
	slots[slotType][index] = { id = nil, order = 0 }
	return id
end

function Slots.count(slots: Slots): number
	local total = 0
	for _, list in { slots.attack, slots.defence } do
		for _, slot in list do
			if slot.id then
				total += 1
			end
		end
	end
	return total
end

-- The oldest power up in any slot, as (slotType, index), or nil when empty.
function Slots.oldest(slots: Slots): (SlotType?, number?)
	local bestType: SlotType? = nil
	local bestIndex: number? = nil
	local bestOrder = math.huge
	for _, slotType: SlotType in { "attack", "defence" } :: { SlotType } do
		for index, slot in slots[slotType] do
			if slot.id and slot.order < bestOrder then
				bestType, bestIndex, bestOrder = slotType, index, slot.order
			end
		end
	end
	return bestType, bestIndex
end

-- The most recently added attack power up (kept on respawn), or nil.
function Slots.latestAttack(slots: Slots): string?
	local best: Slot? = nil
	for _, slot in slots.attack do
		if slot.id and (best == nil or slot.order > best.order) then
			best = slot
		end
	end
	return if best then best.id else nil
end

-- The oldest defence slot whose power up passes `matches(id)`, or nil.
function Slots.findDefence(slots: Slots, matches: (string) -> boolean): number?
	local bestIndex: number? = nil
	local bestOrder = math.huge
	for index, slot in slots.defence do
		if slot.id and matches(slot.id) and slot.order < bestOrder then
			bestIndex, bestOrder = index, slot.order
		end
	end
	return bestIndex
end

-- Changes the number of slots after a level change. Slots lost from the end
-- of each list pop their power ups out; they are returned (attack first) so
-- the game can drop them as fruit.
function Slots.resize(slots: Slots, attackCount: number, defenceCount: number): { string }
	local popped = {}
	for _, pair in { { slots.attack, attackCount }, { slots.defence, defenceCount } } do
		local list: { Slot }, count: number = pair[1], pair[2]
		while #list > count do
			local slot = table.remove(list) :: Slot
			if slot.id then
				table.insert(popped, slot.id)
			end
		end
		while #list < count do
			table.insert(list, { id = nil, order = 0 })
		end
	end
	return popped
end

return table.freeze(Slots)
