--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]

local string = require("string")
local syntax = require("nattlua.syntax.syntax")

local function ReadNumberPowExponent(lexer--[[#: Lexer]], what--[[#: string]])
	lexer:Advance(1)

	if lexer:IsCurrentValue("+") or lexer:IsCurrentValue("-") then
		lexer:Advance(1)

		if not syntax.IsNumber(lexer:GetCurrentByteChar()) then
			lexer:Error(
				"malformed " .. what .. " expected number, got " .. string.char(lexer:GetCurrentByteChar()),
				lexer:GetPosition() - 2
			)
			return false
		end
	end

	while not lexer:TheEnd() do
		if not syntax.IsNumber(lexer:GetCurrentByteChar()) then break end
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
	if not lexer:IsString("0") or (not lexer:IsString("x", 1) and not lexer:IsString("X", 1)) then
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
			if syntax.IsSpace(lexer:GetByte()) or syntax.IsSymbol(lexer:GetByte()) then
				break
			end

			if lexer:IsString("p") or lexer:IsString("P") then
				if ReadNumberPowExponent(lexer, "pow") then
					break
				end
			end

			if  syntax.ReadNumberAnnotation(lexer) then break end

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
	if not lexer:IsString("0") or (not lexer:IsString("b", 1) and not lexer:IsString("B", 1)) then
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
			if syntax.IsSpace(lexer:GetCurrentByteChar()) or syntax.IsSymbol(lexer:GetCurrentByteChar()) then
				break
			end

			if lexer:IsString("e") or lexer:IsString("E") then
				if ReadNumberPowExponent(lexer, "exponent") then
					break
				end
			end

			if  syntax.ReadNumberAnnotation(lexer) then break end
			
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
	if not syntax.IsNumber(lexer:GetCurrentByteChar()) and (not lexer:IsCurrentValue(".") or not syntax.IsNumber(lexer:GetChar(1))) then 
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

		if syntax.IsNumber(lexer:GetByte()) then
			lexer:Advance(1)
        else
			if syntax.IsSpace(lexer:GetByte()) or syntax.IsSymbol(lexer:GetByte()) then
				break
			end

			if lexer:IsString("e") or lexer:IsString("E") then
				if ReadNumberPowExponent(lexer, "exponent") then
					break
				end
			end
			
			if  syntax.ReadNumberAnnotation(lexer) then break end

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
