local T = require("spec.lua.helpers")
local O = T.Object
local N = T.Number
local S = T.String
local Table = T.Table
local Set = T.Set
local Tuple = T.Tuple

describe("table", function()
    it("set and get should work", function()
        local contract = Table()
        assert(contract:Set(S("foo"), O("number")))
        assert(assert(contract:Get("foo")):IsType("number"))
        assert.equal(false, contract:Get(S("asdf")))

        local tbk = Table()
        tbk.contract = contract
        assert(tbk:Set(S("foo"), N(1337)))
        assert.equal(1337, tbk:Get(S("foo")):GetData())

        assert(tbk:SubsetOf(contract))
        assert(not contract:SubsetOf(tbk))
    end)

    it("set string and get constant string should work", function()
        local contract = Table()
        assert(contract:Set(O("string"), O("number")))

        local tbk = Table()
        tbk.contract = contract
        tbk:Set(O("string"), N(1337))
        assert.equal(1337, assert(tbk:Get(O("string"))):GetData())

        assert(tbk:SubsetOf(contract))
        assert(not contract:SubsetOf(tbk))
    end)

    it("errors when trying to modify a table without a defined structure", function()
        local tbk = Table()
        tbk.contract = Table()
        assert(not tbk:Set(S("foo"), N(1337)))
    end)

    it("copy from constness should work", function()
        local contract = Table()
        contract:Set(S("foo"), S("bar"))
        contract:Set(S("a"), O("number"))

        local tbk = Table()
        tbk:Set(S("foo"), O("string", "bar"))
        tbk:Set(S("a"), N(1337))

        assert(tbk:CopyConstness(contract))
        assert(assert(tbk:Get(S("foo"))):IsConst())
    end)

    do return end
    do
        local IAge = Table()
        IAge:Set(Object("string", "age", true), Object("number"), true)

        local IName = Table()
        IName:Set(Object("string", "name", true), Object("string"))
        IName:Set(Object("string", "magic", true), Object("string", "deadbeef", true))

        local function introduce(person)
            io.write(string.format("Hello, my name is %s and I am %s years old.", person:Get(Object("string", "name")), person:Get(Object("string", "age")) ),"\n")
        end

        local Human = IAge:Union(IName)
        Human:Lock()


        assert(IAge:SubsetOf(Human), "IAge should be a subset of Human")
        Human:Set(Object("string", "name", true), Object("string", "gunnar"))
        Human:Set(Object("string", "age", true), Object("number", 40))

        assert(Human:Get(Object("string", "name", true)).data == "gunnar")
        assert(Human:Get(Object("string", "age", true)).data == 40)

        Human:Set(Object("string", "magic"), Object("string", "lol"))
    end
end)