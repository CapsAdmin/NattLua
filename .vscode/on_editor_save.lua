local path = ...
assert(type(path) == "string", "expected path string")
local is_lua = path:sub(-4) == ".lua"
local is_nattlua = path:sub(-5) == ".nlua"

if not is_lua and not is_nattlua then return end

local function read_file(path)
	local f, err = io.open(path, "r")

	if not f then return nil, err end

	local str = f:read("*all")

	if not str then return nil, "empty file" end

	f:close()
	return str
end

local code, err = read_file(path)

if not code then
	io.write("failed to read file:", err, "\n")
	return
end

if
	path:find("on_editor_save.lua", nil, true) or
	path:find("hotreload.lua", nil, true)
then
	-- just check if it compiles
	assert(load(code))
	return
end

_G.HOTRELOAD = true
_G.path = path
_G.code = code
local nl = require("nattlua")
local profiler = require("test.helpers.profiler")

function _G.run_lua(path, ...)
	io.write("running lua: ", path, "\n")
	assert(loadfile(path))(...)
end

function _G.run_nlua(path)
	io.write("running nattlua: ", path, "\n")
	local lua_code = assert(read_file(path))

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

	if has_flag("PROFILE") then profiler.Start() end

	local ok, err

	if not has_flag("DISABLE_ANALYSIS") then ok, err = c:Analyze() end

	if _G.DISABLE_BASE_ENV then _G.DISABLE_BASE_ENV = nil end

	if has_flag("PROFILE") then profiler.Stop() end

	if not ok and err then
		error(err)
		return
	end

	local preserve_whitespace = nil

	if has_flag("PRETTY_PRINT") then preserve_whitespace = false end

	local res = assert(
		c:Emit(
			{
				preserve_whitespace = preserve_whitespace,
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

function _G.run_test_focus()
	local str = read_file("test_focus.nlua")

	if not str then return false end

	str = str:gsub("%s+", "")

	if str == "" then return false end

	_G.run_nlua("test_focus.nlua")
	return true
end

function _G.run_test(path)
	if path then
		io.write("running single test ", path)
	else
		io.write("running all tests")
	end
	assert(loadfile("test/run.lua"))()(path)
	io.write(" - ok\n")
end

function _G.run_fallback()
	if is_nattlua then _G.run_nlua(path) else _G.run_lua(path) end
end

if _G.run_test_focus() then return end

local function run_hotreload_config()
	local function run_hotreload_code(code)
		local func, err = load(code)

		if not func then
			io.write("failed to load hotreload code:", err, "\n")
			return false
		end

		local trimmed = code:match("^%s*(.-)%s*$")

		io.write("running hotreload code:\n", trimmed, "\n")
		func()
		return true
	end

	local code = code:match("%-%-%[%[HOTRELOAD(.-)%]%]")

	if code then return run_hotreload_code(code) end

	local dir = path:match("(.+)/")
	if not dir:find("/NattLua/", 1, true) then
		io.write("not the /NattLua/ directory, refusing to find hotreload config\n")
		return false
	end
	while dir do
		if not dir:find("/NattLua/", 1, true) then break end

		local hotreload_path = dir .. "/hotreload.lua"
		local code = read_file(hotreload_path)

		if code then
			io.write("found hotreload code in ", hotreload_path, "\n")
			return run_hotreload_code(code)
		end

		dir = dir:match("(.+)/")
	end

	return false
end

if not run_hotreload_config(code) then _G.run_fallback() end
