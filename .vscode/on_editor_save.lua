local nl = require("nattlua")
_G.ON_EDITOR_SAVE = true
local path = ...

if not path then error("no path") end

local full_path = path
path = path:lower():gsub("\\", "/")

local function run_lua(path, ...)
	io.write("running ", path, ...)
	assert(loadfile(path))(...)
	io.write(" - ok\n")
end

local function run_nattlua(path)
	local f = assert(io.open(path, "r"))
	local lua_code = f:read("*all")
	f:close()

	local function has_flag(flag)
		return lua_code:find("--" .. flag .. "\n", nil, true) ~= nil
	end

	if has_flag("PLAIN_LUA") then return assert(loadfile(path))() end

	local c = assert(
		nl.File(
			path,
			{
				emitter = {type_annotations = true},
			--inline_require = lua_code:find("%-%-%s-INLINE_REQUIRE") ~= nil,
			--emit_environment = true,
			}
		)
	)
	c.debug = has_flag("VERBOSE_STACKTRACE")
	_G.DISABLE_BASE_ENV = has_flag("DISABLE_BASE_ENV")

	if has_flag("PROFILE") then require("jit.p").start("Flp") end

	local ok, err

	if not has_flag("DISABLE_ANALYSIS") then ok, err = c:Analyze() end

	if _G.DISABLE_BASE_ENV then _G.DISABLE_BASE_ENV = nil end

	if has_flag("PROFILE") then require("jit.p").stop() end

	if not ok and err then
		error(err)
		return
	end

	local res = assert(
		c:Emit(
			{
				preserve_whitespace = has_flag("PRETTY_PRINT") and false or nil,
				string_quote = "\"",
				no_semicolon = true,
				transpile_extensions = has_flag("TRANSPILE_EXTENSIONS"),
				comment_type_annotations = has_flag("COMMENT_TYPE_ANNOTATIONS"),
				type_annotations = true,
				force_parenthesis = true,
				omit_invalid_code = has_flag("OMIT_INVALID_LUA_CODE"),
				extra_indent = {
					Start = {to = "Stop"},
					Toggle = "toggle",
				},
			}
		)
	)

	if has_flag("ENABLE_CODE_RESULT_TO_FILE") then
		local f = assert(io.open("test_focus_result.lua", "w"))
		f:write(res)
		f:close()
	elseif has_flag("ENABLE_CODE_RESULT") then
		print("== code result ==")

		if has_flag("SHOW_NEWLINES") then res = res:gsub("\n", "⏎\n") end

		print(res)
		print("=================")
	end

	if has_flag("RUN_CODE") then assert(load(res))() end
end

local function has_test_focus()
	local f = io.open("test_focus.nlua")

	if not f then return false end

	local str = f:read("*all")
	str = str:gsub("%s+", "")
	f:close()

	if str == "" then return false end

	return true
end

local function run_test(path)
	return run_lua("test/run.lua", path)
end

local function find(str)
	return path:find(str, nil, true) ~= nil
end

if find("on_editor_save.lua") then return end

local is_lua = full_path:sub(-4) == ".lua"
local is_nattlua = full_path:sub(-5) == ".nlua"
local test_focus = has_test_focus()

if not is_lua and not is_nattlua then return end

if full_path:lower():find("/nattlua/", nil, true) == nil and is_lua then
	print("not sure how to run (/nattlua/ not found in path) " .. full_path)
	print("running as normal lua")
	run_lua(full_path)
	return
end

if is_nattlua and not test_focus then
	run_nattlua(full_path)
	return
end

if find("intersect_comparison") then
	run_test("test/tests/nattlua/types/number.lua")
elseif find("jit_options") then
	run_lua("test/performance/tests.lua")
elseif find("jit_trace_track") or find("test/performance/analyzer.lua") then
	run_lua("test/performance/analyzer.lua")
elseif find("nattlua/analyzer/mutation_solver.lua") and not test_focus then
	run_lua("test/tests/nattlua/analyzer/mutation_solver.lua")
elseif find("c_declarations/main.lua") and not test_focus then
	run_test("test/tests/nattlua/c_declarations/cdef.nlua")
	run_test("test/tests/nattlua/c_declarations/parsing.lua")
	run_test("test/tests/nattlua/analyzer/typed_ffi.lua")
	run_lua("examples/projects/luajit/build.lua", full_path)
	run_lua("examples/projects/love2d/nlconfig.lua", full_path)
elseif find("c_declarations/analyzer") and not test_focus then
	run_test("test/tests/nattlua/c_declarations/cdef.nlua")
elseif find("c_declarations") and not test_focus then
	run_test("test/tests/nattlua/c_declarations/parsing.lua")
elseif find("coverage") then
	run_test("test/tests/coverage.lua")
elseif find("nattlua/editor_helper/editor.lua") then
	run_test("test/tests/lsp/editor.lua")
	os.execute("luajit nattlua.lua build fast && luajit nattlua.lua install")
elseif find("language_server/server") then
	os.execute("luajit nattlua.lua build fast && luajit nattlua.lua install")
elseif find("typed_ffi.nlua") and test_focus then
	print("running test focus")
	run_nattlua("./test_focus.nlua")
elseif find("lint.lua") then
	run_lua(full_path)
elseif find("build_glua_base.lua") then
	run_lua(full_path)
elseif find("examples/projects/luajit/") or find("cparser.lua") then
	run_lua("examples/projects/luajit/build.lua", full_path)
elseif find("examples/projects/love2d/") then
	run_lua("examples/projects/love2d/nlconfig.lua", full_path)
elseif is_nattlua and not find("/definitions/") then
	run_nattlua(full_path)
elseif find("formating.lua") then
	run_test("test/tests/nattlua/code_pointing.lua")
elseif find("test/") then
	run_test(full_path)
elseif find("javascript_emitter") then
	run_lua("./examples/lua_to_js.lua")
elseif find("examples/") then
	run_lua(full_path)
elseif test_focus then
	print("running test focus")
	run_nattlua("./test_focus.nlua")
elseif find("lexer.lua") then
	run_test("test/tests/nattlua/lexer.lua")
	run_test("test/performance/lexer.lua")
elseif find("parser.lua") then
	run_test("test/tests/nattlua/parser.lua")
	run_test("test/performance/parser.lua")
else
	run_lua("test/run.lua")
end
