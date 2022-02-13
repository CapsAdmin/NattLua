local nl = require("nattlua")

local function check(config, input, expect)
    expect = expect or input
    expect = expect:gsub("    ", "\t")
    local new_lua_code = assert(nl.Compiler(input, nil, config):Emit())
    if new_lua_code ~= expect then
        diff(new_lua_code, expect)
    end
    equal(new_lua_code, expect, 2)
end

check({ preserve_whitespace = false, force_parenthesis = true, string_quote = '"' }, 
[[local foo = aaa 'aaa'
-- dawdwa
local x = 1]],
[[local foo = aaa("aaa")
-- dawdwa
local x = 1]]
)

check({ preserve_whitespace = false },
    [[x = ""-- foo]]
)
check({ preserve_whitespace = false, use_comment_types = true },
    [[local type x = ""]], [=[--[[#local type x = ""]]]=]
)

check({ string_quote = "'" },
    [[x = "foo"]], [[x = 'foo']]
)

check({ string_quote = '"' },
    [[x = 'foo']], [[x = "foo"]]
)

check({ string_quote = '"', preserve_whitespace = false },
    [[x = '\"']], [[x = "\""]]
)

check({ string_quote = '"' },
    [[x = '"foo"']], [[x = "\"foo\""]]
)

check({ preserve_whitespace = false },
    [[x         = 
    
    1]], [[x = 1]]
)

check({ no_semicolon = true },
    [[x = 1;]], [[x = 1]]
)

check({ no_semicolon = true },
[[
x = 1;
x = 2;--lol
x = 3;
]], 
[[
x = 1
x = 2--lol
x = 3
]]
)

check({ extra_indent = {StartSomething = {to = "EndSomething"}}, preserve_whitespace = false },
[[
x = 1
StartSomething()
x = 2
x = 3
EndSomething()
x = 4
]], 
[[
x = 1
StartSomething()
    x = 2
    x = 3
EndSomething()
x = 4]]
)

check({ extra_indent = {StartSomething = {to = "EndSomething"}}, preserve_whitespace = false },
[[
x = 1
pac.StartSomething()
x = 2
x = 3
pac.EndSomething()
x = 4
]], 
[[
x = 1
pac.StartSomething()
    x = 2
    x = 3
pac.EndSomething()
x = 4]]
)

check({preserve_whitespace = false}, [[local tbl = {foo = true,foo = true,foo = true,foo = true,foo = true}]], 
[[local tbl = {
    foo = true,
    foo = true,
    foo = true,
    foo = true,
    foo = true,
}]])


-- TODO, double indent because of assignment and call
check({preserve_whitespace = false}, 
[[pos, ang = LocalToWorld(
        lexer.Position or Vector(),
        lexer.Angles or Angle(),
        pos or owner:GetPos(),
        ang or owner:GetAngles()
    )]])

check({preserve_whitespace = false}, [[if not ply.pac_cameras then return end]])

check({preserve_whitespace = false}, 
[[local x = lexer.OnDraw and
    (
        draw_type == "viewmodel" or
        draw_type == "hands" or
        (
            (
                lexer.Translucent == true or
                lexer.force_translucent == true
            ) and
            draw_type == "translucent"
        ) or
        (
            (
                lexer.Translucent == false or
                lexer.force_translucent == false
            ) and
            draw_type == "opaque"
        )
    )]])

check({preserve_whitespace = false}, 
[[local cond = key ~= "ParentUID" and
    key ~= "ParentName" and
    key ~= "UniqueID" and
    (
        key ~= "AimPartName" and
        not (
            pac.PartNameKeysToIgnore and
            pac.PartNameKeysToIgnore[key]
        ) or
        key == "AimPartName" and
        table.HasValue(pac.AimPartNames, value)
    )]])

check({preserve_whitespace = false}, 
[[ent = pac.HandleOwnerName(
        lexer:GetPlayerOwner(),
        lexer.OwnerName,
        ent,
        lexer,
        function(e)
            return e.pac_duplicate_attach_uid ~= lexer.UniqueID
        end
    ) or NULL]])

check({preserve_whitespace = false},
[[render.OverrideBlendFunc(
	true,
	lexer.blend_override[1],
	lexer.blend_override[2],
	lexer.blend_override[3],
	lexer.blend_override[4]
)

foo(function() end)

foo(function() end)

pac.AimPartNames = {
    ["local eyes"] = "LOCALEYES",
    ["player eyes"] = "PLAYEREYES",
    ["local eyes yaw"] = "LOCALEYES_YAW",
    ["local eyes pitch"] = "LOCALEYES_PITCH",
}]])

check({preserve_whitespace = false}, 
[[return
    function(config)
        local self = setmetatable({}, META)
        self.config = config or {}
        self:Initialize()
        return self
    end]])

check({preserve_whitespace = false}, 
[[for i, node in ipairs(block.imports) do
    if not self.done[node.path] then
        self:Emit(
            "IMPORTS['" .. node.path .. "'] = function(...) " .. node.root:Render(self.config or {}) .. " end\n"
        )
        self.done[node.path] = true
    end
end]])

check({preserve_whitespace = false}, 
[[function META:IsShortIfStatement(node)
	return
        #node.statements == 1 and
        node.statements[1][1] and
        is_short_statement(node.statements[1][1].kind) and
        not self:ShouldBreakExpressionList({node.expressions[1]})
end]])

check({preserve_whitespace = false}, 
[==[local x = {[ [[foo]] ] = "bar"}]==])

check({preserve_whitespace = false}, 
[[local escape_char_map = {
	["\\"] = "\\\\",
	["\""] = "\\\"",
	["\b"] = "\\b",
	["\f"] = "\\f",
	["\n"] = "\\n",
	["\r"] = "\\r",
	["\t"] = "\\t",
}]])

check({preserve_whitespace = false}, 
[==[--[#[analyzer function coroutine.wrap(cb: Function) end]]]==])