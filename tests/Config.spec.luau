local Config = require("../src/shared/Config")
local Rules = require("../src/shared/Rules")

return function(t)
	t.test("Config loads as a frozen table", function()
		t.expectEqual(type(Config), "table")
		t.expect(table.isfrozen(Config), "Config should be frozen")
	end)

	t.test("Rules loads as a frozen table", function()
		t.expectEqual(type(Rules), "table")
		t.expect(table.isfrozen(Rules), "Rules should be frozen")
	end)
end
