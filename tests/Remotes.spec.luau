local Remotes = require("../src/shared/Remotes")

return function(t)
	t.test("every remote name is a unique, non-empty string", function()
		local seen = {}
		for _, list in { Remotes.Events, Remotes.Functions } do
			for _, name in list do
				t.expectEqual(type(name), "string", "remote name type")
				t.expect(#name > 0, "remote name is empty")
				t.expect(not seen[name], `remote "{name}" is listed twice`)
				seen[name] = true
			end
		end
	end)
end
