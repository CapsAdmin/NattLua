local T = require("test.helpers")
local Number = T.Number
local String = T.String
local Table = T.Table
local Union = T.Union
local Tuple = T.Tuple

test("union and get", function()
    local contract = Table()
    assert(contract:Set(String("foo"), Number()))
    assert(assert(contract:Get("foo")).Type == "number")
    equal(false, contract:Get(String("asdf")))

    local tbl = Table()
    tbl.contract = contract
    assert(tbl:Set(String("foo"), Number(1337)))
    equal(1337, tbl:Get(String("foo")):GetData())

    assert(tbl:IsSubsetOf(contract))
    assert(not contract:IsSubsetOf(tbl))
end)

test("union string and get constant string", function()
    local contract = Table()
    assert(contract:Set(String(), Number()))

    local tbl = Table()
    tbl.contract = contract
    tbl:Set(String(), Number(1337):MakeLiteral(true))
    local union = assert(tbl:Get(String()))
    equal("union", union.Type)
    equal(1337, union:GetType("number"):GetData())
    equal(nil, union:GetType("symbol"):GetData())

    assert(tbl:IsSubsetOf(contract))
    assert(not contract:IsSubsetOf(tbl))    
end)

test("errors when trying to modify a table without a defined structure", function()
    local tbl = Table()
    tbl.contract = Table()
    assert(not tbl:Set(String("foo"), Number(1337)))
end)

test("copy from constness", function()
    local contract = Table()
    contract:Set(String("foo"), String("bar"))
    contract:Set(String("a"), Number())

    local tbl = Table()
    tbl:Set(String("foo"), String("bar"))
    tbl:Set(String("a"), Number(1337))

    assert(tbl:CopyLiteralness(contract))
    assert(assert(tbl:Get(String("foo"))):IsLiteral())
end)
