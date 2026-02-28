_G.TEST = true
local EditorHelper = require("language_server.editor_helper")
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
		equal(#tokens, 34)
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

_G.TEST = false