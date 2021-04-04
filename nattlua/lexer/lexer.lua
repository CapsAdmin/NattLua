--[[#local type { Token } = import_type("nattlua/lexer/token.nlua")]]

local syntax = require("nattlua.syntax.syntax")
local helpers = require("nattlua.other.helpers")
local load = loadstring or load
local META = {}
META.__index = META
--[[#type META.i = number]]
--[[#type META.@Name = "Lexer"]]

local function ReadLiteralString(self--[[#: META]], multiline_comment--[[#: boolean]])--[[#: Tuple<|boolean|> | Tuple<|false, string|>]]
	local start = self.i
	self:Advance(1)

	if self:IsCurrentValue("=") then
		while not self:TheEnd() do
			self:Advance(1)
			if not self:IsCurrentValue("=") then break end
		end
	end

	if not self:IsCurrentValue("[") then
		if multiline_comment then return false end
		return
			false,
			"expected " .. helpers.QuoteToken(self:GetChars(start, self.i - 1) .. "[") .. " got " .. helpers.QuoteToken(self:GetChars(start, self.i))
	end

	self:Advance(1)
	local closing = "]" .. string.rep("=", (self.i - start) - 2) .. "]"
	local pos = self:FindNearest(closing)

	if pos then
		self:Advance(pos)
		return true
	end

	return false, "expected " .. helpers.QuoteToken(closing) .. " reached end of code"
end

do
--[[#	type META.comment_escape = string]]

	function META:ReadCommentEscape()--[[#: boolean]]
		if
			self:IsValue("-", 0) and
			self:IsValue("-", 1) and
			self:IsValue("[", 2) and
			self:IsValue("[", 3) and
			self:IsValue("#", 4)
		then
			self:Advance(5)
			self.comment_escape = string.char(self:GetCurrentChar())
			return true
		end

		return false
	end

	function META:ReadRemainingCommentEscape()--[[#: boolean]]
		if self.comment_escape and self:IsValue("]", 0) and self:IsValue("]", 1) then
			self:Advance(2)
			return true
		end

		return false
	end
end

function META:ReadMultilineComment()--[[#: boolean]]
	if
		self:IsValue("-", 0) and
		self:IsValue("-", 1) and
		self:IsValue("[", 2) and
		(self:IsValue("[", 3) or self:IsValue("=", 3))
	then
		local start = self.i
		self:Advance(2)
		local ok, err = ReadLiteralString(self, true)

		if not ok then
			if err then
				self:Error("expected multiline comment to end: " .. err, start, start + 1)
				self:SetPosition(start + 2)
			else
				self:SetPosition(start)
			end
		end

		return ok
	end

	return false
end

function META:ReadLineComment()--[[#: boolean]]
	if self:IsValue("-", 0) and self:IsValue("-", 1) then
		self:Advance(#"--")

		while not self:TheEnd() do
			if self:IsCurrentValue("\n") then break end
			self:Advance(1)
		end

		return true
	end

	return false
end

function META:ReadCMultilineComment()--[[#: boolean]]
	if self:IsValue("/", 0) and self:IsValue("*", 1) then
		self:Advance(2)

		while not self:TheEnd() do
			if self:IsValue("*", 0) and self:IsValue("/", 1) then
				self:Advance(2)

				break
			end

			self:Advance(1)
		end

		return true
	end

	return false
end

function META:ReadCLineComment()--[[#: boolean]]
	if self:IsValue("/", 0) and self:IsValue("/", 1) then
		self:Advance(2)

		while not self:TheEnd() do
			if self:IsCurrentValue("\n") then break end
			self:Advance(1)
		end

		return true
	end

	return false
end

function META:ReadMultilineString()--[[#: boolean]]
	if self:IsValue("[", 0) and (self:IsValue("[", 1) or self:IsValue("=", 1)) then
		local start = self.i
		local ok, err = ReadLiteralString(self, false)

		if not ok and err then
			if err then -- TODO, err is nil | string
            self:Error("expected multiline string to end: " .. err, start, start + 1)
			end

			return true
		end

		return true
	end

	return false
end

do
	local function build_read_function(tbl--[[#: {[number] = string}]], lower--[[#: boolean]])
		local copy = {}
		local done = {}

		for _, str in ipairs(tbl) do
			if not done[str] then
				table.insert(copy, str)
				done[str] = true
			end
		end

		table.sort(copy, function(a, b)
			return #a > #b
		end)

		local kernel = "return function(self)\n"

		for _, str in ipairs(copy) do
			local lua = "if "

			for i = 1, #str do
				local func = "self:IsByte"
				local first_arg = str:byte(i)
				local second_arg = i - 1
				lua = lua .. "(" .. func .. "(" .. table.concat({first_arg, second_arg}, ",") .. ")"

				if lower then
					lua = lua .. " or "
					lua = lua .. func .. "(" .. table.concat({first_arg - 32, second_arg}, ",") .. ") "
				end

				lua = lua .. ")"

				if i ~= #str then
					lua = lua .. " and "
				end
			end

			lua = lua .. " then"
			lua = lua .. " self:Advance(" .. #str .. ") return true end -- " .. str
			kernel = kernel .. lua .. "\n"
		end

		kernel = kernel .. "\nend"
		return assert(load(kernel))()
	end

	META.ReadSymbol = build_read_function(syntax.GetSymbols(), false)
	META.IsInNumberAnnotation = build_read_function(syntax.NumberAnnotations, true)

	function META:ReadLetter()
		if syntax.IsLetter(self:GetCurrentChar()) then
			while not self:TheEnd() do
				self:Advance(1)
				if not syntax.IsDuringLetter(self:GetCurrentChar()) then break end
			end

			return true
		end

		return false
	end

	function META:ReadSpace()
		if syntax.IsSpace(self:GetCurrentChar()) then
			while not self:TheEnd() do
				self:Advance(1)
				if not syntax.IsSpace(self:GetCurrentChar()) then break end
			end

			return true
		end

		return false
	end

	function META:ReadNumberAnnotations(what--[[#: "hex" | "decimal"]])
		if what == "hex" then
			if self:IsCurrentValue("p") or self:IsCurrentValue("P") then return self:ReadNumberPowExponent("pow") end
		elseif what == "decimal" then
			if self:IsCurrentValue("e") or self:IsCurrentValue("E") then return self:ReadNumberPowExponent("exponent") end
		end

		return self:IsInNumberAnnotation()
	end

	function META:ReadNumberPowExponent(what--[[#: string]])
		self:Advance(1)

		if self:IsCurrentValue("+") or self:IsCurrentValue("-") then
			self:Advance(1)

			if not syntax.IsNumber(self:GetCurrentChar()) then
				self:Error("malformed " .. what .. " expected number, got " .. string.char(self:GetCurrentChar()), self.i - 2)
				return false
			end
		end

		while not self:TheEnd() do
			if not syntax.IsNumber(self:GetCurrentChar()) then break end
			self:Advance(1)
		end

		return true
	end

	local function generate_map(str--[[#: string]])
		local out = {}

		for i = 1, #str do
			out[str:byte(i)] = true
		end

		return out
	end

	local allowed_hex = generate_map("1234567890abcdefABCDEF")

	function META:ReadHexNumber()
		self:Advance(2)
		local dot = false

		while not self:TheEnd() do
			if self:IsCurrentValue("_") then
				self:Advance(1)
			end

			if self:IsCurrentValue(".") then
				if dot then
                    --self:Error("dot can only be placed once")
                    return end
				dot = true
				self:Advance(1)
			end

			if self:ReadNumberAnnotations("hex") then break end

			if allowed_hex[self:GetCurrentChar()] then
				self:Advance(1)
			elseif syntax.IsSpace(self:GetCurrentChar()) or syntax.IsSymbol(self:GetCurrentChar()) then
				break
			elseif self:GetCurrentChar() ~= 0 then
				self:Error(
					"malformed number " .. string.char(self:GetCurrentChar()) .. " in hex notation"
				)
				return
			end
		end
	end

	function META:ReadBinaryNumber()
		self:Advance(2)

		while not self:TheEnd() do
			if self:IsCurrentValue("_") then
				self:Advance(1)
			end

			if self:IsCurrentValue("1") or self:IsCurrentValue("0") then
				self:Advance(1)
			elseif syntax.IsSpace(self:GetCurrentChar()) or syntax.IsSymbol(self:GetCurrentChar()) then
				break
			elseif self:GetCurrentChar() ~= 0 then
				self:Error(
					"malformed number " .. string.char(self:GetCurrentChar()) .. " in binary notation"
				)
				return
			end

			if self:ReadNumberAnnotations("binary") then break end
		end
	end

	function META:ReadDecimalNumber()
		local dot = false

		while not self:TheEnd() do
			if self:IsCurrentValue("_") then
				self:Advance(1)
			end

			if self:IsCurrentValue(".") then
				if dot then
                    --self:Error("dot can only be placed once")
                    return end
				dot = true
				self:Advance(1)
			end

			if self:ReadNumberAnnotations("decimal") then break end

			if syntax.IsNumber(self:GetCurrentChar()) then
				self:Advance(1)
            --elseif self:IsSymbol() or self:IsSpace() then
                --break
            else--if self:GetCurrentChar() ~= 0 then
                --self:Error("malformed number "..self:GetCurrentChar().." in hex notation")
                break
			end
		end
	end

	function META:ReadNumber()
		if
			syntax.IsNumber(self:GetCurrentChar()) or
			(self:IsCurrentValue(".") and syntax.IsNumber(self:GetChar(1)))
		then
			if self:IsValue("x", 1) or self:IsValue("X", 1) then
				self:ReadHexNumber()
			elseif self:IsValue("b", 1) or self:IsValue("B", 1) then
				self:ReadBinaryNumber()
			else
				self:ReadDecimalNumber()
			end

			return true
		end

		return false
	end
end

function META:ReadInlineTypeCode()
	if self:IsCurrentValue("§") then
		self:Advance(1)

		while not self:TheEnd() do
			if self:IsCurrentValue("\n") then break end
			self:Advance(1)
		end

		return true
	end
end

do
	local B = string.byte
	local escape_character = B([[\]])
	local quotes = {Double = [["]], Single = [[']],}

	for name, quote in pairs(quotes) do
		META["Read" .. name .. "String"] = function(self--[[#: META]])
			if not self:IsCurrentValue(quote) then return false end
			local start = self.i
			self:Advance(1)

			while not self:TheEnd() do
				local char = self:ReadChar()

				if char == escape_character then
					local char = self:ReadChar()

					if char == B("z") and not self:IsCurrentValue(quote) then
						self:ReadSpace()
					end
				elseif char == B("\n") then
					self:Advance(-1)
					self:Error("expected " .. name:lower() .. " quote to end", start, self.i - 1)
					return true
				elseif char == B(quote) then
					return true
				end
			end

			self:Error(
				"expected " .. name:lower() .. " quote to end: reached end of file",
				start,
				self.i - 1
			)
			return true
		end
	end
end

function META:OnInitialize()
	self.comment_escape = false
end

function META:Read()
	if self:ReadRemainingCommentEscape() then return "discard", false end

	if self:ReadSpace() then
		return "space", true
	elseif self:ReadCommentEscape() then
		return "comment_escape", true
	elseif self:ReadCMultilineComment() then
		return "multiline_comment", true
	elseif self:ReadCLineComment() then
		return "line_comment", true
	elseif self:ReadMultilineComment() then
		return "multiline_comment", true
	elseif self:ReadLineComment() then
		return "line_comment", true
	elseif self:ReadInlineTypeCode() then
		return "type_code", false
	elseif self:ReadNumber() then
		return "number", false
	elseif self:ReadMultilineString() then
		return "string", false
	elseif self:ReadSingleString() then
		return "string", false
	elseif self:ReadDoubleString() then
		return "string", false
	elseif self:ReadLetter() then
		return "letter", false
	elseif self:ReadSymbol() then
		return "symbol", false
	elseif self:ReadEndOfFile() then
		return "end_of_file", false
	elseif false then

	end

	return self:ReadUnknown()
end

require("nattlua.lexer.base_lexer")(META)
return function(code--[[#: string]])
	local self = setmetatable({}, META)
	self:Initialize(code)
	return self
end
