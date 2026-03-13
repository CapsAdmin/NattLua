local nl = require("nattlua")
local stringx = require("nattlua.other.string")
local path_util = require("nattlua.other.path")

local function check(config, input, expect)
	expect = expect or input
	expect = stringx.replace(expect, "    ", "\t")
	config = config or {}

	if config.comment_type_annotations == nil then
		config.comment_type_annotations = false
	end

	local new_lua_code = assert(nl.Compiler(input, nil, {emitter = config}):Emit())

	if new_lua_code ~= expect then print(diff(new_lua_code, expect)) end

	equal(new_lua_code, expect, 2)
end

local function identical(str)
	check({pretty_print = true}, str)
end

local function emit_and_run(input, config)
	config = config or {}
	config.parser = config.parser or {}
	config.emitter = config.emitter or {}
	local output = assert(
		nl.Compiler(
			input,
			nil,
			{
				parser = {
					emit_environment = config.parser.emit_environment == nil and false or config.parser.emit_environment,
					working_directory = config.parser.working_directory or "./",
					cache_imports_like_require = config.parser.cache_imports_like_require,
				},
				emitter = {
					pretty_print = config.emitter.pretty_print == nil and true or config.emitter.pretty_print,
					force_parenthesis = config.emitter.force_parenthesis == nil and true or config.emitter.force_parenthesis,
					string_quote = config.emitter.string_quote or "\"",
				},
			}
		):Emit()
	)
	local env = {
		assert = assert,
		getmetatable = getmetatable,
		rawget = rawget,
		setmetatable = setmetatable,
		type = type,
		import = {loaded = {}},
		package = {loaded = {}, preload = {}},
	}

	if config.env then
		for k, v in pairs(config.env) do
			env[k] = v
		end
	end

	env.require = function(name)
		local loaded = env.package.loaded[name]

		if loaded ~= nil then return loaded end

		local loader = env.package.preload[name]
		assert(loader, "module '" .. name .. "' not found")
		env.package.loaded[name] = true
		local res = loader(name)

		if res ~= nil then
			env.package.loaded[name] = res
		elseif env.package.loaded[name] == nil then
			env.package.loaded[name] = true
		end

		return env.package.loaded[name]
	end
	env._G = env
	local chunk = assert(loadstring(output))
	setfenv(chunk, env)
	return output, env, {chunk()}
end

do
	local import_path = "test/tests/nattlua/analyzer/file_importing/require_cache/alias_shared.lua"
	local _, _, results = emit_and_run(
		("local a = import(\"%s\")\nlocal b = import(\"%s\")\nreturn a == b"):format(import_path, import_path)
	)

	equal(results[1], false)
end

do
	local import_path = "test/tests/nattlua/analyzer/file_importing/require_cache/alias_shared.lua"
	local output, _, results = emit_and_run(
		("local a = import(\"%s\")\nlocal b = import(\"%s\")\nreturn a == b"):format(import_path, import_path),
		{
			parser = {
				cache_imports_like_require = true,
			},
		}
	)

	assert(output:find("do local __HAS_RUN = false local __M IMPORTS%['" .. import_path:gsub("%.", "%%.") .. "'%]", nil, false))
	assert(output:find("if __HAS_RUN then return __M end", nil, true))
	assert(output:find(import_path, nil, true))
	equal(results[1], true)
end

do
	local old_resolve = path_util.Resolve
	path_util.Resolve = function(path, root_directory, working_directory, file_path)
		if path == "alias.one" or path == "alias.two" then
			return "test/tests/nattlua/analyzer/file_importing/require_cache/alias_shared.lua"
		end

		return old_resolve(path, root_directory, working_directory, file_path)
	end

	local ok, err = pcall(function()
		local _, _, results = emit_and_run(
			[[local a = import("alias.one")
local b = import("alias.two")
return a == b]],
			{
				parser = {
					cache_imports_like_require = true,
				},
			}
		)

		equal(results[1], false)
	end)

	path_util.Resolve = old_resolve
	assert(ok, err)
end

do
	local _, env, results = emit_and_run(
		[[local a = import("test/fixtures/emitter_import_cache/cycle_a.lua")
return a.other.other == a]],
		{
			parser = {
				cache_imports_like_require = true,
			},
		}
	)

	equal(results[1], true)
	assert(env.import)
	assert(env.import.loaded)
	assert(env.import.loaded["test/fixtures/emitter_import_cache/cycle_a.lua"])
	assert(env.import.loaded["test/fixtures/emitter_import_cache/cycle_b.lua"])
end

do
	local import_path = "test/tests/nattlua/analyzer/file_importing/require_cache/alias_shared.lua"
	local output, env, results = emit_and_run(
		([[local static = import(%q)
local dynamic = import("test/tests/nattlua/analyzer/file_importing/require_cache/" .. "alias_shared.lua")
return static == dynamic]]):format(import_path),
		{
			parser = {
				cache_imports_like_require = true,
			},
			env = {
				import = setmetatable(
					{
						loaded = {},
						fallback_calls = {},
					},
					{
						__call = function(self, name)
							self.fallback_calls[name] = (self.fallback_calls[name] or 0) + 1
							error("unexpected fallback import: " .. tostring(name))
						end,
					}
				),
			},
		}
	)

	assert(output:find("__NATTLUA_CALL_IMPORT_FALLBACK", nil, true))
	assert(output:find("local loader = __NATTLUA_RAWGET%(IMPORTS, key%)", nil, false))
	equal(results[1], true)
	equal(env.import.fallback_calls[import_path], nil)
	assert(env.import.loaded[import_path])
end

do
	local output = assert(
		nl.Compiler(
			[[#!/usr/bin/env lua
local dep = import("./shebang_import_dep.nlua")]],
			nil,
			{
				parser = {
					working_directory = "test/tests/nattlua/",
					emit_environment = false,
				},
				emitter = {
					pretty_print = true,
					force_parenthesis = true,
					string_quote = "\"",
				},
			}
		):Emit()
	)

	assert(output:find("^#!/usr/bin/env lua\n_G%.IMPORTS = _G%.IMPORTS or %{%}\n") ~= nil)
	assert(select(2, output:gsub("#!", "")) == 1)
end

do
	local module_name = "test.tests.nattlua.analyzer.file_importing.require_cache.returns_nil"
	local _, env, results = emit_and_run(
		[=[local a = require("test.tests.nattlua.analyzer.file_importing.require_cache.returns_nil")
local b = require("test.tests.nattlua.analyzer.file_importing.require_cache.returns_nil")
return a, b, package.loaded["test.tests.nattlua.analyzer.file_importing.require_cache.returns_nil"]]=]
	)

	equal(results[1], true)
	equal(results[2], true)
	equal(results[3], true)
	equal(env.package.loaded[module_name], true)
	equal(env.__returns_nil_counter, 1)
end

do
	local module_name = "test.tests.nattlua.analyzer.file_importing.require_cache.returns_false"
	local _, env, results = emit_and_run(
		[=[local a = require("test.tests.nattlua.analyzer.file_importing.require_cache.returns_false")
local b = require("test.tests.nattlua.analyzer.file_importing.require_cache.returns_false")
return a, b, package.loaded["test.tests.nattlua.analyzer.file_importing.require_cache.returns_false"]]=]
	)

	equal(results[1], false)
	equal(results[2], false)
	equal(results[3], false)
	equal(env.package.loaded[module_name], false)
	equal(env.__returns_false_counter, 1)
end

do
	local module_name = "test.tests.nattlua.analyzer.file_importing.require_cache.returns_nil"
	local output, env, results = emit_and_run(
		[=[local original_require = require
local value = require("test.tests.nattlua.analyzer.file_importing.require_cache.returns_nil")
return original_require == require, value]=]
	)

	assert(output:find("package%.preload", nil, false))
	assert(env.require == env._G.require)
	equal(results[1], true)
	equal(results[2], true)
	equal(env.package.loaded[module_name], true)
	local first = env.require(module_name)
	local second = env.require(module_name)
	equal(first, true)
	equal(second, true)
	equal(env.package.loaded[module_name], true)
	equal(env.__returns_nil_counter, 1)
end

do
	local old_resolve_require = path_util.ResolveRequire
	path_util.ResolveRequire = function(str)
		if str == "alias.one" or str == "alias.two" then
			return "test/tests/nattlua/analyzer/file_importing/require_cache/alias_shared.lua"
		end

		return old_resolve_require(str)
	end

	local ok, err = pcall(function()
		local output, env, results = emit_and_run(
			[=[local a = require("alias.one")
local b = require("alias.two")
a.foo = 1
b.foo = 2
return a.foo, b.foo, package.loaded["alias.one"].foo, package.loaded["alias.two"].foo]=]
		)

		assert(output:find("package%.loaded%[\"alias%.one\"%]", nil, false))
		assert(output:find("package%.loaded%[\"alias%.two\"%]", nil, false))
		equal(results[1], 1)
		equal(results[2], 2)
		equal(results[3], 1)
		equal(results[4], 2)
		assert(env.package.loaded["alias.one"] ~= env.package.loaded["alias.two"])
	end)

	path_util.ResolveRequire = old_resolve_require
	assert(ok, err)
end

check(
	{pretty_print = true, force_parenthesis = true, string_quote = "\""},
	[[local foo = aaa 'aaa'-- dawdwa
local x = 1]],
	[[local foo = aaa("aaa") -- dawdwa
local x = 1]]
)
check({pretty_print = true, string_quote = "\""}, [[local x = "'"]])
check({pretty_print = true, string_quote = "'"}, [[local x = '"']])
identical([[x = "" -- foo]])
identical([[new_str[i] = "\\" .. c]])
identical([[local x = "\xFE\xFF\n\u{1F602}\t\t1"]])
check(
	{pretty_print = true, comment_type_annotations = true},
	[[local type x = ""]],
	[=[--[[#local type x = ""]]]=]
)
check({string_quote = "'"}, [[x = "foo"]], [[x = 'foo']])
check({string_quote = "\""}, [[x = 'foo']], [[x = "foo"]])
check({string_quote = "\"", pretty_print = true}, [[x = '\"']], [[x = "\""]])
check({string_quote = "\""}, [[x = '"foo"']], [[x = "\"foo\""]])
check({pretty_print = true}, [[x         = 
	
	1]], [[x = 1]])
check({no_semicolon = true}, [[x = 1;]], [[x = 1]])
check(
	{no_semicolon = true},
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
check(
	{
		extra_indent = {StartSomething = {to = "EndSomething"}},
		pretty_print = true,
	},
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
check(
	{
		extra_indent = {StartSomething = {to = "EndSomething"}},
		pretty_print = true,
	},
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
identical([==[local x = {[ [[foo]] ] = "bar"}]==])
check(
	{pretty_print = true},
	[==[local x = a && b || c && a != c || !c]==],
	[==[local x = a and b or c and a ~= c or not c]==]
)
identical([[local escape_char_map = {
	["\\"] = "\\\\",
	["\""] = "\\\"",
	["\b"] = "\\b",
	["\f"] = "\\f",
	["\n"] = "\\n",
	["\r"] = "\\r",
	["\t"] = "\\t",
}]])
identical([==[--[#[analyzer function coroutine.wrap(cb: Function) end]]]==])
identical([[local tbl = {
	foo = true,
	foo = true,
	foo = true,
	foo = true,
	foo = true,
	foo = true,
	foo = true,
	foo = true,
	foo = true,
}]])
-- TODO, double indent because of assignment and call
identical([[pos, ang = LocalToWorld(
	lexer.Position or Vector(),
	lexer.Angles or Angle(),
	pos or owner:GetPos(),
	ang or owner:GetAngles()
)]])
identical([[if not ply.pac_cameras then return end]])
check({pretty_print = true}, [[foo({foo = 1})]], [[foo({foo = 1})]])
check(
	{pretty_print = true},
	[[foo({foo = 1, bar = 2, baz = 3, qux = 4})]],
	[[foo{foo = 1, bar = 2, baz = 3, qux = 4}]]
)
check(
	{pretty_print = true, force_parenthesis = true},
	[[foo({foo = 1, bar = 2, baz = 3, qux = 4})]],
	[[foo({foo = 1, bar = 2, baz = 3, qux = 4})]]
)
check(
	{
		pretty_print = true,
		force_parenthesis = true,
		omit_parentheses_for_single_table_call = true,
	},
	[[foo({foo = 1, bar = 2, baz = 3, qux = 4})]],
	[[foo{foo = 1, bar = 2, baz = 3, qux = 4}]]
)
check(
	{
		pretty_print = true,
		force_parenthesis = true,
		omit_parentheses_for_single_table_call = true,
	},
	"foo{\n\tfoo = bar,\n\tblah = blah,\n\tfoo = function() end,\n}",
	"foo{\n\tfoo = bar,\n\tblah = blah,\n\tfoo = function() end,\n}"
)
check(
	{
		pretty_print = true,
		force_parenthesis = true,
		omit_parentheses_for_single_table_call = true,
	},
	"Button{\n\tSize = Vec2(30, 30),\n\tMode = \"filled\",\n\tlayout = {\n\t\tDirection = \"x\",\n\t\tAlignmentY = \"center\",\n\t\tFitHeight = true,\n\t\tGrowWidth = 1,\n\t},\n}{\n\tText{Text = \"Text Button\", IgnoreMouseInput = true},\n}",
	"Button{\n\tSize = Vec2(30, 30),\n\tMode = \"filled\",\n\tlayout = {\n\t\tDirection = \"x\",\n\t\tAlignmentY = \"center\",\n\t\tFitHeight = true,\n\t\tGrowWidth = 1,\n\t},\n}{\n\tText{Text = \"Text Button\", IgnoreMouseInput = true},\n}"
)
check(
	{pretty_print = true},
	[[foo({
	foo = bar,
	blah = blah,
	foo = function() end,
})]],
	[[foo{
	foo = bar,
	blah = blah,
	foo = function() end,
}]]
)
check(
	{pretty_print = true, comment_type_annotations = true},
	[=[--[[#type Vector.__mul = function=(Vector, number | Vector)>(Vector)]]]=]
)
check(
	{pretty_print = true, comment_type_annotations = true},
	[=[--[[#type start = function=(...string)>(nil)]]]=]
)
check(
	{pretty_print = true, comment_type_annotations = true},
	[[return {lol = Partial<|{foo = true}|>}]],
	[=[return {lol = --[[#Partial<|{foo = true}|>]]nil}]=]
)
check(
	{
		pretty_print = true,
		comment_type_annotations = true,
		omit_invalid_code = true,
	},
	[[return {lol = Partial<|{foo = true}|>}]],
	[[return {lol = nil}]]
)
check(
	{
		pretty_print = true,
		comment_type_annotations = true,
		omit_invalid_code = true,
	},
	[[local lol = Partial<|{foo = true}|>]],
	[[local lol = nil]]
)
check(
	{
		pretty_print = true,
		comment_type_annotations = true,
		omit_invalid_code = true,
	},
	[[lol = Partial<|{foo = true}|>]],
	[[lol = nil]]
)
check(
	{
		pretty_print = true,
		comment_type_annotations = true,
		omit_invalid_code = true,
	},
	[[x = {...todo, ...fieldsToUpdate, foo = true}]],
	[[x = table.mergetables{todo, fieldsToUpdate, {foo = true}}]]
)
check(
	{
		pretty_print = true,
		comment_type_annotations = true,
		omit_invalid_code = false,
	},
	[[x = {...todo, ...fieldsToUpdate, foo = true}]],
	[[x = {...todo, ...fieldsToUpdate, foo = true}]]
)
check(
	{
		pretty_print = true,
		comment_type_annotations = true,
		omit_invalid_code = true,
	},
	[[foo<|"lol"|>]],
	[[]]
)
check({pretty_print = true, type_annotations = true}, [=[local type x = (...,)]=])
check(
	{
		pretty_print = true,
		comment_type_annotations = true,
		type_annotations = true,
	},
	[=[local args--[[#: List<|string | List<|string|>|>]]]=]
)
check(
	{
		pretty_print = true,
		comment_type_annotations = true,
		type_annotations = true,
	},
	[=[return function()--[[#: number]] end]=]
)
check(
	{
		pretty_print = true,
		comment_type_annotations = true,
		type_annotations = true,
	},
	[=[--[[#analyzer function load(code: string | function=()>(string | nil), chunk_name: string | nil) end]]]=]
)
identical([[local x = lexer.OnDraw and
	(
		draw_type == "viewmodel" or
		draw_type == "hands" or
		(
			(
				lexer.Translucent == true or
				lexer.force_translucent == true
			)
			and
			draw_type == "translucent"
		)
		or
		(
			(
				lexer.Translucent == false or
				lexer.force_translucent == false
			)
			and
			draw_type == "opaque"
		)
	)]])
identical([[local cond = key ~= "ParentUID" and
	key ~= "ParentName" and
	key ~= "UniqueID" and
	(
		key ~= "AimPartName" and
		not (
			pac.PartNameKeysToIgnore and
			pac.PartNameKeysToIgnore[key]
		)
		or
		key == "AimPartName" and
		table.HasValue(pac.AimPartNames, value)
	)]])
identical([[ent = pac.HandleOwnerName(
		lexer:GetPlayerOwner(),
		lexer.OwnerName,
		ent,
		lexer,
		function(e)
			return e.pac_duplicate_attach_uid ~= lexer.UniqueID
		end
	) or
	NULL]])
identical([[render.OverrideBlendFunc(
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
identical([[return function(config)
	local self = setmetatable({}, META)
	self.config = config or {}
	self:Initialize()
	return self
end]])
identical([[if
	val == "string" or
	val == "number" or
	val == "boolean" or
	val == "true" or
	val == "false" or
	val == "nil"
then

end]])
identical([[function META:IsShortIfStatement(node)
	return #node.statements == 1 and
		node.statements[1][1] and
		is_short_statement(node.statements[1][1].Type) and
		not self:ShouldBreakExpressionList({node.expressions[1]})
end]])
identical([[local x = val == "string" or
	val == "number" or
	val == "boolean" or
	val == "true" or
	val == "false" or
	val == "nil"]])
identical([[if true then return end]])
identical([[ok, err = pcall(function()
	s = s .. tostring(node)
end)]])
identical([[local str = {}

for i = 1, select("#", ...) do
	str[i] = tostring(select(i, ...))
end]])
identical([[if
	scope.node and
	scope.node.inferred_type and
	scope.node.inferred_type.Type == "function" and
	not scope:Contains(from)
then
	return not scope.node.inferred_type:IsCalled()
end]])
identical([[if upvalue:IsImmutable() then
	return self:Cannot({"cannot assign to const variable ", key})
end]])
identical([[if self:IsRuntime() then
	return self:GetMutatedUpvalue(upvalue) or upvalue:GetValue()
end]])
identical([[if line then str = 1 else str = 2 end]])
identical([[if t > 0 then msg = "\n" .. msg end]])
identical([[return function()
	if obj.Type == "upvalue" then union:SetUpvalue(obj) end
end]])
identical([[local foo = {
	x = 1,
	y = 2,
	z = 3,
	z = 3,
	z = 3,
	z = 3,
	z = 3,
	z = 3,
	z = 3,
	z = 3,
	z = 3,
}
local foo = function()
	for i = 1, 100 do

	end
end
local foo = x{
	x = 1,
	y = 2,
	z = 3,
	z = 3,
	z = 3,
	z = 3,
	z = 3,
	z = 3,
	z = 3,
	z = 3,
	z = 3,
}]])
identical([[local union = stack[#stack].falsy --:Copy()
if obj.Type == "upvalue" then union:SetUpvalue(obj) end

if not ok then
	print("DebugStateString: failed to render node: " .. tostring(err))
	ok, err = pcall(function()
		s = s .. tostring(node)
	end)

	if not ok then
		print("DebugStateString: failed to tostring node: " .. tostring(err))
		s = s .. "* error in rendering statement * "
	end
end]])
identical([[setmetatable(
	{
		Code = Code(lua_code, name),
		parent_line = parent_line,
		parent_name = parent_name,
		config = config,
		Lexer = requirew("nattlua.lexer.lexer"),
		Parser = requirew("nattlua.parser.parser"),
		Analyzer = requirew("nattlua.analyzer.analyzer"),
		Emitter = config and
			config.js and
			requirew("nattlua.transpiler.javascript_emitter") or
			requirew("nattlua.emitter.emitter"),
	},
	META
)]])
identical([[if not ok then
	assert(err)
	return ok, err
end]])
identical([[return {
	AnalyzeImport = function(self, node)
		local args = self:AnalyzeExpressions(node.expressions)
		return self:AnalyzeRootStatement(node.root, table.unpack(args))
	end,
}]])
identical([[local foo = 1
-- hello
-- world
local union = stack[#stack].falsy --:Copy()
local x = 1]])
identical([[return {
	AnalyzeContinue = function(self, statement)
		self._continue_ = true
	end,
}]])
identical([[if name:sub(1, 1) == "@" then -- is this a name that is a location?
	local line, rest = msg:sub(#name):match("^:(%d+):(.+)") -- remove the file name and grab the line number
end

-- foo
-- bar
local foo = aaa'aaa' -- dawdwa
local x = 1]])
identical([=[local type { 
	ExpressionKind,
	StatementKind,
	FunctionAnalyzerStatement,
	FunctionTypeStatement,
	FunctionAnalyzerExpression,
	FunctionTypeExpression,
	FunctionExpression,
	FunctionLocalStatement,
	FunctionLocalTypeStatement,
	FunctionStatement,
	FunctionLocalAnalyzerStatement,
	ValueExpression
 } = importawd("~/nattlua/parser/node.lua")]=])
check(
	{
		pretty_print = true,
		comment_type_annotations = true,
		type_annotations = true,
	},
	[=[function META:OnError(
	code--[[#: Code]],
	message--[[#: string]],
	start--[[#: number]],
	stop--[[#: number]],
	...--[[#: ...any]]
) end]=]
)
identical([[local type Context = {
	tab = number,
	tab_limit = number,
	done = Table,
}]])
check(
	{
		pretty_print = true,
		comment_type_annotations = true,
		type_annotations = true,
	},
	[=[--[[#type coroutine = {
	create = function=(AnyFunction)>(thread),
	close = function=(thread)>(boolean, string),
	isyieldable = function=()>(boolean),
	resume = function=(thread, ...)>(boolean, ...),
	running = function=()>(thread, boolean),
	status = function=(thread)>(string),
	wrap = function=(AnyFunction)>(AnyFunction),
	yield = function=(...)>(...),
}]]]=]
)
identical([[return {
	character_start = character_start or 0,
	character_stop = character_stop or 0,
	sub_line_after = {stop + 1, within_stop - 1},
	line_start = line_start or 0,
	line_stop = line_stop or 0,
}]])
identical([[return function(config)
	config = config or {}
	local self = setmetatable({config = config}, META)

	for _, func in ipairs(META.Test) do
		func(self)
	end

	return self
end]])
check(
	{
		pretty_print = true,
		comment_type_annotations = false,
		type_annotations = true,
	},
	[[local function lasterror(): string, number
	return "", 0
end]]
)
identical([[
local name = ReadSpace(self) or
	ReadCommentEscape(self) or
	ReadMultilineCComment(self) or
	ReadLineCComment(self) or
	ReadMultilineComment(self) or
	ReadLineComment(self)]])
identical([[do
	while
		runtime_syntax:Lol(self:GetToken()) and
		runtime_syntax:Lol(self:GetToken()).left_priority > priority
	do

	end
end]])
check(
	{
		pretty_print = true,
		comment_type_annotations = true,
		type_annotations = true,
	},
	[=[if B.Type == "tuple" then B = (B--[[# as any]]):GetWithNumber(1) end]=]
)
check(
	{
		pretty_print = true,
		comment_type_annotations = true,
		type_annotations = true,
	},
	[=[return ffi.string(A, (B)--[[# as number]])
return ffi.string(A, (((B))--[[# as number]]))
return ffi.string(A, (B--[[# as number]]))]=]
)
check(
	{
		pretty_print = true,
		comment_type_annotations = true,
		type_annotations = true,
	},
	[=[--[[#£parser.config.skip_import = true]]

local x = import("platforms/windows/filesystem.nlua")]=]
)
do
	local input = [[
		assert(loadfile("game/run.lua"))()
		local f = assert(loadfile("test/run.lua"))
		assert(loadfile("game/run.lua"))()
	]]
	local output = assert(
		nl.Compiler(
			input,
			nil,
			{
				parser = {skip_import = true},
				emitter = {
					pretty_print = true,
					force_parenthesis = true,
					string_quote = "\"",
					skip_import = true,
				},
			}
		):Emit()
	)
	assert(output:find("assert%(loadfile%(\"game/run%.lua\"%)%)%(") ~= nil)
	assert(output:find("local f = assert%(loadfile%(\"test/run%.lua\"%)%)") ~= nil)
	assert(output:find("assert%(loadfile%)%(") == nil)
	assert(output:find("local f = assert%(loadfile%)") == nil)
end
identical([[hook.Add("Foo", "bar_foo", function(ply, pos)
    for i = 1, 10 do
        ply:SetPos(pos + VectorRand())
    end
end)]])
identical([=[run[[
aw
d
aw
dawd
]]]=])
identical([=[run([[
aw
d
aw
dawd
]])]=])
identical([[local x = "\xFE\xFF"]])
check(
	{string_quote = "\""},
	[[
	code = code:gsub('\\"', "____DOUBLE_QUOTE_ESCAPE")
]],
	[[
	code = code:gsub("\\\"", "____DOUBLE_QUOTE_ESCAPE")
]]
)
check(
	{string_quote = "\""},
	[[
	code = code:gsub('\\\"', "____DOUBLE_QUOTE_ESCAPE")
]],
	[[
	code = code:gsub("\\\"", "____DOUBLE_QUOTE_ESCAPE")
]]
)
check(
	{string_quote = "\""},
	[[
	code = code:gsub('\\\\"', "____DOUBLE_QUOTE_ESCAPE")
]],
	[[
	code = code:gsub("\\\\\"", "____DOUBLE_QUOTE_ESCAPE")
]]
)
check(
	{
		pretty_print = true,
		comment_type_annotations = true,
		type_annotations = true,
	},
	[=[
		repeat
			if test then
			end
		until foo
	]=],
	[[repeat
	if test then  end
until foo]]
)
