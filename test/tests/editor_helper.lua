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
	equal(code:gsub("foo", "LOL"), new_code)
end

do
	local helper = EditorHelper.New()
	helper:Initialize()

	function helper:OnDiagnostics(name, data)
		if #data == 0 then return end

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

do
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

_G.TEST = false
