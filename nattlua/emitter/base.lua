--ANALYZE
local runtime_syntax = require("nattlua.syntax.runtime")
local characters = require("nattlua.syntax.characters")
local class = require("nattlua.other.class")
local print = _G.print
local error = _G.error
local debug = _G.debug
local tostring = _G.tostring
local pairs = _G.pairs
local table = _G.table
local ipairs = _G.ipairs
local assert = _G.assert
local type = _G.type
local setmetatable = _G.setmetatable
local B = string.byte

--[[#local type { Token } = import("~/nattlua/lexer/token.lua")]]

--[[#local type { Node } = import("~/nattlua/parser/node.lua")]]

--[[#local type ParserConfig = import("~/nattlua/parser/config.nlua")]]
--[[#local type EmitterConfig = import("~/nattlua/emitter/config.nlua")]]
return function()
	local META = class.CreateTemplate("emitter")
	--[[#type META.@Self.toggled_indents = Map<|string, true | nil|>]]
	--[[#type META.@Self.last_indent_index = nil | number]]
	--[[#type META.@Self.level = number]]
	--[[#type META.@Self.out = List<|string|>]]
	--[[#type META.@Self.i = number]]
	--[[#type META.@Self.config = EmitterConfig]]
	--[[#type META.@Self.last_non_space_index = false | number]]
	--[[#type META.@Self.last_newline_index = nil | number]]
	--[[#type META.@Self.force_newlines = nil | List<|boolean|>]]
	--[[#type META.@Self.during_comment_type = false | number]]
	--[[#type META.@Self.is_call_expression = boolean]]
	--[[#type META.@Self.inside_call_expression = boolean]]
	--[[#type META.@Self.OnEmitStatement = false | Function]]
	--[[#type META.@Self.loop_nodes = false | List<|Node|>]]
	--[[#type META.@Self.tracking_indents = nil | Map<|string, List<|{info = any, level = number}|>|>]]
	--[[#type META.@Self.done = nil | Map<|string, true|>]]
	--[[#type META.@Self.FFI_DECLARATION_EMITTER = false | any]]
	--[[#type META.@Self.pre_toggle_level = nil | number]]

	do -- internal
		function META:Whitespace(str--[[#: string]], force--[[#: boolean]])
			if self.config.pretty_print == nil and not force then return end

			if str == "\t" then
				if self.config.no_newlines then
					self:Emit(" ")
				else
					self:Emit(("\t"):rep(self.level))
					self.last_indent_index = #self.out
				end
			elseif str == " " then
				self:Emit(" ")
			elseif str == "\n" then
				self:Emit(self.config.no_newlines and " " or "\n")
				self.last_newline_index = #self.out
			else
				error("unknown whitespace " .. ("%q"):format(str))
			end
		end

		function META:Emit(str)
			if str == "" then return end

			if str == nil then error("nil") end

			self.out[self.i] = str
			self.i = self.i + 1
		end

		function META:EmitNonSpace(str--[[#: string]])
			self:Emit(str)
			self.last_non_space_index = #self.out
		end

		function META:EmitSpace(str--[[#: string]])
			self:Emit(str)
		end

		function META:Indent()
			self.level = self.level + 1
		end

		function META:Outdent()
			self.level = self.level - 1
		end

		function META:GetPrevChar()
			local prev = self.out[self.i - 1]
			local char = prev and prev:sub(-1)
			return char and char:byte() or 0
		end

		function META:EmitWhitespace(token--[[#: Token]])
			if self.config.pretty_print == true and token.type == "space" then
				return
			end

			self:EmitToken(token)

			if token.type ~= "space" then
				self:Whitespace("\n")
				self:Whitespace("\t")
			end
		end

		function META:EmitToken(token--[[#: Token]], translate--[[#: any]])
			if
				self.config.extra_indent and
				self.config.pretty_print == true and
				self.inside_call_expression
			then
				self.tracking_indents = self.tracking_indents or {}

				if type(self.config.extra_indent[token:GetValueString()]) == "table" then
					self:Indent()
					local info = self.config.extra_indent[token:GetValueString()]

					if type(info.to) == "table" then
						for to in pairs(info.to) do
							self.tracking_indents[to] = self.tracking_indents[to] or {}
							table.insert(self.tracking_indents[to], {info = info, level = self.level})
						end
					else
						self.tracking_indents[info.to] = self.tracking_indents[info.to] or {}
						table.insert(self.tracking_indents[info.to], {info = info, level = self.level})
					end
				elseif self.tracking_indents[token:GetValueString()] then
					for _, info in ipairs(assert(self.tracking_indents[token:GetValueString()])) do
						if info.level == self.level or info.level == self.pre_toggle_level then
							self:Outdent()
							local info = self.tracking_indents[token:GetValueString()]

							for key, val in pairs(self.tracking_indents) do
								if info == val.info then self.tracking_indents[key] = nil end
							end

							if self.out[self.last_indent_index] then
								self.out[self.last_indent_index] = self.out[self.last_indent_index]:sub(2)
							end

							if self.toggled_indents then
								self:Outdent()
								self.toggled_indents = {}

								if self.out[self.last_indent_index] then
									self.out[self.last_indent_index] = self.out[self.last_indent_index]:sub(2)
								end
							end

							break
						end
					end
				end

				if self.config.extra_indent[token:GetValueString()] == "toggle" then
					self.toggled_indents = self.toggled_indents or {}

					if not self.toggled_indents[token:GetValueString()] then
						self.toggled_indents[token:GetValueString()] = true
						self.pre_toggle_level = self.level
						self:Indent()
					elseif self.toggled_indents[token:GetValueString()] then
						if self.out[self.last_indent_index] then
							self.out[self.last_indent_index] = self.out[self.last_indent_index]:sub(2)
						end
					end
				end
			end

			if token:HasWhitespace() then
				local whitespace = token:GetWhitespace()

				if self.config.pretty_print == true then
					for i, wtoken in ipairs(whitespace) do
						if wtoken.type == "line_comment" then
							local start = i

							for i = self.i - 1, 1, -1 do
								local val = assert(self.out[i])

								if not val:find("^%s+") then
									local found_newline = false

									for i = start, 1, -1 do
										if whitespace[i]:GetValueString():find("\n") then
											found_newline = true

											break
										end
									end

									if not found_newline then
										self.i = i + 1
										self:Emit(" ")
									end

									break
								end
							end

							self:EmitToken(wtoken)

							if whitespace[i + 1] then
								self:Whitespace("\n")
								self:Whitespace("\t")
							end
						elseif wtoken.type == "multiline_comment" then
							self:EmitToken(wtoken)

							if whitespace[i + 1] then
								self:Whitespace("\n")
								self:Whitespace("\t")
							end
						end
					end
				else
					for _, wtoken in ipairs(whitespace) do
						if wtoken.type ~= "comment_escape" then self:EmitWhitespace(wtoken) end
					end
				end
			end

			translate = self:TranslateToken(token) or translate

			if translate then
				if type(translate) == "table" then
					self:Emit(translate[token:GetValueString()] or token:GetValueString())
				elseif type(translate) == "function" then
					self:Emit(translate(token:GetValueString()))
				elseif translate ~= "" then
					self:Emit(translate)
				end
			else
				self:Emit(token:GetValueString())
			end

			if
				token.type ~= "line_comment" and
				token.type ~= "multiline_comment" and
				token.type ~= "space"
			then
				self.last_non_space_index = #self.out
			end
		end

		function META:Initialize()
			self.level = 0
			self.out = {}
			self.i = 1
		end

		function META:Concat()
			return table.concat(self.out)
		end

		do
			function META:PushLoop(node--[[#: Node]])
				self.loop_nodes = self.loop_nodes or {}
				table.insert(self.loop_nodes, node)
			end

			function META:PopLoop()
				local node = table.remove(self.loop_nodes)

				if node.on_pop then node:on_pop() end
			end

			function META:GetLoopNode()
				if self.loop_nodes then return self.loop_nodes[#self.loop_nodes] end

				return nil
			end
		end
	end

	do -- newline breaking
		do
			function META:PushForcedLineBreaking(b--[[#: boolean]])
				self.force_newlines = self.force_newlines or {}
				table.insert(self.force_newlines, b)
			end

			function META:PopForcedLineBreaking()
				assert(self.force_newlines)
				table.remove(self.force_newlines)
			end

			function META:IsLineBreaking()
				if self.force_newlines then return self.force_newlines[#self.force_newlines] end
			end
		end

		function META:ShouldLineBreakNode(node--[[#: Node]])
			if self.config.pretty_print ~= true then return false end

			if node.Type == "expression_table" or node.Type == "expression_type_table" then
				for _, exp in ipairs(node.children) do
					if exp.value_expression and exp.value_expression.Type == "expression_function" then
						return true
					end
				end

				if #node.children > 0 and #node.children == #node.tokens["separators"] then
					return true
				end
			end

			if node.Type == "expression_function" then return #node.statements > 1 end

			if node.Type == "statement_if" then
				for i = 1, #node.statements do
					if #node.statements[i] > 1 then return true end
				end
			end

			return node:GetLength() > self.config.max_line_length
		end

		function META:EmitLineBreakableExpression(node--[[#: Node]])
			local newlines = self:ShouldLineBreakNode(node)

			if newlines then
				self:Indent()
				self:Whitespace("\n")
				self:Whitespace("\t")
			else
				self:Whitespace(" ")
			end

			self:PushForcedLineBreaking(newlines)
			self:EmitExpression(node)
			self:PopForcedLineBreaking()

			if newlines then
				self:Outdent()
				self:Whitespace("\n")
				self:Whitespace("\t")
			else
				self:Whitespace(" ")
			end
		end

		function META:EmitLineBreakableList(tbl, func)
			local newline = self:ShouldBreakExpressionList(tbl)
			self:PushForcedLineBreaking(newline)

			if newline then
				self:Indent()
				self:Whitespace("\n")
				self:Whitespace("\t")
			end

			func(self, tbl)

			if newline then
				self:Outdent()
				self:Whitespace("\n")
				self:Whitespace("\t")
			end

			self:PopForcedLineBreaking()
		end

		function META:EmitExpressionList(tbl)
			self:EmitNodeList(tbl, self.EmitExpression)
		end

		function META:EmitIdentifierList(tbl)
			self:EmitNodeList(tbl, self.EmitIdentifier)
		end
	end

	local function encapsulate_module(content, name, method)
		if method == "loadstring" then
			local len = 6

			content:gsub("%[[=]*%[", function(s)
				len = math.max(len, #s - 2)
			end)

			local eq = ("="):rep(len + 1)
			return "assert((loadstring or load)([" .. eq .. "[ return " .. content .. " ]" .. eq .. "], '" .. name .. "'))()"
		end

		return content
	end

	function META:BuildCode(block)
		if block.imports then
			self.done = {}
			self:EmitNonSpace("_G.IMPORTS = _G.IMPORTS or {}\n")

			for i, node in ipairs(block.imports) do
				if not self.done[node.key] then
					if node.data then
						self:Emit(
							"IMPORTS['" .. node.key .. "'] = function(...) return [===" .. "===[ " .. node.data .. " ]===" .. "===] end\n"
						)
					else
						-- ugly way of dealing with recursive import
						local root = node.RootStatement

						if root and root.Type ~= "statement_root" then root = root.RootStatement end

						if root then
							local content = root:Render(self.config or {})

							if content:sub(1, 1) == "#" then content = "--" .. content end

							if node.left.value.value == "loadfile" then
								self:Emit(
									"IMPORTS['" .. node.key .. "'] = " .. encapsulate_module(
											"function(...) " .. content .. " end",
											"@" .. node.path,
											self.config.module_encapsulation_method
										) .. "\n"
								)
							elseif node.left.value.value == "require" then
								self:Emit(
									"do local __M; IMPORTS[\"" .. node.key .. "\"] = function(...) __M = __M or (" .. encapsulate_module(
											"function(...) " .. content .. " end",
											"@" .. node.path,
											self.config.module_encapsulation_method
										) .. ")(...) return __M end end\n"
								)
							elseif self.config.inside_data_import then
								self:Emit("IMPORTS['" .. node.key .. "'] = function(...) " .. content .. " end\n")
							else
								self:Emit(
									"IMPORTS['" .. node.key .. "'] = " .. encapsulate_module(
											"function(...) " .. content .. " end",
											"@" .. node.path,
											self.config.module_encapsulation_method
										) .. "\n"
								)
							end
						end
					end

					self.done[node.key] = true
				end
			end
		end

		self:EmitStatements(block.statements)
		local str = self:Concat()

		if self.config.trailing_newline and str:find("\n", nil, true) then
			if str:sub(#str, #str) ~= "\n" then str = str .. "\n" end
		end

		return str
	end

	function META:OptionalWhitespace()
		if self.config.pretty_print == nil then return end

		if
			characters.IsLetter(self:GetPrevChar()) or
			characters.IsNumber(self:GetPrevChar())
		then
			self:EmitSpace(" ")
		end
	end

	do
		local function escape_string(str--[[#: string]], quote--[[#: string]])
			local new_str = {}

			for i = 1, #str do
				local c = str:sub(i, i)

				if c == quote then
					local escape_length = 0

					for i = i - 1, 1, -1 do
						if str:sub(i, i) == "\\" then
							escape_length = escape_length + 1
						else
							break
						end
					end

					if escape_length % 2 == 0 then
						new_str[i] = "\\" .. c
					else
						new_str[i] = c
					end
				else
					new_str[i] = c
				end
			end

			return table.concat(new_str)
		end

		function META:EmitStringToken(token--[[#: Token]])
			if self.config.string_quote then
				local current = token:GetValueString():sub(1, 1)
				local target = self.config.string_quote

				if current == "\"" or current == "'" then
					local contents = escape_string(token:GetValueString():sub(2, -2), target)
					self:EmitToken(token, target .. contents .. target)
					return
				end
			end

			local needs_space = token:GetValueString():sub(1, 1) == "[" and self:GetPrevChar() == B("[")

			if needs_space then self:Whitespace(" ") end

			self:EmitToken(token)

			if needs_space then self:Whitespace(" ") end
		end
	end

	function META:EmitNumberToken(token--[[#: Token]])
		self:EmitToken(token)
	end

	function META:EmitFunctionSignature(node--[[#: Node]])
		self:EmitToken(node.tokens["function"])
		self:EmitToken(node.tokens["="])
		self:EmitToken(node.tokens["arguments("])
		self:EmitLineBreakableList(node.identifiers, self.EmitIdentifierList)
		self:EmitToken(node.tokens["arguments)"])
		self:EmitToken(node.tokens[">"])
		self:EmitToken(node.tokens["return("])
		self:EmitLineBreakableList(node.return_types, self.EmitExpressionList)
		self:EmitToken(node.tokens["return)"])
	end

	function META:EmitExpression(node--[[#: Node]])
		local emitted_invalid_code = false
		local newlines = self:IsLineBreaking()

		if node.tokens["^"] then self:EmitToken(node.tokens["^"]) end

		if node.tokens["("] then
			for i = #node.tokens["("], 1, -1 do
				self:EmitToken(node.tokens["("][i])
			end

			if node.tokens["("] and newlines then
				self:Indent()
				self:Whitespace("\n")
				self:Whitespace("\t")
			end
		end

		if node.Type == "expression_lsx" then
			if self.config.transpile_extensions then
				self:EmitTranspiledLSXExpression(node)
			else
				self:EmitLSXExpression(node)
			end
		elseif node.Type == "expression_binary_operator" then
			self:EmitBinaryOperator(node)
		elseif node.Type == "expression_function" then
			self:EmitAnonymousFunction(node)
		elseif node.Type == "expression_analyzer_function" then
			emitted_invalid_code = self:EmitInvalidLuaCode("EmitAnalyzerFunction", node)
		elseif node.Type == "expression_table" then
			self:EmitTable(node)
		elseif node.Type == "expression_prefix_operator" then
			self:EmitPrefixOperator(node)
		elseif node.Type == "expression_postfix_operator" then
			self:EmitPostfixOperator(node)
		elseif node.Type == "expression_postfix_call" then
			if node.import_expression then
				if not node.path or node.type_call then
					emitted_invalid_code = self:EmitInvalidLuaCode("EmitImportExpression", node)
				else
					self:EmitImportExpression(node)
				end
			elseif node.require_expression then
				self:EmitImportExpression(node)
			elseif node.expressions_typesystem then
				self:EmitCall(node)
			elseif node.type_call then
				emitted_invalid_code = self:EmitInvalidLuaCode("EmitCall", node)
			else
				self:EmitCall(node)
			end
		elseif node.Type == "expression_postfix_expression_index" then
			self:EmitExpressionIndex(node)
		elseif node.Type == "expression_value" then
			if node.value.type == "string" then
				self:EmitStringToken(node.value)
			elseif node.value.type == "number" then
				self:EmitNumberToken(node.value)
			else
				self:EmitToken(node.value)
			end
		elseif node.Type == "expression_require" then
			self:EmitRequireExpression(node)
		elseif node.Type == "expression_type_table" then
			self:EmitTableType(node)
		elseif node.Type == "expression_table_expression_value" then
			self:EmitTableExpressionValue(node)
		elseif node.Type == "sub_statement_table_key_value" then
			self:EmitTableKeyValue(node)
		elseif node.Type == "expression_empty_union" then
			self:EmitEmptyUnion(node)
		elseif node.Type == "expression_tuple" then
			self:EmitTuple(node)
		elseif node.Type == "expression_type_function" then
			emitted_invalid_code = self:EmitInvalidLuaCode("EmitTypeFunction", node)
		elseif node.Type == "expression_function_signature" then
			emitted_invalid_code = self:EmitInvalidLuaCode("EmitFunctionSignature", node)
		elseif node.Type == "expression_vararg" then
			self:EmitVararg(node)
		elseif self.FFI_DECLARATION_EMITTER and node.Type == "expression_c_declaration" then
			self:EmitCDeclaration(node)
		elseif node.Type == "expression_dollar_sign" then
			self:EmitToken(node.tokens["$"])
		elseif node.Type == "expression_error" then

		else
			error("unhandled expression " .. node.Type)
		end

		if node.tokens[")"] and newlines then
			self:Outdent()
			self:Whitespace("\n")
			self:Whitespace("\t")
		end

		if not node.tokens[")"] then
			if self.config.type_annotations and node.tokens[":"] then
				self:EmitInvalidLuaCode("EmitColonAnnotationExpression", node)
			end

			if self.config.type_annotations and node.tokens["as"] then
				self:EmitInvalidLuaCode("EmitAsAnnotationExpression", node)
			end
		else
			local colon_expression = false
			local as_expression = false

			for _, token in ipairs(node.tokens[")"]) do
				if not colon_expression then
					if
						self.config.type_annotations and
						node.tokens[":"] and
						node.tokens[":"].stop < token.start
					then
						self:EmitInvalidLuaCode("EmitColonAnnotationExpression", node)
						colon_expression = true
					end
				end

				if not as_expression then
					if
						self.config.type_annotations and
						node.tokens["as"] and
						node.tokens["as"].stop < token.start
					then
						self:EmitInvalidLuaCode("EmitAsAnnotationExpression", node)
						as_expression = true
					end
				end

				self:EmitToken(token)
			end

			if not colon_expression then
				if self.config.type_annotations and node.tokens[":"] then
					self:EmitInvalidLuaCode("EmitColonAnnotationExpression", node)
				end
			end

			if not as_expression then
				if self.config.type_annotations and node.tokens["as"] then
					self:EmitInvalidLuaCode("EmitAsAnnotationExpression", node)
				end
			end
		end

		if
			emitted_invalid_code and
			not self.is_call_expression and
			(
				self.config.comment_type_annotations or
				self.config.omit_invalid_code
			)
		then
			self:EmitNonSpace("nil")
		end
	end

	function META:EmitVarargTuple(node--[[#: Node]])
		self:Emit(tostring(node:GetLastAssociatedType()))
	end

	function META:EmitExpressionIndex(node--[[#: Node]])
		self:EmitExpression(node.left)
		self:EmitToken(node.tokens["["])
		self:EmitExpression(node.expression)
		self:EmitToken(node.tokens["]"])
	end

	function META:EmitCall(node--[[#: Node]])
		local multiline_string = false

		if #node.expressions == 1 and node.expressions[1].Type == "expression_value" then
			multiline_string = node.expressions[1].value:GetValueString():sub(1, 1) == "["
		end

		-- this will not work for calls with functions that contain statements
		self.inside_call_expression = true
		self:EmitExpression(node.left)

		if node.expressions_typesystem and not self.config.omit_invalid_code then
			local emitted = self:StartEmittingInvalidLuaCode()
			self:EmitToken(node.tokens["call_typesystem("])
			self:EmitExpressionList(node.expressions_typesystem)
			self:EmitToken(node.tokens["call_typesystem)"])
			self:StopEmittingInvalidLuaCode(emitted)
		end

		if node.tokens["call("] then
			self:EmitToken(node.tokens["call("])
		else
			if self.config.force_parenthesis and not multiline_string then
				self:EmitNonSpace("(")
			end
		end

		local newlines = self:ShouldBreakExpressionList(node.expressions)

		if multiline_string then newlines = false end

		local last = node.expressions[#node.expressions]

		if last and last.Type == "expression_function" and #node.expressions < 4 then
			newlines = false
		end

		if node.tokens["call("] and newlines then
			self:Indent()
			self:Whitespace("\n")
			self:Whitespace("\t")
		end

		self:PushForcedLineBreaking(newlines)
		self:EmitExpressionList(node.expressions)
		self:PopForcedLineBreaking()

		if newlines then self:Outdent() end

		if node.tokens["call)"] then
			if newlines then
				self:Whitespace("\n")
				self:Whitespace("\t")
			end

			self:EmitToken(node.tokens["call)"])
		else
			if self.config.force_parenthesis and not multiline_string then
				if newlines then
					self:Whitespace("\n")
					self:Whitespace("\t")
				end

				self:EmitNonSpace(")")
			end
		end

		self.inside_call_expression = false
	end

	do
		function META:EmitFunctionBody(node--[[#: Node]], inject_analyzer_function_code)
			if node.identifiers_typesystem and not self.config.omit_invalid_code then
				local emitted = self:StartEmittingInvalidLuaCode()
				self:EmitToken(node.tokens["arguments_typesystem("])
				self:EmitExpressionList(node.identifiers_typesystem)
				self:EmitToken(node.tokens["arguments_typesystem)"])
				self:StopEmittingInvalidLuaCode(emitted)
			end

			self:EmitToken(node.tokens["arguments("])
			self:EmitLineBreakableList(node.identifiers, self.EmitIdentifierList)
			self:EmitToken(node.tokens["arguments)"])
			self:EmitFunctionReturnAnnotation(node)

			if #node.statements == 0 then
				if inject_analyzer_function_code then self:Emit("__REPLACE_ME__") end

				self:Whitespace(" ")
			else
				self:Whitespace("\n")

				if inject_analyzer_function_code then self:Emit("__REPLACE_ME__") end

				self:EmitBlock(node.statements)
				self:Whitespace("\n")
				self:Whitespace("\t")
			end
		end

		function META:EmitAnonymousFunction(node--[[#: Node]])
			self:EmitToken(node.tokens["function"])
			local distance = (node.tokens["end"].start - node.tokens["arguments)"].start)
			self:EmitFunctionBody(node)
			self:EmitToken(node.tokens["end"])
		end

		function META:EmitLocalFunction(node--[[#: Node]])
			self:EmitToken(node.tokens["local"])
			self:Whitespace(" ")
			self:EmitToken(node.tokens["function"])
			self:Whitespace(" ")
			self:EmitToken(node.tokens["identifier"])
			self:EmitFunctionBody(node)
			self:EmitToken(node.tokens["end"])
		end

		function META:EmitLocalAnalyzerFunction(node--[[#: Node]])
			self:EmitToken(node.tokens["local"])
			self:Whitespace(" ")
			self:EmitToken(node.tokens["analyzer"])
			self:Whitespace(" ")
			self:EmitToken(node.tokens["function"])
			self:Whitespace(" ")
			self:EmitToken(node.tokens["identifier"])
			self:EmitFunctionBody(node)
			self:EmitToken(node.tokens["end"])
		end

		function META:EmitLocalTypeFunction(node--[[#: Node]])
			self:EmitToken(node.tokens["local"])
			self:Whitespace(" ")
			self:EmitToken(node.tokens["function"])
			self:Whitespace(" ")
			self:EmitToken(node.tokens["identifier"])
			self:EmitFunctionBody(node)
			self:EmitToken(node.tokens["end"])
		end

		function META:EmitTypeFunction(node--[[#: Node]])
			self:EmitToken(node.tokens["function"])
			self:Whitespace(" ")

			if node.Type == "expression_type_function" then
				if node.expression then self:EmitExpression(node.expression) end
			end

			self:EmitFunctionBody(node)
			self:EmitToken(node.tokens["end"])
		end

		function META:EmitFunction(node--[[#: Node]])
			if node.tokens["local"] then
				self:EmitToken(node.tokens["local"])
				self:Whitespace(" ")
			end

			self:EmitToken(node.tokens["function"])
			self:Whitespace(" ")
			self:EmitExpression(node.expression or node.identifier)
			self:EmitFunctionBody(node)
			self:EmitToken(node.tokens["end"])
		end

		function META:EmitAnalyzerFunctionStatement(node--[[#: Node]])
			if node.tokens["local"] then
				self:EmitToken(node.tokens["local"])
				self:Whitespace(" ")
			end

			if node.tokens["analyzer"] then
				self:EmitToken(node.tokens["analyzer"])
				self:Whitespace(" ")
			end

			self:EmitToken(node.tokens["function"])
			self:Whitespace(" ")

			if node.tokens["^"] then self:EmitToken(node.tokens["^"]) end

			if node.expression or node.identifier then
				self:EmitExpression(node.expression or node.identifier)
			end

			self:EmitFunctionBody(node)
			self:EmitToken(node.tokens["end"])
		end
	end

	function META:EmitTableExpressionValue(node--[[#: Node]])
		self:EmitToken(node.tokens["["])
		self:EmitExpression(node.key_expression)
		self:EmitToken(node.tokens["]"])

		if node.tokens[":"] then
			local ok = self:StartEmittingInvalidLuaCode()
			self:EmitToken(node.tokens[":"])
			self:Whitespace(" ")
			self:EmitTypeExpression(node.type_expression)
			self:StopEmittingInvalidLuaCode(ok)
		end

		self:Whitespace(" ")
		self:EmitToken(node.tokens["="])
		self:Whitespace(" ")
		self:EmitExpression(node.value_expression)
	end

	function META:EmitTableKeyValue(node--[[#: Node]])
		self:EmitToken(node.tokens["identifier"])

		if node.tokens[":"] then
			local ok = self:StartEmittingInvalidLuaCode()
			self:EmitToken(node.tokens[":"])
			self:Whitespace(" ")
			self:EmitTypeExpression(node.type_expression)
			self:StopEmittingInvalidLuaCode(ok)
		end

		if node.tokens["="] then
			self:Whitespace(" ")
			self:EmitToken(node.tokens["="])
			self:Whitespace(" ")
			local break_binary = node.value_expression.Type == "expression_binary_operator" and
				self:ShouldLineBreakNode(node.value_expression)

			if break_binary then self:Indent() end

			self:PushForcedLineBreaking(break_binary)
			self:EmitExpression(node.value_expression)
			self:PopForcedLineBreaking()

			if break_binary then self:Outdent() end
		else
			self:EmitNonSpace(" = nil")
		end
	end

	function META:EmitEmptyUnion(node--[[#: Node]])
		self:EmitToken(node.tokens["|"])
	end

	function META:EmitTuple(node--[[#: Node]])
		self:EmitToken(node.tokens["("])
		self:EmitExpressionList(node.expressions)

		if #node.expressions == 1 then
			if node.expressions[1].tokens[","] then
				self:EmitToken(node.expressions[1].tokens[","])
			end
		end

		self:EmitToken(node.tokens[")"])
	end

	function META:EmitVararg(node--[[#: Node]])
		self:EmitToken(node.tokens["..."])

		if node.value then self:EmitExpression(node.value) end
	end

	function META:EmitTable(tree--[[#: Node]])
		if tree.spread then
			if self.config.omit_invalid_code then
				self:EmitNonSpace("table.mergetables")
			end
		end

		local during_spread = false
		self:EmitToken(tree.tokens["{"])
		local newline = self:ShouldLineBreakNode(tree)

		if newline then
			self:Whitespace("\n")
			self:Indent()
		end

		if tree.children[1] then
			for i, node in ipairs(tree.children) do
				if newline then self:Whitespace("\t") end

				if node.Type == "sub_statement_table_index_value" then
					if node.spread then
						if not self.config.omit_invalid_code then
							self:EmitToken(node.spread.tokens["..."])
							self:EmitExpression(node.spread.expression)
						else
							if during_spread then
								self:EmitNonSpace("},")
								during_spread = false
							end

							self:EmitExpression(node.spread.expression)
						end
					else
						self:EmitExpression(node.value_expression)
					end
				elseif node.Type == "sub_statement_table_key_value" then
					if self.config.omit_invalid_code and tree.spread and not during_spread then
						during_spread = true
						self:EmitNonSpace("{")
					end

					self:EmitTableKeyValue(node)
				elseif node.Type == "sub_statement_table_expression_value" then
					self:EmitTableExpressionValue(node)
				end

				if tree.tokens["separators"][i] then
					self:EmitToken(tree.tokens["separators"][i])
				else
					if newline then self:EmitNonSpace(",") end
				end

				if newline then
					self:Whitespace("\n")
				else
					if i ~= #tree.children then self:Whitespace(" ") end
				end
			end
		end

		if during_spread then self:EmitNonSpace("}") end

		if newline then
			self:Outdent()
			self:Whitespace("\t")
		end

		self:EmitToken(tree.tokens["}"])
	end

	do
		local translate_prefix = {
			["!"] = "not ",
		}

		function META:EmitPrefixOperator(node--[[#: Node]])
			local func_chunks = not self.config.skip_translation and
				node.environment == "runtime" and
				runtime_syntax:GetFunctionForPrefixOperator(node.value)

			if func_chunks then self:Emit(func_chunks[1]) end

			if
				runtime_syntax:IsKeyword(node.value) or
				runtime_syntax:IsNonStandardKeyword(node.value)
			then
				self:OptionalWhitespace()
			end

			self:EmitToken(
				node.value,
				not self.config.skip_translation and
					translate_prefix[node.value:GetValueString()] or
					nil
			)
			self:OptionalWhitespace()
			self:EmitExpression(node.right)

			if func_chunks then self:Emit(func_chunks[2]) end
		end
	end

	do
		local translate_binary = {
			["&&"] = "and",
			["||"] = "or",
			["!="] = "~=",
		}

		function META:EmitBinaryOperator(node--[[#: Node]])
			local func_chunks = not self.config.skip_translation and
				node.environment == "runtime" and
				runtime_syntax:GetFunctionForBinaryOperator(node.value)

			if func_chunks then self:Emit(func_chunks[1]) end

			if node.left then self:EmitExpression(node.left) end

			if func_chunks then self:Emit(func_chunks[2]) end

			if node.value.sub_type == "." or node.value.sub_type == ":" then
				self:EmitToken(node.value)
			else
				local special_break = 
					node.value.sub_type == ("and") or
					node.value.sub_type == ("or") or
					node.value.sub_type == ("||") or
					node.value.sub_type == ("&&")

				if special_break and self:IsLineBreaking() then
					if
						self:GetPrevChar() == B(")") and
						node.left.Type ~= "expression_postfix_call" and
						(
							node.left.Type == "expression_binary_operator" and
							node.left.right.Type ~= "expression_postfix_call"
						)
					then
						self:Whitespace("\n")
						self:Whitespace("\t")
					else
						self:Whitespace(" ")
					end
				else
					self:Whitespace(" ")
				end

				self:EmitToken(
					node.value,
					not self.config.skip_translation and
						translate_binary[node.value:GetValueString()] or
						nil
				)

				if special_break and self:IsLineBreaking() then
					if node.right then
						self:Whitespace("\n")
						self:Whitespace("\t")
					end
				else
					self:Whitespace(" ")
				end
			end

			if node.right then self:EmitExpression(node.right) end

			if func_chunks then self:Emit(func_chunks[3]) end
		end
	end

	function META:EmitPostfixOperator(node--[[#: Node]])
		local func_chunks = node.environment == "runtime" and
			runtime_syntax:GetFunctionForPostfixOperator(node.value)
		-- no such thing as postfix operator in lua,
		-- so we have to assume that there's a translation
		assert(func_chunks)
		self:Emit(func_chunks[1])
		self:EmitExpression(node.left)
		self:Emit(func_chunks[2])
	end

	function META:EmitBlock(statements--[[#: List<|Node|>]])
		self:PushForcedLineBreaking(false)
		self:Indent()
		self:EmitStatements(statements)
		self:Outdent()
		self:PopForcedLineBreaking()
	end

	function META:EmitIfStatement(node--[[#: Node]])
		local short = not self:ShouldLineBreakNode(node)

		for i = 1, #node.statements do
			if node.expressions[i] then
				if not short and i > 1 then
					self:Whitespace("\n")
					self:Whitespace("\t")
				end

				self:EmitToken(node.tokens["if/else/elseif"][i])
				self:EmitLineBreakableExpression(node.expressions[i])
				self:EmitToken(node.tokens["then"][i])
			elseif node.tokens["if/else/elseif"][i] then
				if not short then
					self:Whitespace("\n")
					self:Whitespace("\t")
				end

				self:EmitToken(node.tokens["if/else/elseif"][i])
			end

			if short then self:Whitespace(" ") else self:Whitespace("\n") end

			if #node.statements[i] == 1 and short then
				self:EmitStatement(node.statements[i][1])
			else
				self:EmitBlock(node.statements[i])
			end

			if short then self:Whitespace(" ") end
		end

		if not short then
			self:Whitespace("\n")
			self:Whitespace("\t")
		end

		self:EmitToken(node.tokens["end"])
	end

	function META:EmitGenericForStatement(node--[[#: Node]])
		self:EmitToken(node.tokens["for"])
		self:Whitespace(" ")
		self:EmitIdentifierList(node.identifiers)
		self:Whitespace(" ")
		self:EmitToken(node.tokens["in"])
		self:Whitespace(" ")
		self:EmitExpressionList(node.expressions)
		self:Whitespace(" ")
		self:EmitToken(node.tokens["do"])
		self:PushLoop(node)
		self:Whitespace("\n")
		self:EmitBlock(node.statements)
		self:Whitespace("\n")
		self:Whitespace("\t")
		self:PopLoop()
		self:EmitToken(node.tokens["end"])
	end

	function META:EmitNumericForStatement(node--[[#: Node]])
		self:EmitToken(node.tokens["for"])
		self:PushLoop(node)
		self:Whitespace(" ")
		self:EmitIdentifierList(node.identifiers)
		self:Whitespace(" ")
		self:EmitToken(node.tokens["="])
		self:Whitespace(" ")
		self:EmitExpressionList(node.expressions)
		self:Whitespace(" ")
		self:EmitToken(node.tokens["do"])
		self:Whitespace("\n")
		self:EmitBlock(node.statements)
		self:Whitespace("\n")
		self:Whitespace("\t")
		self:PopLoop()
		self:EmitToken(node.tokens["end"])
	end

	function META:EmitWhileStatement(node--[[#: Node]])
		self:EmitToken(node.tokens["while"])
		self:EmitLineBreakableExpression(node.expression)
		self:EmitToken(node.tokens["do"])
		self:PushLoop(node)
		self:Whitespace("\n")
		self:EmitBlock(node.statements)
		self:Whitespace("\n")
		self:Whitespace("\t")
		self:PopLoop()
		self:EmitToken(node.tokens["end"])
	end

	function META:EmitRepeatStatement(node--[[#: Node]])
		self:EmitToken(node.tokens["repeat"])
		self:PushLoop(node)
		self:Whitespace("\n")
		self:EmitBlock(node.statements)
		self:Whitespace("\t")
		self:Whitespace("\n")
		self:Whitespace("\t")
		self:PopLoop()
		self:EmitToken(node.tokens["until"])
		self:Whitespace(" ")
		self:EmitExpression(node.expression)
	end

	function META:EmitLabelStatement(node--[[#: Node]])
		self:EmitToken(node.tokens["::"])
		self:EmitToken(node.tokens["identifier"])
		self:EmitToken(node.tokens["::"])
	end

	function META:EmitGotoStatement(node--[[#: Node]])
		self:EmitToken(node.tokens["goto"])
		self:Whitespace(" ")
		self:EmitToken(node.tokens["identifier"])
	end

	function META:EmitBreakStatement(node--[[#: Node]])
		self:EmitToken(node.tokens["break"])
	end

	function META:EmitContinueStatement(node--[[#: Node]])
		local loop_node = self.config.transpile_extensions and self:GetLoopNode()

		if loop_node then
			self:EmitToken(node.tokens["continue"], "goto __CONTINUE__")
			loop_node.on_pop = function()
				self:EmitNonSpace("::__CONTINUE__::;")
			end
		else
			self:EmitToken(node.tokens["continue"])
		end
	end

	function META:EmitDoStatement(node--[[#: Node]])
		self:EmitToken(node.tokens["do"])
		self:Whitespace("\n")
		self:EmitBlock(node.statements)
		self:Whitespace("\n")
		self:Whitespace("\t")
		self:EmitToken(node.tokens["end"])
	end

	function META:EmitReturnStatement(node--[[#: Node]])
		self:EmitToken(node.tokens["return"])

		if node.expressions[1] then
			self:Whitespace(" ")
			self:PushForcedLineBreaking(self:ShouldLineBreakNode(node))
			self:EmitExpressionList(node.expressions)
			self:PopForcedLineBreaking()
		end
	end

	function META:EmitSemicolonStatement(node--[[#: Node]])
		if self.config.no_semicolon then
			self:EmitToken(node.tokens[";"], "")
		else
			self:EmitToken(node.tokens[";"])
		end
	end

	function META:EmitAssignment(node--[[#: Node]])
		if node.tokens["local"] then
			self:EmitToken(node.tokens["local"])
			self:Whitespace(" ")
		end

		if node.tokens["type"] then
			self:EmitToken(node.tokens["type"])
			self:Whitespace(" ")
		end

		if node.tokens["local"] then
			self:EmitIdentifierList(node.left)
		else
			self:EmitExpressionList(node.left)
		end

		if node.tokens["="] then
			self:Whitespace(" ")
			self:EmitToken(node.tokens["="])
			self:Whitespace(" ")
			self:PushForcedLineBreaking(self:ShouldBreakExpressionList(node.right))
			self:EmitExpressionList(node.right)
			self:PopForcedLineBreaking()
		end
	end

	function META:EmitStatement(node--[[#: Node]])
		if node.Type == "statement_if" then
			self:EmitIfStatement(node)
		elseif node.Type == "statement_goto" then
			self:EmitGotoStatement(node)
		elseif node.Type == "statement_goto_label" then
			self:EmitLabelStatement(node)
		elseif node.Type == "statement_while" then
			self:EmitWhileStatement(node)
		elseif node.Type == "statement_repeat" then
			self:EmitRepeatStatement(node)
		elseif node.Type == "statement_break" then
			self:EmitBreakStatement(node)
		elseif node.Type == "statement_return" then
			self:EmitReturnStatement(node)
		elseif node.Type == "statement_numeric_for" then
			self:EmitNumericForStatement(node)
		elseif node.Type == "statement_generic_for" then
			self:EmitGenericForStatement(node)
		elseif node.Type == "statement_do" then
			self:EmitDoStatement(node)
		elseif node.Type == "statement_analyzer_function" then
			self:EmitInvalidLuaCode("EmitAnalyzerFunctionStatement", node)
		elseif node.Type == "statement_function" then
			self:EmitFunction(node)
		elseif node.Type == "statement_type_function" then
			self:EmitInvalidLuaCode("EmitFunction", node)
		elseif node.Type == "statement_local_function" then
			self:EmitLocalFunction(node)
		elseif node.Type == "statement_local_analyzer_function" then
			self:EmitInvalidLuaCode("EmitLocalAnalyzerFunction", node)
		elseif node.Type == "statement_local_type_function" then
			if node.identifiers_typesystem then
				self:EmitLocalTypeFunction(node)
			else
				self:EmitInvalidLuaCode("EmitLocalTypeFunction", node)
			end
		elseif node.Type == "statement_type_function" then
			self:EmitInvalidLuaCode("EmitTypeFunction", node)
		elseif
			node.Type == "statement_destructure_assignment" or
			node.Type == "statement_local_destructure_assignment"
		then
			if self.config.comment_type_annotations or node.environment == "typesystem" then
				self:EmitInvalidLuaCode("EmitDestructureAssignment", node)
			elseif self.config.transpile_extensions then
				self:EmitTranspiledDestructureAssignment(node)
			else
				self:EmitDestructureAssignment(node)
			end
		elseif node.Type == "statement_assignment" or node.Type == "statement_local_assignment" then
			if node.environment == "typesystem" and self.config.comment_type_annotations then
				self:EmitInvalidLuaCode("EmitAssignment", node)
			else
				self:EmitAssignment(node)

				if node.Type == "statement_assignment" then self:Emit_ENVFromAssignment(node) end
			end
		elseif node.Type == "statement_call_expression" then
			self.is_call_expression = true
			self:EmitExpression(node.value)
			self.is_call_expression = false
		elseif node.Type == "statement_shebang" then
			self:EmitToken(node.tokens["shebang"])
		elseif node.Type == "statement_continue" then
			self:EmitContinueStatement(node)
		elseif node.Type == "statement_semicolon" then
			self:EmitSemicolonStatement(node)

			if self.config.pretty_print == true then
				if self.out[self.i - 2] and self.out[self.i - 2] == "\n" then
					self.out[self.i - 2] = ""
				end
			end
		elseif node.Type == "statement_end_of_file" then
			self:EmitToken(node.tokens["end_of_file"])
		elseif node.Type == "statement_root" then
			self:BuildCode(node)
		elseif node.Type == "statement_analyzer_debug_code" then
			self:EmitInvalidLuaCode("EmitExpression", node.lua_code)
		elseif node.Type == "statement_parser_debug_code" then
			self:EmitInvalidLuaCode("EmitExpression", node.lua_code)
		elseif node.Type == "statement_error" then

		-- do nothing
		else
			error("unhandled statement: " .. node.Type)
		end

		if self.OnEmitStatement then
			if node.Type ~= "statement_end_of_file" then self:OnEmitStatement() end
		end
	end

	local function general_kind(self--[[#: META.@Self]], node--[[#: Node]])
		if node.Type == "statement_call_expression" then
			for i, v in ipairs(node.value.expressions) do
				if v.Type == "expression_function" then return "other" end
			end
		end

		if
			node.Type == "statement_call_expression" or
			node.Type == "statement_local_assignment" or
			node.Type == "statement_assignment" or
			node.Type == "statement_return"
		then
			return "expression_statement"
		end

		return "other"
	end

	function META:EmitStatements(tbl--[[#: List<|Node|>]])
		for i, node in ipairs(tbl) do
			if
				i > 1 and
				general_kind(self, node) == "other" and
				node.Type ~= "statement_end_of_file"
			then
				self:Whitespace("\n")
			end

			self:Whitespace("\t")
			self:EmitStatement(node)

			if
				node.Type ~= "statement_semicolon" and
				node.Type ~= "statement_end_of_file" and
				tbl[i + 1] and
				tbl[i + 1].Type ~= "statement_end_of_file"
			then
				self:Whitespace("\n")
			end

			if general_kind(self, node) == "other" then
				if tbl[i + 1] and general_kind(self, tbl[i + 1]) == "expression_statement" then
					self:Whitespace("\n")
				end
			end
		end
	end

	function META:ShouldBreakExpressionList(tbl--[[#: List<|Node|>]])
		if self.config.pretty_print ~= true then return true end

		if #tbl == 0 then return false end

		local first_node = tbl[1]
		local last_node = tbl[#tbl]
		--first_node = first_node:GetStatement()
		--last_node = last_node:GetStatement()
		local start = first_node.code_start
		local stop = last_node.code_stop
		return (stop - start) > self.config.max_line_length
	end

	function META:EmitNodeList(tbl--[[#: List<|Node|>]], func--[[#: Function]])
		for i = 1, #tbl do
			self:PushForcedLineBreaking(self:ShouldLineBreakNode(tbl[i]))
			local break_binary = self:IsLineBreaking() and tbl[i].Type == "expression_binary_operator"

			if break_binary then self:Indent() end

			func(self, tbl[i])

			if break_binary then self:Outdent() end

			self:PopForcedLineBreaking()

			if i ~= #tbl then
				self:EmitToken(tbl[i].tokens[","])

				if self:IsLineBreaking() then
					self:Whitespace("\n")
					self:Whitespace("\t")
				else
					self:Whitespace(" ")
				end
			end
		end
	end

	function META:HasTypeNotation(node--[[#: Node]])
		return node.type_expression or node:GetLastAssociatedType() or node.return_types
	end

	function META:EmitFunctionReturnAnnotationExpression(node, analyzer_function)
		if node.tokens["return:"] then
			self:EmitToken(node.tokens["return:"])
		else
			self:EmitNonSpace(":")
		end

		self:Whitespace(" ")

		if node.return_types then
			for i, exp in ipairs(node.return_types) do
				self:EmitTypeExpression(exp)

				if i ~= #node.return_types then
					self:EmitToken(exp.tokens[","])
					self:Whitespace(" ")
				end
			end
		elseif node:GetLastAssociatedType() and self.config.type_annotations ~= "explicit" then
			local str = {}
			-- this iterates the first return tuple
			local obj = node:GetLastAssociatedType():GetContract() or node:GetLastAssociatedType()

			if obj.Type == "function" then
				for i, v in ipairs(obj:GetOutputSignature():GetData()) do
					str[i] = tostring(v)
				end
			else
				str[1] = tostring(obj)
			end

			if str[1] then self:EmitNonSpace(table.concat(str, ", ")) end
		end
	end

	function META:EmitFunctionReturnAnnotation(node--[[#: Node]], analyzer_function--[[#: Node]])
		if not self.config.type_annotations then return end

		if self:HasTypeNotation(node) and node.tokens["return:"] then
			self:EmitInvalidLuaCode("EmitFunctionReturnAnnotationExpression", node, analyzer_function)
		end
	end

	function META:EmitAnnotationExpression(node--[[#: Node]])
		if node.type_expression then
			self:EmitTypeExpression(node.type_expression)
		elseif node:GetLastAssociatedType() and self.config.type_annotations ~= "explicit" then
			self:Emit(
				tostring(node:GetLastAssociatedType():GetContract() or node:GetLastAssociatedType())
			)
		end
	end

	function META:EmitAsAnnotationExpression(node--[[#: Node]])
		self:Whitespace(" ")
		self:EmitToken(node.tokens["as"])
		self:Whitespace(" ")
		self:EmitAnnotationExpression(node)
	end

	function META:EmitColonAnnotationExpression(node--[[#: Node]])
		if node.tokens[":"] then
			self:EmitToken(node.tokens[":"])
		else
			self:EmitNonSpace(":")
		end

		self:Whitespace(" ")
		self:EmitAnnotationExpression(node)
	end

	function META:EmitAnnotation(node--[[#: Node]])
		if not self.config.type_annotations then return end

		if self:HasTypeNotation(node) and not node.tokens["as"] then
			self:EmitInvalidLuaCode("EmitColonAnnotationExpression", node)
		end
	end

	function META:EmitIdentifier(node--[[#: Node]])
		if node.identifier then
			self:EmitToken(node.identifier)

			if not self.config.omit_invalid_code then
				local ok = self:StartEmittingInvalidLuaCode()
				self:EmitToken(node.tokens[":"])
				self:Whitespace(" ")
				self:EmitTypeExpression(node)
				self:StopEmittingInvalidLuaCode(ok)
			end

			return
		end

		self:EmitExpression(node)
	end

	do -- types
		function META:EmitTypeBinaryOperator(node--[[#: Node]])
			if node.left then self:EmitTypeExpression(node.left) end

			if node.value.sub_type == "." or node.value.sub_type == ":" then
				self:EmitToken(node.value)
			else
				self:Whitespace(" ")
				self:EmitToken(node.value)
				self:Whitespace(" ")
			end

			if node.right then self:EmitTypeExpression(node.right) end
		end

		function META:EmitType(node--[[#: Node]])
			self:EmitToken(node.value)
			self:EmitAnnotation(node)
		end

		function META:EmitTableType(node--[[#: Node]])
			local tree = node
			self:EmitToken(tree.tokens["{"])
			local newline = self:ShouldLineBreakNode(tree)

			if newline then
				self:Indent()
				self:Whitespace("\n")
			end

			if tree.children[1] then
				for i, node in ipairs(tree.children) do
					if newline then self:Whitespace("\t") end

					if node.Type == "sub_statement_table_index_value" then
						if node.spread then
							self:EmitToken(node.spread.tokens["..."])
							self:EmitExpression(node.spread.expression)
						else
							self:EmitTypeExpression(node.value_expression)
						end
					elseif node.Type == "sub_statement_table_key_value" then
						self:EmitToken(node.tokens["identifier"])
						self:Whitespace(" ")
						self:EmitToken(node.tokens["="])
						self:Whitespace(" ")
						self:EmitTypeExpression(node.value_expression)
					elseif node.Type == "sub_statement_table_expression_value" then
						self:EmitToken(node.tokens["["])
						self:EmitTypeExpression(node.key_expression)
						self:EmitToken(node.tokens["]"])
						self:Whitespace(" ")
						self:EmitToken(node.tokens["="])
						self:Whitespace(" ")
						self:EmitTypeExpression(node.value_expression)
					end

					if tree.tokens["separators"][i] then
						self:EmitToken(tree.tokens["separators"][i])
					else
						if newline then self:EmitNonSpace(",") end
					end

					if newline then
						self:Whitespace("\n")
					else
						if i ~= #tree.children then self:Whitespace(" ") end
					end
				end
			end

			if newline then
				self:Outdent()
				self:Whitespace("\t")
			end

			self:EmitToken(tree.tokens["}"])
		end

		function META:EmitAnalyzerFunction(node--[[#: Node]])
			if node.tokens["analyzer"] then
				self:EmitToken(node.tokens["analyzer"])
				self:Whitespace(" ")
			end

			self:EmitToken(node.tokens["function"])

			if node.tokens["^"] then self:EmitToken(node.tokens["^"]) end

			self:EmitFunctionBody(node)
			self:EmitToken(node.tokens["end"])
		end

		function META:EmitTypeExpression(node--[[#: Node]])
			if node.tokens["^"] then self:EmitToken(node.tokens["^"]) end

			if node.tokens["("] then
				for i = #node.tokens["("], 1, -1 do
					self:EmitToken(node.tokens["("][i])
				end
			end

			if node.Type == "expression_binary_operator" then
				self:EmitTypeBinaryOperator(node)
			elseif node.Type == "expression_analyzer_function" then
				self:EmitAnalyzerFunction(node)
			elseif node.Type == "expression_table" then
				self:EmitTable(node)
			elseif node.Type == "expression_prefix_operator" then
				self:EmitPrefixOperator(node)
			elseif node.Type == "expression_postfix_operator" then
				self:EmitPostfixOperator(node)
			elseif node.Type == "expression_postfix_call" then
				self:EmitCall(node)
			elseif node.Type == "expression_postfix_expression_index" then
				self:EmitExpressionIndex(node)
			elseif node.Type == "expression_value" then
				self:EmitToken(node.value)
			elseif node.Type == "expression_type_table" then
				self:EmitTableType(node)
			elseif node.Type == "expression_table_expression_value" then
				self:EmitTableExpressionValue(node)
			elseif node.Type == "expression_table_key_value" then
				self:EmitTableKeyValue(node)
			elseif node.Type == "expression_empty_union" then
				self:EmitEmptyUnion(node)
			elseif node.Type == "expression_tuple" then
				self:EmitTuple(node)
			elseif node.Type == "expression_type_function" then
				self:EmitTypeFunction(node)
			elseif node.Type == "expression_function" then
				self:EmitAnonymousFunction(node)
			elseif node.Type == "expression_function_signature" then
				self:EmitFunctionSignature(node)
			elseif node.Type == "expression_vararg" then
				self:EmitVararg(node)
			else
				error("unhandled expression: " .. node.Type)
			end

			if node.tokens["as"] then
				self:Whitespace(" ")
				self:EmitToken(node.tokens["as"])
				self:Whitespace(" ")
			end

			if node.type_expression then
				self:EmitTypeExpression(node.type_expression)
			end

			if node.tokens[")"] then
				for _, node in ipairs(node.tokens[")"]) do
					self:EmitToken(node)
				end
			end

			if node.tokens[")"] and newlines then
				self:Outdent()
				self:Whitespace("\n")
				self:Whitespace("\t")
			end
		end

		function META:StartEmittingInvalidLuaCode()
			local emitted = false

			if self.config.comment_type_annotations then
				if not self.during_comment_type or self.during_comment_type == 0 then
					self:EmitNonSpace("--[[#")
					emitted = #self.out
				end

				self.during_comment_type = self.during_comment_type or 0
				self.during_comment_type = self.during_comment_type + 1
			end

			return emitted
		end

		function META:StopEmittingInvalidLuaCode(emitted--[[#: false | number]])
			if emitted then
				if self:GetPrevChar() == B("]") then self:Emit(" ") end

				local needs_escape = false

				for i = emitted, #self.out do
					local str = self.out[i]

					if str:find("]]", nil, true) then
						self.out[emitted] = "--[=[#"
						needs_escape = true

						break
					end
				end

				if needs_escape then
					self:EmitNonSpace("]=]")
				else
					self:EmitNonSpace("]]")
				end
			end

			if self.config.comment_type_annotations then
				self.during_comment_type = self.during_comment_type - 1
			end
		end

		function META:EmitInvalidLuaCode(func--[[#: ref keysof<|META|>]], ...--[[#: ref ...any]])
			if self.config.omit_invalid_code then return true end

			local i = self.i
			local emitted = self:StartEmittingInvalidLuaCode()
			self[func](self, ...)
			self:StopEmittingInvalidLuaCode(emitted)

			if self.config.blank_invalid_code then
				for i = self.i, i, -1 do
					if self.out[i] then self.out[i] = "" end
				end
			end

			return emitted
		end
	end

	do -- extra
		function META:EmitTranspiledDestructureAssignment(node--[[#: Node]])
			self:EmitToken(node.tokens["{"], "")

			if node.default then
				self:EmitToken(node.default.value)
				self:EmitToken(node.default_comma)
			end

			self:EmitToken(node.tokens["{"], "")
			self:Whitespace(" ")
			self:EmitIdentifierList(node.left)
			self:EmitToken(node.tokens["}"], "")
			self:Whitespace(" ")
			self:EmitToken(node.tokens["="])
			self:Whitespace(" ")
			self:EmitNonSpace("table.destructure(")
			self:EmitExpression(node.right)
			self:EmitNonSpace(",")
			self:EmitSpace(" ")
			self:EmitNonSpace("{")

			for i, v in ipairs(node.left) do
				self:EmitNonSpace("\"")
				self:Emit(v.value.value)
				self:EmitNonSpace("\"")

				if i ~= #node.left then
					self:EmitNonSpace(",")
					self:EmitSpace(" ")
				end
			end

			self:EmitNonSpace("}")

			if node.default then
				self:EmitNonSpace(",")
				self:EmitSpace(" ")
				self:EmitNonSpace("true")
			end

			self:EmitNonSpace(")")
		end

		function META:EmitDestructureAssignment(node--[[#: Node]])
			if node.tokens["local"] then self:EmitToken(node.tokens["local"]) end

			if node.tokens["type"] then
				self:Whitespace(" ")
				self:EmitToken(node.tokens["type"])
			end

			self:Whitespace(" ")
			self:EmitToken(node.tokens["{"])
			self:Whitespace(" ")
			self:EmitLineBreakableList(node.left, self.EmitIdentifierList)
			self:PopForcedLineBreaking()
			self:Whitespace(" ")
			self:EmitToken(node.tokens["}"])
			self:Whitespace(" ")
			self:EmitToken(node.tokens["="])
			self:Whitespace(" ")
			self:EmitExpression(node.right)
		end

		function META:Emit_ENVFromAssignment(node--[[#: Node]])
			for i, v in ipairs(node.left) do
				if v.Type == "expression_value" and v.value:ValueEquals("_ENV") then
					if node.right[i] then
						local key = node.left[i]
						local val = node.right[i]
						self:EmitNonSpace(";setfenv(1, _ENV);")
					end
				end
			end
		end

		function META:EmitImportExpression(node--[[#: Node]])
			if not node.path then
				self:EmitToken(node.left.value)
			else
				self:EmitToken(node.left.value, "IMPORTS['" .. node.key .. "']")
			end

			if not node.left.value:ValueEquals("loadfile") or not node.path then
				if node.tokens["call("] then
					self:EmitToken(node.tokens["call("])
				elseif self.config.force_parenthesis then
					self:EmitNonSpace("(")
				end

				self:EmitExpressionList(node.expressions)

				if node.tokens["call)"] then
					self:EmitToken(node.tokens["call)"])
				elseif self.config.force_parenthesis then
					self:EmitNonSpace(")")
				end
			end
		end

		function META:EmitRequireExpression(node--[[#: Node]])
			self:EmitToken(node.tokens["require"])
			self:EmitToken(node.tokens["arguments("])
			self:EmitExpressionList(node.expressions)
			self:EmitToken(node.tokens["arguments)"])
		end
	end

	do
		function META:EmitLSXExpression(node)
			self:EmitToken(node.tokens["<"])
			self:EmitExpression(node.tag)
			local len = 0

			for _, prop in ipairs(node.props) do
				len = len + prop:GetLength()
			end

			local line_break = len > self.config.max_line_length

			if line_break then self:Indent() end

			for _, prop in ipairs(node.props) do
				if line_break then
					self:Whitespace("\n")
					self:Whitespace("\t")
				end

				if prop.Type == "expression_table_spread" then
					if not line_break then self:Whitespace(" ") end

					self:EmitToken(prop.tokens["{"])
					self:EmitToken(prop.tokens["..."])
					self:EmitExpression(prop.expression)
					self:EmitToken(prop.tokens["}"])
				else
					if not line_break then self:Whitespace(" ") end

					self:EmitToken(prop.tokens["identifier"])
					self:EmitToken(prop.tokens["="])

					if prop.tokens["{"] then
						self:EmitToken(prop.tokens["{"])
						self:EmitExpression(prop.value_expression)
						self:EmitToken(prop.tokens["}"])
					else
						self:EmitExpression(prop.value_expression)
					end
				end
			end

			if line_break then self:Outdent() end

			if node.children[1] then
				if line_break then
					self:Whitespace("\n")
					self:Whitespace("\t")
				end

				self:EmitToken(node.tokens[">"])
				self:Indent()
				self:Whitespace("\n")
				self:Whitespace("\t")

				for i, child in ipairs(node.children) do
					if child.Type == "expression_value" then
						self:EmitExpression(child)
					elseif child.is_expression and child.Type == "expression_lsx" then
						self:EmitLSXExpression(child)
					else
						self:EmitToken(child.tokens["lsx{"])
						self:EmitExpression(child)
						self:EmitToken(child.tokens["lsx}"])
					end

					if i ~= #node.children then
						self:Whitespace("\n")
						self:Whitespace("\t")
					end
				end

				self:Outdent()
				self:Whitespace("\n")
				self:Whitespace("\t")
				self:EmitToken(node.tokens["<2"])
				self:EmitToken(node.tokens["/"])
				self:EmitToken(node.tokens["type2"])
				self:EmitToken(node.tokens[">2"])
			else
				if line_break then
					self:Whitespace("\n")
					self:Whitespace("\t")
				end

				self:EmitToken(node.tokens["/"])
				self:EmitToken(node.tokens[">"])
			end
		end

		function META:EmitTranspiledLSXExpression(node)
			self:EmitToken(node.tokens["<"], "LSX(")
			self:EmitExpression(node.tag)
			self:Emit(",")
			self:Emit("{")

			for i, prop in ipairs(node.props) do
				if prop.Type == "expression_table_spread" then
					self:Whitespace(" ")
					self:EmitToken(prop.tokens["{"])
					self:EmitToken(prop.tokens["..."])
					self:EmitExpression(prop.expression)
					self:EmitToken(prop.tokens["}"])
				else
					self:Whitespace(" ")
					self:EmitToken(prop.tokens["identifier"], "{k=")
					self:EmitNonSpace("\"")
					self:EmitNonSpace(prop.tokens["identifier"].value)
					self:EmitNonSpace("\"")
					self:EmitToken(prop.tokens["="], ",")
					self:EmitNonSpace("v=")

					if prop.tokens["{"] then
						self:EmitToken(prop.tokens["{"], "")
						self:EmitExpression(prop.value_expression)
						self:EmitToken(prop.tokens["}"], "")
					else
						self:EmitExpression(prop.value_expression)
					end

					self:Emit("}")
				end

				if i ~= #node.props then self:Emit(",") end
			end

			if node.children[1] then
				self:EmitToken(node.tokens[">"], "},{")
				self:Indent()
				self:Whitespace("\n")
				self:Whitespace("\t")

				for i, child in ipairs(node.children) do
					if child.Type == "expression_value" then
						self:EmitExpression(child)
					elseif child.is_expression and child.Type == "expression_lsx" then
						self:EmitTranspiledLSXExpression(child)
					else
						self:EmitToken(child.tokens["lsx{"], "")
						self:EmitExpression(child)
						self:EmitToken(child.tokens["lsx}"], "")
					end

					if i ~= #node.children then self:Emit(",") end
				end

				self:Outdent()
				self:Whitespace("\n")
				self:Whitespace("\t")
				self:EmitToken(node.tokens["<2"], "")
				self:EmitToken(node.tokens["/"], "")
				self:EmitToken(node.tokens["type2"], "")
				self:EmitToken(node.tokens[">2"], "})")
				self:Whitespace("\n")
				self:Whitespace("\t")
			else
				self:EmitToken(node.tokens["/"], "")
				self:EmitToken(node.tokens[">"], "})")
			end
		end
	end

	function META:TranslateToken(token)
		return nil
	end

	function META.New(config--[[#: EmitterConfig]])
		config = config or {}
		config.max_argument_length = config.max_argument_length or 5
		config.max_line_length = config.max_line_length or 80

		if config.comment_type_annotations == nil then
			config.comment_type_annotations = true
		end

		local self = META.NewObject(
			{
				level = 0,
				out = {},
				i = 1,
				config = config,
				last_non_space_index = false,
				force_newlines = false,
				during_comment_type = false,
				during_comment_type = false,
				is_call_expression = false,
				inside_call_expression = false,
				OnEmitStatement = false,
				loop_nodes = false,
				last_indent_index = false,
				last_newline_index = false,
				tracking_indents = false,
				toggled_indents = false,
				done = false,
				FFI_DECLARATION_EMITTER = false,
			},
			true
		)
		self:Initialize()
		return self
	end

	return META
end
