-- Scans the game source for names that must match a list somewhere else,
-- so a typo fails here instead of at runtime in Studio.
local fs = require("@lune/fs")

local Remotes = require("../src/shared/Remotes")
local Sounds = require("../src/shared/Config/Sounds")

local function sourceFiles(dir: string, into: { string })
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			sourceFiles(path, into)
		elseif string.match(name, "%.luau$") then
			table.insert(into, path)
		end
	end
	return into
end

local files = sourceFiles("src", {})

local function each(pattern: string, fn: (string, string) -> ())
	for _, path in files do
		for name in string.gmatch(fs.readFile(path), pattern) do
			fn(name, path)
		end
	end
end

return function(t)
	t.test("every remote used in the code is listed in Remotes.luau", function()
		local listed = {}
		for _, name in Remotes.Events do
			listed[name] = true
		end
		for _, name in Remotes.Functions do
			listed[name] = true
		end
		local count = 0
		each('Remotes%.event%("([%w_]+)"%)', function(name, path)
			count += 1
			t.expect(listed[name], `{path} uses unlisted remote "{name}"`)
		end)
		each('Remotes%.func%("([%w_]+)"%)', function(name, path)
			t.expect(listed[name], `{path} uses unlisted remote "{name}"`)
		end)
		t.expect(count > 0, "found remote uses")
	end)

	t.test("every sound played by name exists in Config/Sounds", function()
		each('Effects%.sound%("([%w_]+)"', function(name, path)
			t.expect(Sounds.ids[name], `{path} plays unknown sound "{name}"`)
		end)
		each('"sound", { name = "([%w_]+)"', function(name, path)
			t.expect(Sounds.ids[name], `{path} plays unknown sound "{name}"`)
		end)
	end)

	t.test("nothing outside Remotes.luau creates remotes", function()
		for _, path in files do
			if not string.find(path, "Remotes.luau", 1, true) then
				local source = fs.readFile(path)
				t.expect(
					not string.find(source, 'Instance.new("RemoteEvent")', 1, true),
					`{path} creates a RemoteEvent`
				)
				t.expect(
					not string.find(source, 'Instance.new("RemoteFunction")', 1, true),
					`{path} creates a RemoteFunction`
				)
			end
		end
	end)

	t.test("Config and Rules modules require nothing", function()
		for _, path in files do
			if
				string.find(path, "src/shared/Config/", 1, true)
				or string.find(path, "src/shared/Rules/", 1, true)
			then
				t.expect(
					not string.find(fs.readFile(path), "require(", 1, true),
					`{path} requires something`
				)
			end
		end
	end)

	t.test("every required module exists", function()
		each("require%(ReplicatedStorage%.Shared%.([%w_%.]+)%)", function(name, path)
			local file = "src/shared/" .. string.gsub(name, "%.", "/") .. ".luau"
			t.expect(fs.isFile(file), `{path} requires missing {file}`)
		end)
		for _, path in files do
			local dir = string.match(path, "^(.*)/[^/]+$") :: string
			for name in string.gmatch(fs.readFile(path), "require%(script%.Parent%.([%w_]+)%)") do
				local file = `{dir}/{name}.luau`
				t.expect(fs.isFile(file), `{path} requires missing {file}`)
			end
		end
	end)
end
