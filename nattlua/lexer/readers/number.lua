--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]

local string = require("string")
local characters = require("nattlua.syntax.characters")
local runtime_syntax = require("nattlua.syntax.runtime")

local function ReadNumberPowExponent(lexer--[[#: Lexer]], what--[[#: string]])
	lexer:Advance(1)

	if lexer:IsCurrentValue("+") or lexer:IsCurrentValue("-") then
		lexer:Advance(1)

		if not characters.IsNumber(lexer:GetCurrentByteChar()) then
			lexer:Error(
				"malformed " .. what .. " expected number, got " .. string.char(lexer:GetCurrentByteChar()),
				lexer:GetPosition() - 2
			)
			return false
		end
	end

	while not lexer:TheEnd() do
		if not characters.IsNumber(lexer:GetCurrentByteChar()) then break end
		lexer:Advance(1)
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

local function ReadHexNumber(lexer--[[#: Lexer]])
	if not lexer:IsString("0") or not lexer:IsStringLower("x", 1) then
		return false
	end

	lexer:Advance(2)
	local has_dot = false

	while not lexer:TheEnd() do
		if lexer:IsCurrentValue("_") then
			lexer:Advance(1)
		end

		if not has_dot and lexer:IsString(".") then
			-- 22..66 would be a number range
            -- so we have to return 22 only
			if lexer:IsValue(".", 1) then
				break
			end
			
			has_dot = true
			lexer:Advance(1)
		end


		if allowed_hex[lexer:GetByte()] then
			lexer:Advance(1)
		else
			if characters.IsSpace(lexer:GetByte()) or characters.IsSymbol(lexer:GetByte()) then
				break
			end

			if lexer:IsStringLower("p") then
				if ReadNumberPowExponent(lexer, "pow") then
					break
				end
			end

			if lexer:ReadFirstFromArray(runtime_syntax:GetNumberAnnotations()) then break end

			lexer:Error(
				"malformed hex number, got " .. string.char(lexer:GetByte()),
				lexer:GetPosition() - 1,
				lexer:GetPosition()
			)

			return false
		end
	end

	return "number"
end

local function ReadBinaryNumber(lexer--[[#: Lexer]])
	if not lexer:IsString("0") or not lexer:IsStringLower("b", 1) then
		return false
	end

	-- skip past 0b
	lexer:Advance(2)

	while not lexer:TheEnd() do
		if lexer:IsString("_") then
			lexer:Advance(1)
		end

		if lexer:IsString("1") or lexer:IsString("0") then
			lexer:Advance(1)
		else
			if characters.IsSpace(lexer:GetCurrentByteChar()) or characters.IsSymbol(lexer:GetCurrentByteChar()) then
				break
			end

			if lexer:IsStringLower("e") then
				if ReadNumberPowExponent(lexer, "exponent") then
					break
				end
			end

			if lexer:ReadFirstFromArray(runtime_syntax:GetNumberAnnotations()) then break end
			
			lexer:Error(
				"malformed binary number, got " .. string.char(lexer:GetByte()),
				lexer:GetPosition() - 1,
				lexer:GetPosition()
			)
			return false
		end
	end

	return "number"
end

local function ReadDecimalNumber(lexer--[[#: Lexer]])
	if not characters.IsNumber(lexer:GetCurrentByteChar()) and (not lexer:IsCurrentValue(".") or not characters.IsNumber(lexer:GetChar(1))) then 
		return false
	end

	-- if we start with a dot
    -- .0
	local has_dot = false
	if lexer:IsString(".") then
		has_dot = true
		lexer:Advance(1)
	end

	while not lexer:TheEnd() do
		if lexer:IsString("_") then
			lexer:Advance(1)
		end

		if not has_dot and lexer:IsString(".") then
			-- 22..66 would be a number range
            -- so we have to return 22 only
			if lexer:IsValue(".", 1) then
				break
			end
			
			has_dot = true
			lexer:Advance(1)
		end

		if characters.IsNumber(lexer:GetByte()) then
			lexer:Advance(1)
        else
			if characters.IsSpace(lexer:GetByte()) or characters.IsSymbol(lexer:GetByte()) then
				break
			end

			if lexer:IsString("e") or lexer:IsString("E") then
				if ReadNumberPowExponent(lexer, "exponent") then
					break
				end
			end
			
			if lexer:ReadFirstFromArray(runtime_syntax:GetNumberAnnotations()) then break end

			lexer:Error(
				"malformed number, got " .. string.char(lexer:GetByte()) .. " in decimal notation",
				lexer:GetPosition() - 1,
				lexer:GetPosition()
			)
			return false
		end
	end

	return "number"
end

return
	{
		ReadHexNumber = ReadHexNumber,
		ReadBinaryNumber = ReadBinaryNumber,
		ReadDecimalNumber = ReadDecimalNumber,
	}
