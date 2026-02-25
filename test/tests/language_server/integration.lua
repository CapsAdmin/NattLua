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
