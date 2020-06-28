local T = require("spec.lua.helpers")
local Number = T.Number
local String = T.String
local Table = T.Table
local Set = T.Set
local Tuple = T.Tuple

describe("table", function()
    it("set and get should work", function()
        local contract = Table()
        assert(contract:Set(String("foo"), Number()))
        assert(assert(contract:Get("foo")).Type == "number")
        assert.equal(false, contract:Get(String("asdf")))

        local tbl = Table()
        tbl.contract = contract
        assert(tbl:Set(String("foo"), Number(1337)))
        assert.equal(1337, tbl:Get(String("foo")):GetData())

        assert(tbl:SubsetOf(contract))
        assert(not contract:SubsetOf(tbl))
    end)

    it("set string and get constant string should work", function()
        local contract = Table()
        assert(contract:Set(String(), Number()))

        local tbl = Table()
        tbl.contract = contract
        tbl:Set(String(), Number(1337))
        assert.equal(1337, assert(tbl:Get(String())):GetData())

        assert(tbl:SubsetOf(contract))
        assert(not contract:SubsetOf(tbl))
    end)

    it("errors when trying to modify a table without a defined structure", function()
        local tbl = Table()
        tbl.contract = Table()
        assert(not tbl:Set(String("foo"), Number(1337)))
    end)

    it("copy from constness should work", function()
        local contract = Table()
        contract:Set(String("foo"), String("bar"))
        contract:Set(String("a"), Number())

        local tbl = Table()
        tbl:Set(String("foo"), String("bar"))
        tbl:Set(String("a"), Number(1337))

        assert(tbl:CopyLiteralness(contract))
        assert(assert(tbl:Get(String("foo"))):IsLiteral())
    end)

    do return end
    do
        local IAge = Table()
        IAge:Set(String("age", true), Number(), true)

        local IName = Table()
        IName:Set(String("name"), String())
        IName:Set(String("magic"), String("deadbeef", true))

        local function introduce(person)
            io.write(string.format("Hello, my name is %s and I am %s years old.", person:Get(O("string", "name")), person:Get(O("string", "age")) ),"\n")
        end

        local Human = IAge:Union(IName)
        Human:Lock()


        assert(IAge:SubsetOf(Human), "IAge should be a subset of Human")
        Human:Set(O("string", "name", true), O("string", "gunnar"))
        Human:Set(O("string", "age", true), O("number", 40))

        assert(Human:Get(O("string", "name", true)).data == "gunnar")
        assert(Human:Get(O("string", "age", true)).data == 40)

        Human:Set(O("string", "magic"), O("string", "lol"))
    end
end)