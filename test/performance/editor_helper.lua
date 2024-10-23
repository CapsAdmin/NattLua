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

	helper:SetFileContent(path, code)
	helper:OpenFile(path, code)
	return helper, diagnostics
end

local helper = single_file(io.open("test/tests/nattlua/analyzer/complex/ljsocket.nlua"):read("*a"))
local profiler = require("test.helpers.profiler")
profiler.Start()
print(helper:GetSemanticTokens(path))
profiler.Stop()
