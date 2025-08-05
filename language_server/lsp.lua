--DONT_ANALYZE
local b64 = require("language_server.base64")
local EditorHelper = require("language_server.editor_helper")
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
	local data = code:SubPosToLineChar(start, stop)
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
	return path.UrlSchemeToPath(url, editor_helper:GetWorkingDirectory())
end

local function to_lsp_path(url)
	return path.PathToUrlScheme(url)
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

			if not ok then error(err) end

			editor_helper:DebugLog("[ " .. original_path .. " ] loading config " .. config_path)
			err.config_dir = dir .. "/"

			if editor_helper.debug then table.print(err) end

			return err
		end

		path = dir
	end
end)

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
			message = v.message .. "\n" .. (v.trace or "no trace??"),
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
			completionProvider = {
				resolveProvider = false,
				triggerCharacters = {".", ":"},
			},
			--[[codeLensProvider = {
				resolveProvider = true,
			},]]
			documentSymbolProvider = true,
		-- for symbols like all functions within a file
		-- highlighting equal upvalues
		-- documentHighlightProvider = true, 
		--[[
			signatureHelpProvider = {
				triggerCharacters = { "(" },
			},
			
			workspaceSymbolProvider = true,
			codeActionProvider = true,
			documentFormattingProvider = true,
			documentRangeFormattingProvider = true,
			documentOnTypeFormattingProvider = {
				firstTriggerCharacter = "}",
				moreTriggerCharacter = { "end" },
			},
			renameProvider = true,
			]]
		},
	}
end
lsp.methods["initialized"] = function(params)
	editor_helper:Initialize()
end
lsp.methods["nattlua/format"] = function(params)
	local path = to_fs_path(params.textDocument.uri)
	local code = editor_helper:Format(params.code, path)

	if code:sub(#code, #code) ~= "\n" then code = code .. "\n" end

	return {
		code = b64.encode(code),
	}
end
lsp.methods["shutdown"] = function(params)
	table.print(params)
end
lsp.methods["textDocument/semanticTokens/full"] = function(params)
	local path = to_fs_path(params.textDocument.uri)
	-- this is not the right place to do this I guess, but it's more reliable and simple
	lsp.PublishDecorations(path)
	return {data = editor_helper:GetSemanticTokens(path)}
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
	local path = to_fs_path(params.textDocument.uri)
	editor_helper:OpenFile(path, params.textDocument.text)
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
	local path = to_fs_path(params.textDocument.uri)

	if not editor_helper:IsLoaded(path) then return {} end

	local data = editor_helper:GetFile(path)
	local nodes = editor_helper:GetReferences(path, params.position.line, params.position.character - 1)

	if not nodes then return {} end

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

do
	local item_kind = {
		text = 1, -- Plain text
		method = 2, -- obj:method()
		["function"] = 3, -- function()
		constructor = 4, -- new Class()
		field = 5, -- obj.field (simple field)
		variable = 6, -- local var
		class = 7, -- class definition
		interface = 8, -- interface
		module = 9, -- module/namespace
		property = 10, -- obj.property (complex property)
		unit = 11, -- measurement unit
		value = 12, -- literal value
		enum = 13, -- enum type
		keyword = 14, -- language keyword
		snippet = 15, -- code snippet
		color = 16, -- color value
		file = 17, -- file reference
		reference = 18, -- reference to something
		folder = 19, -- folder reference
		enum_member = 20, -- enum.MEMBER
		constant = 21, -- CONSTANT value
		struct = 22, -- struct type
		event = 23, -- event
		operator = 24, -- operator
		type_parameter = 25, -- generic type parameter
	}
	lsp.methods["textDocument/completion"] = function(params)
		local path = to_fs_path(params.textDocument.uri)

		if not editor_helper:IsLoaded(path) then
			return {isIncomplete = false, items = {}}
		end

		local keyvalues = editor_helper:GetKeyValuesForCompletion(path, params.position.line, params.position.character - 1)
		local items = {}

		if keyvalues then
			for _, kv in ipairs(keyvalues) do
				local kind = "property"
				local key = kv.key
				local val = kv.val
				local t = kv.obj.Type

				if t == "function" then
					kind = "function"
				elseif t == "table" then
					kind = "struct"
					val = "table"
				end

				local item = {label = key, detail = val, kind = assert(item_kind[kind])}

				-- If key is numeric, use textEdit to replace with bracket notation
				if tonumber(key) then item.label = "[" .. key .. "]" end

				table.insert(items, item)
			end
		end

		return {isIncomplete = false, items = items}
	end
end

lsp.methods["textDocument/inlayHint"] = function(params)
	local path = to_fs_path(params.textDocument.uri)

	if not editor_helper:IsLoaded(path) then return {} end

	local result = {}

	for _, hint in ipairs(
		editor_helper:GetInlayHints(
			path,
			params.range.start.line + 1,
			params.range.start.character + 1,
			params.range["end"].line + 1,
			params.range["end"].character + 1
		)
	) do
		local range = get_range(editor_helper:GetCode(path), hint.start, hint.stop)
		table.insert(
			result,
			{
				type = 1, -- type
				label = ": " .. hint.label:gsub("%s+", " "),
				position = range["end"],
			}
		)
	end

	return result
end

do
	local symbol_kind = {
		File = 1,
		Module = 2,
		Namespace = 3,
		Package = 4,
		Class = 5,
		Method = 6,
		Property = 7,
		Field = 8,
		Constructor = 9,
		Enum = 10,
		Interface = 11,
		Function = 12,
		Variable = 13,
		Constant = 14,
		String = 15,
		Number = 16,
		Boolean = 17,
		Array = 18,
		Object = 19,
		Key = 20,
		Null = 21,
		EnumMember = 22,
		Struct = 23,
		Event = 24,
		Operator = 25,
		TypeParameter = 26,
	}

	local function translate(node, path)
		node.kind = symbol_kind[node.kind] or node.kind

		if node.node then
			node.range = get_range(editor_helper:GetCode(path), node.node:GetStartStop())
			node.selectionRange = get_range(editor_helper:GetCode(path), node.node:GetStartStop())
			node.node = nil

			if node.children then
				for _, child in ipairs(node.children) do
					translate(child, path)
				end
			end
		end
	end

	lsp.methods["textDocument/documentSymbol"] = function(params)
		local path = to_fs_path(params.textDocument.uri)

		if not editor_helper:IsLoaded(path) then return {} end

		local nodes = editor_helper:GetSymbolTree(path)

		for _, node in ipairs(nodes) do
			translate(node, path)
		end

		return nodes
	end
end

if false then
	-- Also implement the resolve method if you want to defer loading the details
	lsp.methods["codeLens/resolve"] = function(params)
		-- This can be used to lazily load more detailed information when the user
		-- interacts with the code lens
		return params
	end
	lsp.methods["textDocument/codeLens"] = function(params)
		do
			return {}
		end

		local path = to_fs_path(params.textDocument.uri)

		if not editor_helper:IsLoaded(path) then return {} end

		local result = {}

		-- This would be replaced with your actual logic to find block scopes/functions
		for _, item in ipairs(editor_helper:GetScopes(path)) do
			local start, stop = item.statement:GetStartStop()
			local range = get_range(code, start, stop)
			-- Only set the start position for the lens (typically at the beginning of the block)
			range["end"] = range.start
			table.insert(
				result,
				{
					range = range,
					command = {
						title = "📊 View Block Types",
						command = "nattlua.viewBlockTypes",
						arguments = {
							uri = to_lsp_path(path),
							position = range.start,
							scopeId = scope.id, -- Some identifier for the scope
						},
					},
				}
			)
		end

		return result
	end
end

lsp.methods["textDocument/rename"] = function(params)
	local fs_path = to_fs_path(params.textDocument.uri)

	if not editor_helper:IsLoaded(fs_path) then return {} end

	local lsp_path = to_lsp_path(params.textDocument.uri)
	local edits = {}
	local instructions = editor_helper:GetRenameInstructions(fs_path, params.position.line, params.position.character, params.newName)

	if not instructions then return edits end

	for _, edit in ipairs(instructions) do
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
	local path = to_fs_path(params.textDocument.uri)

	if not editor_helper:IsLoaded(path) then return {} end

	local node = editor_helper:GetDefinition(path, params.position.line, params.position.character)

	if node then
		local start, stop = node:GetStartStop()
		local path = node:GetSourcePath() or path
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
	local path = to_fs_path(params.textDocument.uri)

	if not editor_helper:IsLoaded(path) then return {} end

	local data = editor_helper:GetHover(path, params.position.line, params.position.character)

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
				if obj.Type == "table" then obj = obj:GetMutatedFromScope(scope) end

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

		if min then linepos = wtf[1].Code:SubPosToLineChar(min, max) end

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
lsp.methods["$/setTrace"] = function(params)
	local value = params.value
	print(value)
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

	function lsp.PublishDecorations(path)
		local highlights = editor_helper:GetHighlightRanges(path)

		if not highlights then return end

		local decorations = {}

		for _, highlight in ipairs(highlights) do
			table.insert(
				decorations,
				{
					range = get_range(editor_helper:GetCode(path), highlight.start, highlight.stop),
					renderOptions = {
						backgroundColor = highlight.backgroundColor,
					},
				}
			)
		end

		lsp.Call(
			{
				method = "nattlua/textDecoration",
				params = {
					uri = to_lsp_path(path),
					decorations = decorations,
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
