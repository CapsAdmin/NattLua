local String = require("nattlua.types.string").String
local Number = require("nattlua.types.number").Number
local Tuple = require("nattlua.types.tuple").Tuple
local Any = require("nattlua.types.any").Any
local shared = require("nattlua.types.shared")
local SN = Tuple({String(), Number()})
local NS = Tuple({Number(), String()})
local SNS = Tuple({String(), Number(), String()})
local cast = require("nattlua.analyzer.cast")

test(tostring(SN) .. " should not be a subset of " .. tostring(NS), function()
	assert(not shared.IsSubsetOf(SN, NS))
end)

test(tostring(SN) .. " should be a subset of " .. tostring(SN), function()
	assert(shared.IsSubsetOf(SN, SN))
end)

pending(tostring(SN) .. " should be a subset of " .. tostring(SNS), function()
	assert(shared.IsSubsetOf(SN, SNS))
end)

test(tostring(SNS) .. " should not be a subset of " .. tostring(SN), function()
	assert(not shared.IsSubsetOf(SNS, SN))
end)

test("remainder", function()
	local tup = Tuple(
		{
			String(),
			Number(),
			String(),
			Number(),
			String(),
			Number(),
			String(),
			Number(),
			String(),
			Number(),
		}
	):AddRemainder(Tuple({String()}):SetRepeat(10))
	assert(tup:GetElementCount() == 10 + (1 * 10))
	assert(tup:GetWithNumber(1).Type == "string")
	assert(tup:GetWithNumber(2).Type == "number")
	assert(tup:GetWithNumber(9).Type == "string")
	assert(tup:GetWithNumber(10).Type == "number")
	assert(tup:GetWithNumber(11).Type == "string")
	assert(tup:GetWithNumber(12).Type == "string")
	assert(tup:GetWithNumber(15).Type == "string")
	assert(tup:GetWithNumber(18).Type == "string")
	assert(tup:GetWithNumber(19).Type == "string")
	assert(tup:GetWithNumber(20).Type == "string")
	assert(tup:GetWithNumber(21) == false)
end)

test("remainder with repeated tuple structure", function()
	local tup = Tuple({String()}):AddRemainder(Tuple({String(), Number()}):SetRepeat(4))
	assert(tup:GetElementCount() == 1 + (2 * 4))
	assert(tup:GetWithNumber(1).Type == "string")
	assert(tup:GetWithNumber(2).Type == "string")
	assert(tup:GetWithNumber(3).Type == "number")
	assert(tup:GetWithNumber(4).Type == "string")
	assert(tup:GetWithNumber(5).Type == "number")
end)

test("tuple unpack", function()
	local tup = Tuple({String()}):AddRemainder(Tuple({String(), Number()}):SetRepeat(4))
	local tbl = tup:ToTable()
	assert(tup:GetElementCount() == 1 + (2 * 4))
	assert(tup:GetElementCount() == #tbl)
	assert(tbl[1].Type == "string")
	assert(tbl[2].Type == "string")
	assert(tbl[3].Type == "number")
	assert(tbl[4].Type == "string")
	assert(tbl[5].Type == "number")
end)

test("tuple unpack", function()
	local tup = Tuple({String()}):AddRemainder(Tuple({String(), Number()}):SetRepeat(4))
	local tbl = tup:ToTable(3)
	assert(#tbl == 3)
	assert(tbl[1].Type == "string")
	assert(tbl[2].Type == "string")
	assert(tbl[3].Type == "number")
	local tbl = tup:ToTable(1)
	assert(#tbl == 1)
	assert(tbl[1].Type == "string")
end)

test("infinite tuple repetition", function()
	local tup = Tuple({String()}):AddRemainder(Tuple({String(), Number()}):SetRepeat(math.huge))
	assert(tup:GetWithNumber(1).Type == "string")
	assert(tup:GetWithNumber(2).Type == "string")
	assert(tup:GetWithNumber(10000).Type == "string")
	assert(tup:GetWithNumber(10001).Type == "number")
	assert(select("#", tup:Unpack(100)) == 100)
end)

test("length subset", function()
	local A = Tuple({String(), String()})
	local B = Tuple({String(), String(), String()})
	assert(shared.IsSubsetOf(B, A) == false)
end)

test("length subset", function()
	local A = Tuple({String(), String()})
	local B = Tuple({String()}):AddRemainder(Tuple({String()}):SetRepeat(4))
	assert(shared.IsSubsetOf(B, A) == true)
end)

test("initialize with remainder", function()
	local A = Tuple({String(), Tuple({String()}):SetRepeat(2)})
	assert(A:GetElementCount() == 3)
	assert(A:GetWithNumber(1).Type == "string")
	assert(A:GetWithNumber(2).Type == "string")
	assert(A:GetWithNumber(3).Type == "string")
end)

test("initialize with remainder", function()
	local A = Tuple({Tuple({String()}):SetRepeat(2), Number()})
	assert(A:GetElementCount() == 2)
	assert(A:GetWithNumber(1).Type == "tuple")
	assert(A:GetWithNumber(2).Type == "number")
end)

test("merge tuples", function()
	local infinite_any = Tuple():AddRemainder(Tuple({Any()}):SetRepeat(math.huge))
	local number_number = Tuple({Number(), Number()})
	infinite_any:Merge(number_number)
	assert(infinite_any:HasInfiniteValues())
	assert(infinite_any:GetWithNumber(1).Type == "union")
	assert(infinite_any:GetWithNumber(2).Type == "union")
	assert(infinite_any:GetWithNumber(1):GetType("number"))
	assert(infinite_any:GetWithNumber(1):GetType("any"))
	assert(infinite_any:GetWithNumber(2):GetType("number"))
	assert(infinite_any:GetWithNumber(2):GetType("any"))
	assert(not infinite_any:GetWithNumber(2):GetType("string"))
end)

test("tuple in tuple", function()
	local T = Tuple(cast({1, 2, 3, Tuple(cast({4, 5, 6}))}))
	assert(T:GetElementCount() == 6)

	for i = 1, 6 do
		assert(T:GetWithNumber(i):GetData() == i)
	end
end)