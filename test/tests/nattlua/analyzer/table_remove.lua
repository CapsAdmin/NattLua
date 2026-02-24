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

test("table length with contract", function()
	analyze[[
		local t: List<|string|> = {"a", "b"}
        -- this should return number, not 2, since List<|string|> could have any number of elements, not just 2
		attest.equal(#t, _ as number)
	]]
end)
