test("table.remove shifting", function()
	analyze[[
		local t = {"a", "b", "c"}
		local r = table.remove(t, 2)
		attest.equal(r, "b")
		attest.equal(#t, 2)
		attest.equal(t[1], "a")
		attest.equal(t[2], "c")
		attest.equal(t[3], nil)
	]]
end)

test("table.remove recursive path traversal", function()
	analyze[[
		local function set_recursive(t, path, value)
			local key = table.remove(path, 1)
			if not path[1] then
				t[key] = value
			else
				t[key] = t[key] or {}
				set_recursive(t[key], path, value)
			end
		end

		local data = {}
		set_recursive(data, {"a", "b", "c"}, 42)
		attest.equal(data.a.b.c, 42)

		local data2 = {}
		set_recursive(data2, {"x", "y"}, "final")
		attest.equal(data2.x.y, "final")
	]]
end)
