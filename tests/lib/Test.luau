--[[
	A tiny test helper so tests run on a normal computer with Lune,
	without Roblox Studio. Each spec file returns a function that receives
	this module and calls `test(name, fn)`.
]]

local Test = {}

type Case = { name: string, fn: () -> () }

local cases: { Case } = {}

function Test.test(name: string, fn: () -> ())
	table.insert(cases, { name = name, fn = fn })
end

local function describe(value: any): string
	if type(value) == "string" then
		return `"{value}"`
	end
	return tostring(value)
end

function Test.expectEqual(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(
			`{message or "values differ"}: expected {describe(expected)}, got {describe(actual)}`,
			2
		)
	end
end

function Test.expect(condition: any, message: string?)
	if not condition then
		error(message or "expectation failed", 2)
	end
end

-- Runs every collected case under `label` and returns the number of failures.
function Test.run(label: string): (number, number)
	local failed = 0
	for _, case in cases do
		local ok, err = pcall(case.fn)
		if ok then
			print(`  PASS  {label} > {case.name}`)
		else
			failed += 1
			print(`  FAIL  {label} > {case.name}\n        {err}`)
		end
	end
	local total = #cases
	table.clear(cases)
	return total, failed
end

return Test
