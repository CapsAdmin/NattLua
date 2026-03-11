local LSPClient = require("test.helpers.lsp_client")
local lsp = require("language_server.lsp")

local function find_position(code, pattern)
	local marker = "|"
	local start_marker = pattern:find(marker, 1, true)

	if not start_marker then error("pattern must contain " .. marker) end

	local search_pattern = pattern:gsub("%|", "")
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

do
	local client = LSPClient.New()
	client:SetWorkingDirectory("/workspace")
	local root_uri = "file:///workspace"
	local init_res = client:Initialize(lsp, root_uri)
	assert(init_res.capabilities, "Initialization failed")
	local file_uri = root_uri .. "/test.nlua"
	local code = [[
		local a = 1
		local b = 2
		local function foo(x)
			return x + 1
		end
	]]
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
	-- Test Hover
	local hover_res = client:Call(
		lsp,
		"textDocument/hover",
		{textDocument = {uri = file_uri}, position = find_position(code, "local |a")}
	)
	assert(hover_res.contents:find("1"), "Hover should show '1' for literal assigned variable 'a'")
	-- Test Document Symbols
	local symbols = client:Call(lsp, "textDocument/documentSymbol", {textDocument = {uri = file_uri}})
	assert(#symbols > 0, "Should have symbols")
	local foo_sym

	for _, sym in ipairs(symbols) do
		if sym.name == "foo" then foo_sym = sym end
	end

	assert(foo_sym, "Should find function 'foo' in symbols")
	-- Test Document Highlight
	local highlights = client:Call(
		lsp,
		"textDocument/documentHighlight",
		{
			textDocument = {uri = file_uri},
			position = find_position(code, "local |a"),
		}
	)
	assert(#highlights > 0, "Should have highlights for 'a'")
end

do
	local client = LSPClient.New()
	client:SetWorkingDirectory("/workspace")
	local root_uri = "file:///workspace"
	client:Initialize(lsp, root_uri)
	local file_uri = root_uri .. "/test.nlua"
	local code = [[
		local a = 1
		local b = 2
		local function foo(x, y)
			return x + y
		end
	]]
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
	-- Test Signature Help (no call yet)
	client:Call(
		lsp,
		"textDocument/signatureHelp",
		{
			textDocument = {uri = file_uri},
			position = find_position(code, "|end"),
		}
	)
	local code2 = [[
		local a = 1
		local b = 2
		local function foo(x, y)
			return x + y
		end
		foo( )
	]]
	client:Notify(
		lsp,
		"textDocument/didChange",
		{
			textDocument = {uri = file_uri, version = 2},
			contentChanges = {
				{
					text = code2,
				},
			},
		}
	)
	local sig_res = client:Call(
		lsp,
		"textDocument/signatureHelp",
		{
			textDocument = {uri = file_uri},
			position = find_position(code2, "foo(| )"), -- foo( >> here
		}
	)
	assert(#sig_res.signatures > 0, "Should have signature help for 'foo'")
	assert(sig_res.signatures[1].label:find("foo"), "Label should contain 'foo'")
end

do
	local client = LSPClient.New()
	client:SetWorkingDirectory("/workspace")
	local root_uri = "file:///workspace"
	client:Initialize(lsp, root_uri)
	local other_uri = root_uri .. "/other.nlua"
	local other_code = [[
	--ANALYZE
	return { val = 1337 }]]
	client:Notify(
		lsp,
		"textDocument/didOpen",
		{
			textDocument = {
				uri = other_uri,
				languageId = "nattlua",
				version = 1,
				text = other_code,
			},
		}
	)
	local file_uri = root_uri .. "/test.nlua"
	local code = [[
		--ANALYZE
		local other = import("./other.nlua")
		table.insert({}, 1)
		math.sin(other.val)
	]]
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
	local hover_res = client:Call(
		lsp,
		"textDocument/hover",
		{
			textDocument = {uri = file_uri},
			position = find_position(code, "math.sin(other.|val"),
		}
	)
	assert(hover_res.contents:find("1337"), "Should see 1337 in other.val hover")
	-- Test Definition (Upvalue)
	local def_res = client:Call(
		lsp,
		"textDocument/definition",
		{
			textDocument = {uri = file_uri},
			position = find_position(code, "math.sin(|other.val"),
		}
	)
	assert(def_res.uri:find("test.nlua"), "Definition of 'other' should be in test.nlua")
	assert(def_res.range.start.line == 1, "Definition of 'other' should be on line 1")
	-- Test Definition (Global Table Member)
	local def_res = client:Call(
		lsp,
		"textDocument/definition",
		{
			textDocument = {uri = file_uri},
			position = find_position(code, "table.|insert"),
		}
	)
	assert(def_res.uri:find("table.nlua"), "Definition of 'table.insert' should be in table.nlua")
	-- Test Definition (Global)
	local def_res = client:Call(
		lsp,
		"textDocument/definition",
		{
			textDocument = {uri = file_uri},
			position = find_position(code, "|table.insert"),
		}
	)
	assert(def_res.uri:find("table.nlua"), "Definition of 'table' should be in table.nlua")
	-- Test Definition (Global function)
	local def_res = client:Call(
		lsp,
		"textDocument/definition",
		{
			textDocument = {uri = file_uri},
			position = find_position(code, "|math.sin"),
		}
	)
	assert(def_res.uri:find("math.nlua"), "Definition of 'math.sin' should be in math.nlua")
	-- Test References (Upvalue)
	local ref_res = client:Call(
		lsp,
		"textDocument/references",
		{
			textDocument = {uri = file_uri},
			position = find_position(code, "local |other ="),
			context = {includeDeclaration = true},
		}
	)
	assert(#ref_res >= 2, "Should find at least 2 references to 'other'")
end

do
	local client = LSPClient.New()
	local root_uri = "file:///workspace"
	client:SetWorkingDirectory("/workspace")
	client:Initialize(lsp, root_uri)
	local file_uri = root_uri .. "/test.nlua"
	local code = [[local a = (1)]]
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

	local function test_hover(pattern, expected_content)
		local pos = find_position(code, pattern)
		local hover_res = client:Call(
			lsp,
			"textDocument/hover",
			{
				textDocument = {uri = file_uri},
				position = pos,
			}
		)

		if expected_content then
			if not hover_res or not hover_res.contents:find(expected_content, 1, true) then
				error(
					"Expected hover content '" .. expected_content .. "' not found at " .. pos.line .. ":" .. pos.character .. " (" .. pattern .. ")"
				)
			end
		end
	end

	test_hover("local |a =", "1")
	test_hover("local a = |(1)", "1")
	test_hover("local a = (|1)", "1")
end

-- Test unreachable code is dimmed via Unnecessary diagnostic tag
do
	local client = LSPClient.New()
	local root_uri = "file:///workspace"
	client:SetWorkingDirectory("/workspace")
	client:Initialize(lsp, root_uri)
	local file_uri = root_uri .. "/test.nlua"
	local code = [[
if false then
	local www = "hello"
end
]]
	client:ClearNotifications()
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
	local diag_notifications = client:GetNotifications("textDocument/publishDiagnostics")
	assert(#diag_notifications > 0, "Should have publishDiagnostics notifications")
	local found_unnecessary = false

	for _, notif in ipairs(diag_notifications) do
		for _, diag in ipairs(notif.params.diagnostics) do
			if diag.tags then
				for _, tag in ipairs(diag.tags) do
					if tag == 1 and diag.message:find("unreachable") then
						found_unnecessary = true
					end
				end
			end
		end
	end

	assert(
		found_unnecessary,
		"Unreachable code inside 'if false' should produce a diagnostic with Unnecessary tag (1)"
	)
end

-- Test semantic tokens for a long multiline string
do
	local client = LSPClient.New()
	local root_uri = "file:///workspace"
	client:SetWorkingDirectory("/workspace")
	client:Initialize(lsp, root_uri)
	local file_uri = root_uri .. "/test.nlua"
	local code = [[
local HTML_TEMPLATE = [==[
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Profiler</title>
<style>
:root {
  --accent:      #e0e0e0;
  --accent-dim:  rgba(224,224,224,0.15);
  --bg-base:     #1a1a1a;
  --bg-panel:    #222;
  --bg-elevated: #2a2a2a;
  --bg-hover:    #383838;
  --border:      #3030306c;
}
</style>
</head>
<body>
	<script>
		local x = 1
		return x
	</script>
</body>
</html>
]==]
local y = 2
]]
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
	local tokens = client:Call(lsp, "textDocument/semanticTokens/full", {textDocument = {uri = file_uri}})
	assert(tokens and tokens.data, "Should return semantic tokens")
	local current_line = 0
	local found_html_token = false

	for i = 1, #tokens.data, 5 do
		local deltaLine = tokens.data[i]
		current_line = current_line + deltaLine

		-- Check if any token inside the multiline string (lines 1 to 24) is NOT type 11 (string)
		-- EXCEPT the "local HTML_TEMPLATE =" part on line 0.
		if current_line >= 1 and current_line <= 24 then
			assert(
				tokens.data[i + 3] == 11,
				"Token on line " .. current_line .. " inside multiline string should be type 11 (string), but got " .. tokens.data[i + 3]
			)
			found_html_token = true
		end
	end

	assert(found_html_token, "Should have found tokens inside the HTML string")
end

-- Test unreachable code in else-branch when condition is always true
do
	local client = LSPClient.New()
	local root_uri = "file:///workspace"
	client:SetWorkingDirectory("/workspace")
	client:Initialize(lsp, root_uri)
	local file_uri = root_uri .. "/test.nlua"
end

-- Test unreachable code in else-branch when condition is always true
do
	local client = LSPClient.New()
	local root_uri = "file:///workspace"
	client:SetWorkingDirectory("/workspace")
	client:Initialize(lsp, root_uri)
	local file_uri = root_uri .. "/test.nlua"
	local code = [[
local x = true
if x then
	local alive = "reachable"
else
	local dead = "unreachable"
end
]]
	client:ClearNotifications()
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
	local diag_notifications = client:GetNotifications("textDocument/publishDiagnostics")
	assert(#diag_notifications > 0, "Should have publishDiagnostics notifications")
	local found_unnecessary = false

	for _, notif in ipairs(diag_notifications) do
		for _, diag in ipairs(notif.params.diagnostics) do
			if diag.tags then
				for _, tag in ipairs(diag.tags) do
					if tag == 1 and diag.message:find("unreachable") then
						found_unnecessary = true
					end
				end
			end
		end
	end

	assert(
		found_unnecessary,
		"Unreachable else-branch when condition is always true should produce a diagnostic with Unnecessary tag (1)"
	)
end

-- Test while loop unreachable code issue
do
	local client = LSPClient.New()
	local root_uri = "file:///workspace"
	client:SetWorkingDirectory("/workspace")
	client:Initialize(lsp, root_uri)
	local file_uri = root_uri .. "/test.nlua"
	local code = [[
local function test(l, u)
	while l < u do
		if l == 1 then break end
		local i = (l + u) / 2
		if u - l == 2 then break end

		while true do
			i = i + 1
			if i > 10 then break end
		end
	end
end
test(1, 10)
]]
	client:ClearNotifications()
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
	local diag_notifications = client:GetNotifications("textDocument/publishDiagnostics")
	local found_unnecessary = false

	for _, notif in ipairs(diag_notifications) do
		for _, diag in ipairs(notif.params.diagnostics) do
			if diag.tags then
				for _, tag in ipairs(diag.tags) do
					if tag == 1 and diag.message:find("unreachable") then
						-- Check if the diagnostic is inside the while loop (lines 2-10 roughly)
						if diag.range.start.line >= 0 and diag.range.start.line <= 20 then
							found_unnecessary = true
						end
					end
				end
			end
		end
	end

	assert(
		not found_unnecessary,
		"Code inside while loop should NOT be marked as unreachable"
	)
end
