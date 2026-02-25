local LSPClient = require("test.helpers.lsp_client")
local lsp = require("language_server.lsp")

local function find_position(code, pattern)
	local marker = "|"
	local start_marker = pattern:find(marker, 1, true)

	if not start_marker then error("pattern must contain " .. marker) end

	local search_pattern = pattern:gsub("%%|", "%%|") -- wait, the find_position in lsp_integration uses pattern:gsub("%|", "")
	-- standard gsub for |
	search_pattern = pattern:gsub("|", "")
	local code_start, code_end = code:find(search_pattern, 1, true)

	if not code_start then
		error("could not find pattern '" .. search_pattern .. "' in code:\n" .. code)
	end

	local pos = code_start + (start_marker - 1)
	local line = 0
	local char = 0

	for i = 1, pos - 1 do
		if code:sub(i, i) == "\n" then
			line = line + 1
			char = 0
		else
			char = char + 1
		end
	end

	return {line = line, character = char}
end

local function test_rename(code, pattern, new_name, expected_code)
	local client = LSPClient.New()
	client:SetWorkingDirectory("/workspace")
	local root_uri = "file:///workspace"
	client:Initialize(lsp, root_uri)
	local file_uri = root_uri .. "/test.nlua"
	client:Notify(
		lsp,
		"textDocument/didOpen",
		{
			textDocument = {
				uri = file_uri,
				languageId = "nattlua",
				version = 1,
				text = code,
			},
		}
	)
	local res = client:Call(
		lsp,
		"textDocument/rename",
		{
			textDocument = {uri = file_uri},
			position = find_position(code, pattern),
			newName = new_name,
		}
	)

	if not res or not res.changes or not res.changes[file_uri] then
		error("Rename failed or returned no changes")
	end

	local edits = res.changes[file_uri]

	-- Sort edits in descending order of start position to apply them without breaking indices
	table.sort(edits, function(a, b)
		if a.range.start.line == b.range.start.line then
			return a.range.start.character > b.range.start.character
		end

		return a.range.start.line > b.range.start.line
	end)

	local lines = {}

	for s in (code .. "\n"):gmatch("(.-)\n") do
		table.insert(lines, s)
	end

	for _, edit in ipairs(edits) do
		local line_idx = edit.range.start.line + 1
		local line = lines[line_idx]
		local before = line:sub(1, edit.range.start.character)
		local after = line:sub(edit.range["end"].character + 1)
		lines[line_idx] = before .. edit.newText .. after
	end

	local result_code = table.concat(lines, "\n")

	-- Trim trailing newline added by loop if original didn't have one, or just compare carefully
	if result_code:sub(-1) == "\n" and code:sub(-1) ~= "\n" then
		result_code = result_code:sub(1, -2)
	end

	if result_code ~= expected_code then
		error(
			"Rename result mismatch.\nExpected:\n" .. expected_code .. "\nGot:\n" .. result_code
		)
	end
end

-- Test 1: Simple local variable rename
test_rename(
	[[
local foo = 1
math.sin(foo)
]],
	"local |foo",
	"bar",
	[[
local bar = 1
math.sin(bar)
]]
)
-- Test 2: Function parameter rename
test_rename(
	[[
local function test(abc)
    return abc + 1
end
]],
	"local function test(|abc)",
	"xyz",
	[[
local function test(xyz)
    return xyz + 1
end
]]
)
-- Test 3: Local function rename
test_rename(
	[[
local function foo() end
foo()
]],
	"local function |foo",
	"bar",
	[[
local function bar() end
bar()
]]
)
-- Test 4: Upvalue rename from inner scope
test_rename(
	[[
local x = 1
local function f()
    math.sin(x)
end
]],
	"    math.sin(|x)",
	"y",
	[[
local y = 1
local function f()
    math.sin(y)
end
]]
)
