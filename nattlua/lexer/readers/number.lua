--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]

local string = require("string")
local syntax = require("nattlua.syntax.syntax")
local BuildReadFunction = require("nattlua.lexer.build_read_function")
local IsInNumberAnnotation = BuildReadFunction(syntax.NumberAnnotations, true)

local function ReadNumberPowExponent(lexer--[[#: Lexer]], what--[[#: string]])
	lexer:Advance(1)

	if lexer:IsCurrentValue("+") or lexer:IsCurrentValue("-") then
		lexer:Advance(1)

		if not syntax.IsNumber(lexer:GetCurrentChar()) then
			lexer:Error(
				"malformed " .. what .. " expected number, got " .. string.char(lexer:GetCurrentChar()),
				lexer:GetPosition() - 2
			)
			return false
		end
	end

	while not lexer:TheEnd() do
		if not syntax.IsNumber(lexer:GetCurrentChar()) then break end
		lexer:Advance(1)
	end

	return true
end

local function ReadNumberAnnotations(lexer--[[#: Lexer]], what--[[#: "hex" | "decimal"]])
	if what == "hex" then
		if lexer:IsCurrentValue("p") or lexer:IsCurrentValue("P") then return ReadNumberPowExponent(lexer, "pow") end
	elseif what == "decimal" then
		if lexer:IsCurrentValue("e") or lexer:IsCurrentValue("E") then return ReadNumberPowExponent(lexer, "exponent") end
	end

	return IsInNumberAnnotation(lexer)
end

local function generate_map(str--[[#: string]])
	local out = {}

	for i = 1, #str do
		out[str:byte(i)] = true
	end

	return out
end

local allowed_hex = generate_map("1234567890abcdefABCDEF")

local function ReadHexNumber(lexer--[[#: Lexer]])
	lexer:Advance(2)
	local dot = false

	while not lexer:TheEnd() do
		if lexer:IsCurrentValue("_") then
			lexer:Advance(1)
		end

		if lexer:IsCurrentValue(".") then
			if dot then
                --self:Error("dot can only be placed once")
                return end
			dot = true
			lexer:Advance(1)
		end

		if ReadNumberAnnotations(lexer, "hex") then break end

		if allowed_hex[lexer:GetCurrentChar()] then
			lexer:Advance(1)
		elseif syntax.IsSpace(lexer:GetCurrentChar()) or syntax.IsSymbol(lexer:GetCurrentChar()) then
			break
		elseif lexer:GetCurrentChar() ~= 0 then
			lexer:Error(
				"malformed number " .. string.char(lexer:GetCurrentChar()) .. " in hex notation"
			)
			return
		end
	end
end

local function ReadBinaryNumber(lexer--[[#: Lexer]])
	lexer:Advance(2)

	while not lexer:TheEnd() do
		if lexer:IsCurrentValue("_") then
			lexer:Advance(1)
		end

		if lexer:IsCurrentValue("1") or lexer:IsCurrentValue("0") then
			lexer:Advance(1)
		elseif syntax.IsSpace(lexer:GetCurrentChar()) or syntax.IsSymbol(lexer:GetCurrentChar()) then
			break
		elseif lexer:GetCurrentChar() ~= 0 then
			lexer:Error(
				"malformed number " .. string.char(lexer:GetCurrentChar()) .. " in binary notation"
			)
			return
		end

		if ReadNumberAnnotations(lexer, "binary") then break end
	end
end

local function read_decimal_number(lexer--[[#: Lexer]])
	local dot = false

	while not lexer:TheEnd() do
		if lexer:IsCurrentValue("_") then
			lexer:Advance(1)
		end

		if lexer:IsCurrentValue(".") then
			if dot then
                --self:Error("dot can only be placed once")
                return end
			dot = true
			lexer:Advance(1)
		end

		if ReadNumberAnnotations(lexer, "decimal") then break end

		if syntax.IsNumber(lexer:GetCurrentChar()) then
			lexer:Advance(1)
        --elseif self:IsSymbol() or self:IsSpace() then
            --break
        else--if self:GetCurrentChar() ~= 0 then
            --self:Error("malformed number "..self:GetCurrentChar().." in hex notation")
            break
		end
	end
end

return
	{
		number = function(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if
				syntax.IsNumber(lexer:GetCurrentChar()) or
				(lexer:IsCurrentValue(".") and syntax.IsNumber(lexer:GetChar(1)))
			then
				if lexer:IsValue("x", 1) or lexer:IsValue("X", 1) then
					ReadHexNumber(lexer)
				elseif lexer:IsValue("b", 1) or lexer:IsValue("B", 1) then
					ReadBinaryNumber(lexer)
				else
					read_decimal_number(lexer)
				end

				return "number"
			end

			return false
		end,
	}
