-- Bug #4: Method calls on values returned from generic constructors
-- "type symbol : nil cannot be called"
--
-- When a generic function returns an object with a metatable,
-- calling methods on the result produces "nil cannot be called".
-- ============================================================
-- BASELINE: metatable methods work on non-generic constructor
-- ============================================================
analyze[[
    local Foo = {}
    Foo.__index = Foo
    type Foo.@Name = "Foo"
    type Foo.@SelfArgument = {
        ["value"] = number,
        @MetaTable = Foo,
    }

    function Foo:GetValue(): number
        return self.value
    end

    local function new_foo(): Foo.@SelfArgument
        return setmetatable({value = 42} as Foo.@SelfArgument, Foo)
    end

    local f = new_foo()
    local v = f:GetValue()
    attest.equal(v, _ as number)
]]
-- ============================================================
-- Test A: generic constructor, method call on local variable
-- ============================================================
analyze[[
    local Foo = {}
    Foo.__index = Foo
    type Foo.@Name = "Foo"
    type Foo.@SelfArgument = {
        ["value"] = number,
        @MetaTable = Foo,
    }

    function Foo:GetValue(): number
        return self.value
    end

    local function new_foo<|T: any|>(): Foo.@SelfArgument
        return setmetatable({value = 42} as Foo.@SelfArgument, Foo)
    end

    local f = new_foo<|string|>()
    local v = f:GetValue()
    attest.equal(v, _ as number)
]]
-- ============================================================
-- Test B: generic constructor, method call without explicit type args
-- ============================================================
analyze[[
    local Foo = {}
    Foo.__index = Foo
    type Foo.@Name = "Foo"
    type Foo.@SelfArgument = {
        ["value"] = number,
        @MetaTable = Foo,
    }

    function Foo:GetValue(): number
        return self.value
    end

    local function new_foo<|T: any|>(): Foo.@SelfArgument
        return setmetatable({value = 42} as Foo.@SelfArgument, Foo)
    end

    local f = new_foo()
    local v = f:GetValue()
    attest.equal(v, _ as number)
]]
-- ============================================================
-- Test C: generic constructor, inline method call (no local)
-- ============================================================
analyze[[
    local Foo = {}
    Foo.__index = Foo
    type Foo.@Name = "Foo"
    type Foo.@SelfArgument = {
        ["value"] = number,
        @MetaTable = Foo,
    }

    function Foo:GetValue(): number
        return self.value
    end

    local function new_foo<|T: any|>(): Foo.@SelfArgument
        return setmetatable({value = 42} as Foo.@SelfArgument, Foo)
    end

    local v = new_foo<|string|>():GetValue()
    attest.equal(v, _ as number)
]]
-- ============================================================
-- Test D: non-generic constructor, inline method call
-- ============================================================
analyze[[
    local Foo = {}
    Foo.__index = Foo
    type Foo.@Name = "Foo"
    type Foo.@SelfArgument = {
        ["value"] = number,
        @MetaTable = Foo,
    }

    function Foo:GetValue(): number
        return self.value
    end

    local function new_foo(): Foo.@SelfArgument
        return setmetatable({value = 42} as Foo.@SelfArgument, Foo)
    end

    local v = new_foo():GetValue()
    attest.equal(v, _ as number)
]]
-- ============================================================
-- Test E: generic constructor using typed local instead of as-cast
-- (the pattern from our reactive project)
-- ============================================================
analyze[[
    local Foo = {}
    Foo.__index = Foo
    type Foo.@Name = "Foo"
    type Foo.@SelfArgument = {
        ["value"] = number,
        @MetaTable = Foo,
    }

    function Foo:GetValue(): number
        return self.value
    end

    local function new_foo<|T: any|>(): Foo.@SelfArgument
        local self: Foo.@SelfArgument = {
            value = 42,
        }
        setmetatable(self, Foo)
        return self
    end

    local f = new_foo<|string|>()
    local v = f:GetValue()
    attest.equal(v, _ as number)
]]
-- ============================================================
-- Test F: exported through module table
-- ============================================================
analyze[[
    local Foo = {}
    Foo.__index = Foo
    type Foo.@Name = "Foo"
    type Foo.@SelfArgument = {
        ["value"] = number,
        @MetaTable = Foo,
    }

    function Foo:GetValue(): number
        return self.value
    end

    local M = {}
    local function new_foo<|T: any|>(): Foo.@SelfArgument
        return setmetatable({value = 42} as Foo.@SelfArgument, Foo)
    end
    M.new = new_foo

    local f = M.new<|string|>()
    local v = f:GetValue()
    attest.equal(v, _ as number)
]]
