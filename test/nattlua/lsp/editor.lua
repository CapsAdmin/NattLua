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

	function helper:ReadFile(path)
		return code
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

	assert(diagnostics[1].name == "test.nlua")
	assert(diagnostics[1].data[1].message:find("expected assignment or call") ~= nil)
end

print("done")