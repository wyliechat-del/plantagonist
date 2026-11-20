--[[
	Test runner. Run from the repo root with: lune run tests
	It finds every `*.spec.luau` file in this folder and runs it.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local Test = require("@self/lib/Test")

local specs = {}
for _, file in fs.readDir("tests") do
	if string.match(file, "%.spec%.luau$") then
		table.insert(specs, file)
	end
end
table.sort(specs)

local total, failed = 0, 0
for _, file in specs do
	local name = string.gsub(file, "%.luau$", "")
	local spec = (require :: any)("@self/" .. name)
	spec(Test)
	local count, failures = Test.run(name)
	total += count
	failed += failures
end

print(`\n{total - failed} passed, {failed} failed, {#specs} spec files`)
if failed > 0 then
	process.exit(1)
end
