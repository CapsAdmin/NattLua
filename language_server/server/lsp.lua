--DONT_ANALYZE
local b64 = require("nattlua.other.base64")
local EditorHelper = require("nattlua.editor_helper.editor")
local formating = require("nattlua.other.formating")
local path = require("nattlua.other.path")
local lsp = {}
lsp.methods = {}
local TextDocumentSyncKind = {None = 0, Full = 1, Incremental = 2}
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
local SemanticTokenModifiers = {
	"declaration", -- For declarations of symbols.
	"definition", -- For definitions of symbols, for example, in header files.
	"readonly", -- For readonly variables and member fields (constants).
	"static", -- For class members (static members).
	"private", -- For class members (static members).
	"deprecated", -- For symbols that should no longer be used.
	"abstract", -- For types and member functions that are abstract.
	"async", -- For functions that are marked async.
	"modification", -- For variable references where the variable is assigned to.
	"documentation", -- For occurrences of symbols in documentation.
	"defaultLibrary", -- For symbols that are part of the standard library.
}

local function get_range(code, start, stop)
	local data = formating.SubPositionToLinePosition(code:GetString(), start, stop)
	return {
		start = {
			line = data.line_start - 1,
			character = data.character_start - 1,
		},
		["end"] = {
			line = data.line_stop - 1,
			character = data.character_stop, -- not sure about this
		},
	}
end

local editor_helper = EditorHelper.New()
editor_helper.debug = true

local function to_fs_path(url)
	local wdir = editor_helper:GetWorkingDirectory()
	url = path.RemoveProtocol(url)

	if url:sub(1, 1) ~= "/" then
		local start, stop = url:find(wdir, 1, true)

		if start == 1 and stop then url = url:sub(stop + 1, #url) end

		if url:sub(1, #wdir) ~= wdir then
			if wdir:sub(#wdir) ~= "/" then
				if url:sub(1, 1) ~= "/" then url = "/" .. url end
			end

			url = wdir .. url
		end
	end

	url = path.Normalize(url)
	return url
end

local function to_lsp_path(url)
	if url:sub(1, 1) == "@" then url = url:sub(2) end

	if url:sub(1, 7) ~= "file://" then url = "file://" .. url end

	return url
end

do
	local path = "file:///home/foo/bar/lsp.lua"
	local fs_path = to_fs_path(path)
	assert(fs_path == "/home/foo/bar/lsp.lua")
	local lsp_path = to_lsp_path(fs_path)
	assert(lsp_path == path)
	local path = "file:///home/foo/./bar/lsp.lua"
	local fs_path = to_fs_path(path)
	assert(fs_path == "/home/foo/bar/lsp.lua")
	local path = "file:///home/foo/../bar/lsp.lua"
	local fs_path = to_fs_path(path)
	assert(fs_path == "/home/bar/lsp.lua")
	local path = "file:///home/foo/bar/../../lsp.lua"
	local fs_path = to_fs_path(path)
	assert(fs_path == "/home/lsp.lua")
end

editor_helper:SetConfigFunction(function(path)
	local original_path = path
	local wdir = editor_helper:GetWorkingDirectory()
	path = path or wdir

	while path ~= "" do
		local dir = path:match("(.+)/")

		if not dir then break end

		local config_path = dir .. "/nlconfig.lua"
		local f, err = loadfile(config_path)

		if f then
			local ok, err = pcall(f)

			if not ok then print(err) end

			editor_helper:DebugLog("[ " .. original_path .. " ] loading config " .. config_path)
			err.config_dir = dir .. "/"

			if editor_helper.debug then table.print(err) end

			return err
		end

		path = dir
	end
end)

function editor_helper:OnRefresh()
	lsp.Call({method = "workspace/semanticTokens/refresh", params = {}})
end

function editor_helper:OnDiagnostics(path, data)
	local DiagnosticSeverity = {
		error = 1,
		fatal = 1, -- from lexer and parser
		warning = 2,
		information = 3,
		hint = 4,
	}
	local diagnostics = {}

	for i, v in ipairs(data) do
		local range = get_range(v.code, v.start, v.stop)
		diagnostics[i] = {
			severity = DiagnosticSeverity[v.severity],
			range = range,
			message = v.message .. "\n" .. v.trace,
		}
	end

	lsp.Call(
		{
			method = "textDocument/publishDiagnostics",
			params = {
				uri = to_lsp_path(path),
				diagnostics = diagnostics,
			},
		}
	)
end

lsp.methods["initialize"] = function(params)
	editor_helper:SetWorkingDirectory(to_fs_path(params.workspaceFolders[1].uri))
	return {
		clientInfo = {name = "NattLua", version = "1.0"},
		capabilities = {
			textDocumentSync = {
				openClose = true,
				change = TextDocumentSyncKind.Full,
			},
			semanticTokensProvider = {
				legend = {
					tokenTypes = SemanticTokenTypes,
					tokenModifiers = SemanticTokenModifiers,
				},
				full = true,
				range = false,
			},
			hoverProvider = true,
			publishDiagnostics = {
				relatedInformation = true,
				tagSupport = {1, 2},
			},
			inlayHintProvider = true,
			definitionProvider = true,
			renameProvider = true,
			definitionProvider = true,
			inlineValueProvider = true,
			referencesProvider = true,
		-- for symbols like all functions within a file
		-- documentSymbolProvider = {label = "NattLua"},
		-- highlighting equal upvalues
		-- documentHighlightProvider = true, 
		--[[completionProvider = {
				resolveProvider = true,
				triggerCharacters = { ".", ":" },
			},
			signatureHelpProvider = {
				triggerCharacters = { "(" },
			},
			
			workspaceSymbolProvider = true,
			codeActionProvider = true,
			codeLensProvider = {
				resolveProvider = true,
			},
			documentFormattingProvider = true,
			documentRangeFormattingProvider = true,
			documentOnTypeFormattingProvider = {
				firstTriggerCharacter = "}",
				moreTriggerCharacter = { "end" },
			},
			renameProvider = true,
			]] },
	}
end
lsp.methods["initialized"] = function(params)
	editor_helper:Initialize()
end
lsp.methods["nattlua/format"] = function(params)
	return {
		code = b64.encode(editor_helper:Format(params.code, to_fs_path(params.path))),
	}
end
lsp.methods["nattlua/syntax"] = function(params)
	local data = require("nattlua.syntax.monarch_language")
	return {data = b64.encode(data)}
end
lsp.methods["shutdown"] = function(params)
	table.print(params)
end

do
	local tokenTypeMap = {}
	local tokenModifiersMap = {}
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
	local SemanticTokenModifiers = {
		"declaration", -- For declarations of symbols.
		"definition", -- For definitions of symbols, for example, in header files.
		"readonly", -- For readonly variables and member fields (constants).
		"static", -- For class members (static members).
		"private", -- For class members (static members).
		"deprecated", -- For symbols that should no longer be used.
		"abstract", -- For types and member functions that are abstract.
		"async", -- For functions that are marked async.
		"modification", -- For variable references where the variable is assigned to.
		"documentation", -- For occurrences of symbols in documentation.
		"defaultLibrary", -- For symbols that are part of the standard library.
	}

	for i, v in ipairs(SemanticTokenTypes) do
		tokenTypeMap[v] = i - 1
	end

	for i, v in ipairs(SemanticTokenModifiers) do
		tokenModifiersMap[v] = i - 1
	end

	lsp.methods["textDocument/semanticTokens/full"] = function(params)
		local data = editor_helper:GetFile(to_fs_path(params.textDocument.uri))
		local integers = {}
		local last_y = 0
		local last_x = 0

		for _, token in ipairs(data.tokens) do
			if token.type ~= "end_of_file" then
				local type, modifiers = token:GetSemanticType()

				if type then
					local data = data.code:SubPosToLineChar(token.start, token.stop)
					local len = #token.value
					local y = (data.line_start - 1) - last_y
					local x = (data.character_start - 1) - last_x

					-- x is not relative when there's a new line
					if y ~= 0 then x = data.character_start - 1 end

					if x >= 0 and y >= 0 then
						table.insert(integers, y)
						table.insert(integers, x)
						table.insert(integers, len)
						assert(tokenTypeMap[type], "invalid type " .. type)
						table.insert(integers, tokenTypeMap[type])
						local result = 0

						if modifiers then
							for _, mod in ipairs(modifiers) do
								assert(tokenModifiersMap[mod], "invalid modifier " .. mod)
								result = bit.bor(result, bit.lshift(1, tokenModifiersMap[mod])) -- TODO, doesn't seem to be working
							end
						end

						table.insert(integers, result)
						last_y = data.line_start - 1
						last_x = data.character_start - 1
					end
				end
			end
		end

		return {data = integers}
	end
end

lsp.methods["$/cancelRequest"] = function(params)
	do
		return
	end

	print("cancelRequest")
	table.print(params)
end
lsp.methods["workspace/didChangeConfiguration"] = function(params)
	print("configuration changed")
	table.print(params)
end
lsp.methods["textDocument/didOpen"] = function(params)
	editor_helper:OpenFile(to_fs_path(params.textDocument.uri), params.textDocument.text)
end
lsp.methods["textDocument/didClose"] = function(params)
	editor_helper:CloseFile(to_fs_path(params.textDocument.uri))
end
lsp.methods["textDocument/didChange"] = function(params)
	editor_helper:UpdateFile(to_fs_path(params.textDocument.uri), params.contentChanges[1].text)
end
lsp.methods["textDocument/didSave"] = function(params)
	editor_helper:SaveFile(to_fs_path(params.textDocument.uri))
end
lsp.methods["textDocument/references"] = function(params)
	local nodes = editor_helper:GetReferences(
		to_fs_path(params.textDocument.uri),
		params.position.line,
		params.position.character - 1
	)
	local result = {}

	for k, node in pairs(nodes) do
		local path = node:GetSourcePath() or to_fs_path(path)
		editor_helper:OpenFile(path, node.Code:GetString())
		table.insert(
			result,
			{
				uri = to_fs_path(path),
				range = get_range(editor_helper:GetCode(path), node:GetStartStop()),
			}
		)
	end

	return result
end
lsp.methods["textDocument/inlayHint"] = function(params)
	local result = {}

	for _, hint in ipairs(
		editor_helper:GetInlayHints(
			to_fs_path(params.textDocument.uri),
			params.range.start.line + 1,
			params.range.start.character + 1,
			params.range["end"].line + 1,
			params.range["end"].character + 1
		)
	) do
		local range = get_range(
			editor_helper:GetCode(to_fs_path(params.textDocument.uri)),
			hint.start,
			hint.stop
		)
		table.insert(
			result,
			{
				type = 1, -- type
				label = ": " .. hint.label,
				position = range["end"],
			}
		)
	end

	return result
end
lsp.methods["textDocument/rename"] = function(params)
	local fs_path = to_fs_path(params.textDocument.uri)
	local lsp_path = to_lsp_path(params.textDocument.uri)
	local edits = {}

	for _, edit in ipairs(
		editor_helper:GetRenameInstructions(
			fs_path,
			params.position.line + 1,
			params.position.character + 1,
			params.newName
		)
	) do
		table.insert(
			edits,
			{
				range = get_range(editor_helper:GetCode(fs_path), edit.start, edit.stop),
				newText = edit.to,
			}
		)
	end

	return {
		changes = {
			[lsp_path] = edits,
		},
	}
end
lsp.methods["textDocument/definition"] = function(params)
	local node = editor_helper:GetDefinition(
		to_fs_path(params.textDocument.uri),
		params.position.line,
		params.position.character
	)

	if node then
		local start, stop = node:GetStartStop()
		local path = node:GetSourcePath() or to_fs_path(params.textDocument.uri)
		path = to_fs_path(path)
		editor_helper:OpenFile(path, node.Code:GetString())
		return {
			uri = to_lsp_path(path),
			range = get_range(editor_helper:GetCode(path), start, stop),
		}
	end

	return {}
end
lsp.methods["textDocument/hover"] = function(params)
	local data = editor_helper:GetHover(
		to_fs_path(params.textDocument.uri),
		params.position.line,
		params.position.character
	)

	if not data then return {} end

	local markdown = ""

	local function add_line(str)
		markdown = markdown .. str .. "\n\n"
	end

	local function add_code(str)
		add_line("```lua\n" .. tostring(str) .. "\n```")
	end

	if data.obj then
		add_line("main type:")
		add_code("\t" .. tostring(data.obj))
		local upvalue = data.obj:GetUpvalue()

		if upvalue then
			add_line("upvalue:")
			add_code("\t" .. tostring(upvalue))
			local shadow = upvalue:GetShadow()

			if shadow then
				add_code("\tshadowed:")

				while shadow do
					add_code("\t\t" .. tostring(shadow))
					shadow = shadow:GetShadow()
				end
			end

			if upvalue:HasMutations() then
				local code = ""

				for i, mutation in ipairs(upvalue.Mutations) do
					code = code .. "\t" .. i .. ":\n"
					code = code .. "\t\tvalue = " .. tostring(mutation.value) .. "\n"
					code = code .. "\t\tscope = " .. tostring(mutation.scope) .. "\n"
					code = code .. "\t\ttracking = " .. tostring(mutation.from_tracking) .. "\n"
				end

				add_line("\t\tmutations:")
				add_code(code)
			end
		end
	end

	do
		local types, found_parents, scope = data.token:FindType()
		local str = ""

		for _, node in ipairs(found_parents) do
			str = str .. "\t" .. tostring(node) .. "\n"

			for _, obj in ipairs(node:GetAssociatedTypes()) do
				str = str .. "\t\t" .. tostring(obj) .. "\n"
			end
		end

		add_line("associated types:")
		add_code(str)
	end

	local wtf = data.found_parents
	local linepos

	if wtf[1] then
		add_line("parent nodes:")
		local min, max = wtf[1]:GetStartStop()

		if min then
			linepos = formating.SubPositionToLinePosition(wtf[1].Code:GetString(), min, max)
		end

		for i = 1, #wtf do
			local min, max = wtf[i]:GetStartStop()
			add_code("\t" .. tostring(wtf[i]) .. " len=" .. tostring(max - min))
		end
	end

	if not linepos then return {} end

	if data.scope then
		add_line("scope:")
		add_code("\t" .. tostring(data.scope))
	end

	local limit = 5000

	if #markdown > limit then markdown = markdown:sub(0, limit) .. "\n```\n..." end

	markdown = markdown:gsub("\\", "BSLASH_")
	return {
		contents = markdown,
		range = {
			start = {
				line = linepos.line_start - 1,
				character = linepos.character_start - 1,
			},
			["end"] = {
				line = linepos.line_stop - 1,
				character = linepos.character_stop,
			},
		},
	}
end

do
	local MessageType = {error = 1, warning = 2, info = 3, log = 4}

	function lsp.ShowMessage(type, msg)
		lsp.Call(
			{
				method = "window/showMessage",
				params = {
					type = assert(MessageType[type]),
					message = msg,
				},
			}
		)
	end

	function lsp.LogMessage(type, msg)
		lsp.Call(
			{
				method = "window/logMessage",
				params = {
					type = assert(MessageType[type]),
					message = msg,
				},
			}
		)
	end
end

-- this can be overriden
function lsp.Call(params)
	if lsp.methods[params.method] then lsp.methods[params.method](params) end
end

return lsp