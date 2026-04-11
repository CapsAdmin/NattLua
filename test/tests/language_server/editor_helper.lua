_G.TEST = true
local EditorHelper = require("language_server.editor_helper")
local LStringNoMeta = require("nattlua.types.string").LStringNoMeta
local fs = require("nattlua.other.fs")
local path_util = require("nattlua.other.path")
local path = "./test.nlua"

local function single_file(code)
	local helper = EditorHelper.New()
	helper:Initialize()
	local diagnostics = {}

	function helper:OnDiagnostics(name, data)
		table.insert(diagnostics, {
			name = name,
			data = data,
		})
	end

	helper:OpenFile(path, code)
	return helper, diagnostics
end

do
	local editor = single_file([[local a = 1]])
	assert(editor:GetHover(path, 0, 6).obj:GetData() == 1)
end

do
	local editor = single_file([[local a = 1; a = 2]])
	assert(editor:GetHover(path, 0, 6).obj:GetData() == 1)
	assert(editor:GetHover(path, 0, 13).obj:GetData() == 2)
end

do
	local helper = EditorHelper.New()
	local runtime_env, typesystem_env = helper:GetEnvironment()

	for _, env in ipairs({runtime_env, typesystem_env}) do
		assert(env:Get(LStringNoMeta("type")).Type == "function")
		assert(env:Get(LStringNoMeta("require")).Type == "function")
		assert(env:Get(LStringNoMeta("rawget")).Type == "function")
	end
end

do
	local code = [[
        local a: number = 1
        local x: number = 2
    ]]
	local editor = single_file(code)
	assert(editor:GetHover(path, 1, 18).obj.Type == "number")
end

do
	local editor, diagnostics = single_file([[locwal]])
	assert(diagnostics[1].name == "test.nlua")
	assert(diagnostics[1].data[1].message:find("expected assignment or call") ~= nil)
end

local function get_line_char(code)
	local _, start = code:find(">>")
	code = code:gsub(">>", "  ")
	local line_pos = 0
	local char_pos = 0

	for i = 1, start do
		if code:sub(i, i) == "\n" then
			line_pos = line_pos + 1
			char_pos = 0
		else
			char_pos = char_pos + 1
		end
	end

	return code, line_pos, char_pos
end

local function apply_edits(code, edits)
	for i = #edits, 1, -1 do
		local edit = edits[i]
		local before = code:sub(1, edit.start - 1)
		local after = code:sub(edit.stop + 1, #code)
		code = before .. edit.to .. after
	end

	return code
end

do
	local code = [[
        local a = 1
		do
			a = 2
			function foo()
				>>a = 3
				asdf(a, a, a)
			end
		end
    ]]
	local code, line_pos, char_pos = get_line_char(code)
	local editor = single_file(code)
	local new_code = apply_edits(code, editor:GetRenameInstructions(path, line_pos, char_pos, "b"))
	assert(#new_code == #new_code)
end

do
	local code = [[local >>a = 1]]
	local code, line_pos, char_pos = get_line_char(code)
	local editor = single_file(code)
	local new_code = apply_edits(code, editor:GetRenameInstructions(path, line_pos, char_pos, "foo"))
	assert(new_code:find("local%s+foo%s+%=") ~= nil)
end

do
	local code = [[local >>aaa = 1]]
	local code, line_pos, char_pos = get_line_char(code)
	local editor = single_file(code)
	local new_code = apply_edits(code, editor:GetRenameInstructions(path, line_pos, char_pos, "foo"))
	assert(new_code:find("local%s+foo%s+%=") ~= nil)
end

do
	local code = [[
        local function foo()

		end

		foo()
		>>foo()

		function lol()
			foo()
			local bar = foo
			bar()
		end
    ]]
	local code, line_pos, char_pos = get_line_char(code)
	local editor = single_file(code)
	local new_code = apply_edits(code, editor:GetRenameInstructions(path, line_pos, char_pos, "LOL"))
	equal((code:gsub("foo", "LOL")), new_code)
end

do
	local helper = EditorHelper.New()
	helper:Initialize()

	function helper:OnDiagnostics(name, data)
		print(name)
		table.print(data)
		error("should not be called")
	end

	helper:SetFileContent(
		"./main.nlua",
		[[
		do
			local type a = import("./a.nlua")
			local type b = import("./b.nlua")

			attest.equal(a + b, 5)
		end

		do
			local a = import("./a.nlua")
			local b = import("./b.nlua")
			assert(a + b == 5)
		end

		do
			local a = dofile("./a.nlua")
			local b = dofile("./b.nlua")
			assert(a + b == 5)
		end

		do
			local a = loadfile("./a.nlua")()
			local b = loadfile("./b.nlua")()
			assert(a + b == 5)
		end
	]]
	)
	helper:SetFileContent("./a.nlua", [[
		return 2
	]])
	helper:SetFileContent("./b.nlua", [[
		return 3
	]])
	helper:Recompile("./main.nlua")
end

do
	local helper = EditorHelper.New()
	helper:Initialize()
	local format_path = "./main.lua"
	local code = [[
		assert(loadfile("game/run.lua"))()
		local f = assert(loadfile("test/run.lua"))
		assert(loadfile("game/run.lua"))()
	]]
	helper:OpenFile(format_path, code)
	local formatted = helper:Format(code, format_path)
	assert(formatted:find("assert%(loadfile%(\"game/run%.lua\"%)%)%(") ~= nil)
	assert(formatted:find("local f = assert%(loadfile%(\"test/run%.lua\"%)%)") ~= nil)
	assert(formatted:find("assert%(loadfile%)%(") == nil)
	assert(formatted:find("local f = assert%(loadfile%)") == nil)
end

do
	local helper = EditorHelper.New()
	helper:Initialize()
	local diagnostics_calls = {}
	local main_path = "./import_error_main.nlua"

	function helper:OnDiagnostics(name, data)
		table.insert(diagnostics_calls, {
			name = name,
			data = data,
		})
	end

	helper:SetFileContent(main_path, [[local bad = import("./does_not_exist.nlua")]])
	helper:Recompile(main_path)

	local import_error

	for _, call in ipairs(diagnostics_calls) do
		for _, diagnostic in ipairs(call.data) do
			if diagnostic.message:find("error importing file:", nil, true) then
				import_error = diagnostic.message
				break
			end
		end

		if import_error then break end
	end

	assert(import_error, "expected an import diagnostic")
	assert(import_error:find("requested path:", nil, true) ~= nil)
	assert(import_error:find("reason:", nil, true) ~= nil)
	assert(import_error:find("error importing file: nil", nil, true) == nil)
end

do
	local helper = EditorHelper.New()
	helper:Initialize()
	local diagnostics_calls = {}
	local main_path = "./project_root_import/src/main.nlua"
	local imported_path = "./project_root_import/goluwa/render/render.lua"

	function helper:OnDiagnostics(name, data)
		table.insert(diagnostics_calls, {
			name = name,
			data = data,
		})
	end

	helper:SetConfigFunction(function(path)
		return {
			config_dir = "project_root_import/",
			commands = {
				["get-compiler-config"] = {
					cb = function()
						return
					end,
				},
			},
		}
	end)

	helper:SetFileContent(main_path, [[local render = import("goluwa/render/render.lua")]])
	helper:SetFileContent(imported_path, [[return {ok = true}]])
	helper:Recompile(main_path)

	for _, call in ipairs(diagnostics_calls) do
		for _, diagnostic in ipairs(call.data) do
			assert(diagnostic.message:find("error importing file:", nil, true) == nil)
		end
	end

	assert(helper:IsLoaded(imported_path))
end

do
	local helper = EditorHelper.New()
	helper:Initialize()
	local diagnostics_calls = {}
	local main_path = "./light_mode_import/src/main.nlua"
	local imported_path = "./light_mode_import/goluwa/render/render.lua"

	function helper:OnDiagnostics(name, data)
		table.insert(diagnostics_calls, {
			name = name,
			data = data,
		})
	end

	helper:SetConfigFunction(function(path)
		return {
			config_dir = "light_mode_import/",
			commands = {
				["get-compiler-config"] = {
					cb = function()
						return {
							lsp = {
								analyze = false,
								entry_point = "goluwa/render/render.lua",
							},
							parser = {
								emit_environment = false,
							},
						}
					end,
				},
			},
		}
	end)

	helper:SetFileContent(main_path, [[local render = import("goluwa/render/render.lua")]])
	helper:SetFileContent(imported_path, [[return {ok = true}]])
	helper:Recompile(main_path)

	for _, call in ipairs(diagnostics_calls) do
		for _, diagnostic in ipairs(call.data) do
			assert(diagnostic.message:find("error importing file:", nil, true) == nil)
		end
	end

	assert(not helper:IsLoaded(imported_path))

	diagnostics_calls = {}
	helper:SetFileContent(main_path, [[local render = import("goluwa/render/missing.lua")]])
	helper:Recompile(main_path)

	local import_error

	for _, call in ipairs(diagnostics_calls) do
		for _, diagnostic in ipairs(call.data) do
			if diagnostic.message:find("error importing file:", nil, true) then
				import_error = diagnostic.message
				break
			end
		end

		if import_error then break end
	end

	assert(import_error)
	assert(import_error:find("requested path: goluwa/render/missing.lua", nil, true) ~= nil)
	assert(import_error:find("reason: file not found", nil, true) ~= nil)
end

do
	local helper = EditorHelper.New()
	helper:Initialize()
	local diagnostics_calls = {}
	local main_path = "./light_mode_open/src/main.nlua"

	function helper:OnDiagnostics(name, data)
		table.insert(diagnostics_calls, {
			name = name,
			data = data,
		})
	end

	helper:SetConfigFunction(function(path)
		return {
			config_dir = "light_mode_open/",
			commands = {
				["get-compiler-config"] = {
					cb = function()
						return {
							lsp = {
								analyze = false,
							},
							parser = {
								emit_environment = false,
							},
						}
					end,
				},
			},
		}
	end)

	helper:OpenFile(main_path, [[local render = import("missing.lua")]])
	assert(not helper:IsLoaded(main_path))
	assert(#diagnostics_calls == 0)
	assert(helper:EnsureParsed(main_path) == true)
	assert(helper:IsParsed(main_path))
	assert(not helper:IsAnalyzed(main_path))
	helper:CloseFile(main_path)
	diagnostics_calls = {}
	helper:OpenFile(main_path, [[local render = import("missing.lua")]])
	assert(not helper:IsLoaded(main_path))
	assert(helper:EnsureLoaded(main_path) == true)
	assert(helper:IsLoaded(main_path))
	assert(#diagnostics_calls > 0)
end

do
	local helper = EditorHelper.New()
	local diagnostics_calls = {}

	function helper:OnDiagnostics(name, data)
		table.insert(diagnostics_calls, {
			name = name,
			data = data,
		})
	end

	helper:SetConfigFunction(function(path)
		return {
			config_dir = "./light_mode_initialize/",
			commands = {
				["get-compiler-config"] = {
					cb = function()
						return {
							lsp = {
								analyze = false,
								entry_point = "src/entry.nlua",
							},
							parser = {
								emit_environment = false,
							},
						}
					end,
				},
			},
		}
	end)

	helper:SetFileContent("./light_mode_initialize/src/entry.nlua", [[local x = import("missing.lua")]])
	helper:Initialize()
	assert(#diagnostics_calls == 0)
end

do
	local helper = EditorHelper.New()
	local old_fs_read = fs.read
	local save_path = "./save_syntax_only.nlua"
	local normalized_save_path = path_util.Normalize(save_path)
	fs.read = function(read_path)
		if read_path == save_path or read_path == normalized_save_path then return "local value = 1" end
		return old_fs_read(read_path)
	end

	helper:SaveFile(save_path)
	assert(helper:IsParsed(save_path))
	assert(not helper:IsAnalyzed(save_path))

	fs.read = old_fs_read
end

do
	local helper = EditorHelper.New()
	local now = 100
	helper.Now = function()
		return now
	end
	helper:MarkDirty("./burst.nlua")
	assert(helper:ShouldDeferInteractiveRefresh("./burst.nlua") == true)
	now = now + 1
	assert(helper:ShouldDeferInteractiveRefresh("./burst.nlua") == false)
end

do
	local helper = EditorHelper.New()
	local old_fs_read = fs.read
	local save_path = "./save_force_analyze.nlua"
	local normalized_save_path = path_util.Normalize(save_path)
	helper:SetConfigFunction(function(cfg_path)
		return {
			commands = {
				["get-compiler-config"] = {
					cb = function()
						return {
							lsp = {},
						}
					end,
				},
			},
		}
	end)
	fs.read = function(read_path)
		if read_path == save_path or read_path == normalized_save_path then
			return [[
				--ANALYZE
				local value = 1
				math.sin(value)
			]]
		end
		return old_fs_read(read_path)
	end

	helper:SaveFile(save_path)
	assert(helper:IsParsed(save_path))
	assert(helper:IsAnalyzed(save_path))

	fs.read = old_fs_read
end

do
	local helper = EditorHelper.New()
	helper:Initialize()
	local format_path = "./main.nlua"
	local code = [[
		local a=1
		local b=2]]
	helper:OpenFile(format_path, code)
	local formatted = helper:Format(code, format_path)
	assert(formatted:sub(#formatted, #formatted) == "\n")

	helper:SetConfigFunction(function(path)
		return {
			["get-compiler-config"] = function()
				return {
					emitter = {
						trailing_newline = false,
					},
					lsp = {entry_point = path},
				}
			end,
		}
	end)

	formatted = helper:Format(code, format_path)
	assert(formatted:sub(#formatted, #formatted) ~= "\n")
end

do
	local helper = EditorHelper.New()
	helper:Initialize()

	function helper:OnDiagnostics(name, data)
		if #data == 0 then return end

		error("should not be called")
	end

	helper:SetConfigFunction(function(...)
		local cmd = ...

		if cmd == "get-compiler-config" then
			return {
				parser = {inline_require = true},
				lsp = {entry_point = "./src/main.nlua"},
			}
		end
	end)

	_G.loaded = nil
	helper:SetFileContent("./src/main.nlua", [[
		§ _G.loaded = true
	]])
	helper:Recompile()
	helper:Recompile("./src/main.nlua")
	assert(_G.loaded)
	_G.loaded = nil
end

if false then
	local helper = EditorHelper.New()
	helper:Initialize()
	local called = false

	function helper:OnDiagnostics(name, data)
		assert(data[1].message:find("error importing") ~= nil)
		called = true
	end

	helper:SetConfigFunction(function(...)
		return {
			["get-compiler-config"] = function()
				return {
					parser = {
						inline_require = true,
					},
					lsp = {entry_point = "./src/bad.nlua"},
				}
			end,
		}
	end)

	helper:SetFileContent("./src/main.nlua", [[
		error("should not be called")
	]])
	helper:Recompile()
	assert(called)
end

do
	local SemanticTokenTypes = {
		-- identifiers or reference
		"class", -- a class type. maybe META or Meta?
		"typeParameter", -- local type >foo< = true
		"parameter", -- function argument: function foo(>a<)
		"variable", -- a local or global variable.
		"property", -- a member property, member field, or member variable.
		"enumMember", -- an enumeration property, constant, or member. uppercase variables and global non tables? local FOO = true ?
		"event", --  an event property.
		"function", -- local or global function: local function >foo<
		"method", --  a member function or method: string.>bar<()
		"type", -- misc type
		-- tokens
		"comment", -- 
		"string", -- 
		"keyword", -- 
		"number", -- 
		"regexp", -- regular expression literal.
		"operator", --
		"decorator", -- decorator syntax, maybe for @Foo in tables, $ and §
		-- other identifiers or references
		"namespace", -- namespace, module, or package.
		"enum", -- 
		"interface", --
		"struct", -- 
		"decorator", -- decorators and annotations.
		"macro", --  a macro.
		"label", --  a label. ??
	}

	local function convert_semantic_tokens_to_tokens(integers, source_code)
		local tokens = {}
		local current_line = 1
		local current_char = 1
		-- Split source code into lines for easier position tracking
		local lines = {}

		for line in source_code:gmatch("([^\n]*)\n?") do
			table.insert(lines, line)
		end

		for i = 1, #integers, 5 do
			local delta_line = integers[i]
			local delta_start = integers[i + 1]
			local length = integers[i + 2]
			local token_type = integers[i + 3]
			local modifiers = integers[i + 4]
			-- Update current position based on deltas
			current_line = current_line + delta_line

			if delta_line == 0 then
				-- Same line, relative to previous token
				current_char = current_char + delta_start
			else
				-- New line, absolute position
				current_char = delta_start + 1
			end

			-- Extract the token text from source code
			local token_text = ""

			if current_line <= #lines then
				local line = lines[current_line]

				if current_char <= #line then
					token_text = line:sub(current_char, current_char + length - 1)
				end
			end

			-- Create token info
			local token_info = {
				line = current_line,
				character = current_char,
				length = length,
				text = token_text,
				token_type = SemanticTokenTypes[token_type + 1],
				modifiers = modifiers,
				-- Additional computed info
				start_pos = current_char,
				end_pos = current_char + length - 1,
			}
			table.insert(tokens, token_info)
		-- Update current_char for next iteration (but don't advance line)
		-- The next token's delta will be relative to this position
		end

		return tokens
	end

	do
		local helper = single_file([[local x = 10*2]])
		local hints = helper:GetInlayHints(path, 1, 1, 1, 100)
		assert(#hints == 1)
		assert(hints[1].start == 7)
		assert(hints[1].stop == 7)
		assert(hints[1].label == "20")
	end

	do
		local helper = single_file([[local x]])
		local integers = helper:GetSemanticTokens(path)
		assert((#integers / 5) == 2)
	end

	do
		local str = [[local x = loadstring("local y = 1 return y")]]
		local helper = single_file(str)
		local integers = helper:GetSemanticTokens(path)
		local tokens = convert_semantic_tokens_to_tokens(integers, str)
		equal(#tokens, 14)
	end

	do
		local str = [[local x = analyze("local y = 1 return y")]]
		local helper = single_file(str)
		local integers = helper:GetSemanticTokens(path)
		local tokens = convert_semantic_tokens_to_tokens(integers, str)
		equal(#tokens, 14)
	end

	do
		local str = [===[local t = 
ffi.typeof([[struct {
    uint32_t st_dev;
    // lol
    uint16_t st_mode;
}]]) --test
local x --
loadstring("local x = 'hello'")
--]===]
		local helper = single_file(str)
		local integers = helper:GetSemanticTokens(path)
		local tokens = convert_semantic_tokens_to_tokens(integers, str)
		equal(#tokens, 31)
	end

	do
		local str = [===[
		local function mod()
			local i = 0
			return function()
				i = i + 1
				return i
			end
		end
		local f = mod()
		f()
		f()
		local yyy = f()
		attest.equal(yyy, 3)
		]===]
		local helper = single_file(str)

		function helper:OnDiagnostics(name, data)
			print(name)
			table.print(data)
			error("should not be called")
		end

		helper:Recompile(path)
	end
end

do
	-- Test that diagnostics are properly cleared when errors are fixed
	local helper = EditorHelper.New()
	helper:Initialize()
	local diagnostics_calls = {}

	function helper:OnDiagnostics(name, data)
		table.insert(diagnostics_calls, {
			name = name,
			data = data,
			count = #data,
		})
	end

	helper:OpenFile(path, [[locwal]])
	helper:Recompile(path)
	assert(#diagnostics_calls > 0)
	diagnostics_calls = {} -- reset
	helper:UpdateFile(path, [[local a = 1]])
	helper:Recompile(path)
	assert(#diagnostics_calls == 0)
end

do
	local helper = EditorHelper.New()
	helper:Initialize()
	local clears = {}

	function helper:OnClearDiagnostics(name)
		table.insert(clears, name)
	end

	helper:OpenFile(path, [[locwal]])
	helper:CloseFile(path)
	assert(clears[#clears] == "test.nlua")
end

_G.TEST = false
