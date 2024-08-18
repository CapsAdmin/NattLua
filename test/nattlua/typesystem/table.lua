
local Number = require("nattlua.types.number").Number
local LNumber = require("nattlua.types.number").LNumber
local LString = require("nattlua.types.string").LString
local Table = require("nattlua.types.table").Table

test("union and get", function()
	local contract = Table()
	assert(contract:Set(LString("foo"), Number()))
	assert(assert(contract:Get(LString("foo")).Type == "number"))
	equal(false, contract:Get(LString("asdf")))
	local tbl = Table()
	tbl:SetContract(contract)
	assert(tbl:Set(LString("foo"), LNumber(1337)))
	equal(1337, tbl:Get(LString("foo")):GetData())
	assert(tbl:IsSubsetOf(contract))
	assert(not contract:IsSubsetOf(tbl))
end)

test("errors when trying to modify a table without a defined structure", function()
	local tbl = Table()
	tbl:SetContract(Table())
	assert(not tbl:Set(LString("foo"), LNumber(1337)))
end)

test("copy from constness", function()
	local contract = Table()
	contract:Set(LString("foo"), LString("bar"))
	contract:Set(LString("a"), Number())
	local tbl = Table()
	tbl:Set(LString("foo"), LString("bar"))
	tbl:Set(LString("a"), LNumber(1337))
	assert(tbl:CopyLiteralness(contract))
	assert(assert(tbl:Get(LString("foo"))):IsLiteral())
end)
