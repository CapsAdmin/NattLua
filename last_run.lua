--[[#local type test = analyzer function()
	return 11, 22, 33
end]]
local a, b, c = test()
attest.equal(a, 11)
attest.equal(b, 22)
attest.equal(c, 33)
