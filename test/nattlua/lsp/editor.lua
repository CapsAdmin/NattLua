local EditorHelper = require("nattlua.editor_helper.editor")
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
        local a = 1
        local x = 2
    ]]
	local editor = single_file(code)
	assert(editor:GetHover(path, 1, 18).obj:GetData() == 2)
end

do
	local editor, diagnostics = single_file([[locwal]])
	assert(diagnostics[1].name == "./test.nlua")
	assert(diagnostics[1].data[1].message:find("expected assignment or call") ~= nil)
end

local function get_line_char(code)
	local _, start = code:find(">>")
	code = code:gsub(">>", "  ")
	local line = 0
	local char = 0

	for i = 1, start do
		if code:sub(i, i) == "\n" then
			line = line + 1
			char = 0
		else
			char = char + 1
		end
	end

	return code, line, char
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
	local code, line, char = get_line_char(code)
	local editor = single_file(code)
	local new_code = apply_edits(code, editor:GetRenameInstructions(path, line, char, "b"))
	assert(#new_code == #new_code)
end

do
	local code = [[local >>a = 1]]
	local code, line, char = get_line_char(code)
	local editor = single_file(code)
	local new_code = apply_edits(code, editor:GetRenameInstructions(path, line, char, "foo"))
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
	local code, line, char = get_line_char(code)
	local editor = single_file(code)
	local new_code = apply_edits(code, editor:GetRenameInstructions(path, line, char, "LOL"))
	assert(code:gsub("foo", "LOL") == new_code)
end

do
	local helper = EditorHelper.New()
	helper:Initialize()

	function helper:OnDiagnostics(name, data)
		print(name)
		table.print(data)
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