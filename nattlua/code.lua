local setmetatable = _G.setmetatable
local helpers = require("nattlua.other.helpers")
local class = require("nattlua.other.class")
local META = class.CreateTemplate("code")
--[[#type META.@Name = "Code"]]
--[[#type META.@Self = {
	Buffer = string,
	Name = string,
}]]

function META:GetString()
	return self.Buffer
end

function META:GetName()
	return self.Name
end

function META:GetByteSize()
	return #self.Buffer
end

function META:GetStringSlice(start--[[#: number]], stop--[[#: number]])
	return self.Buffer:sub(start, stop)
end

function META:IsStringSlice(start--[[#: number]], stop--[[#: number]], str--[[#: string]])
	return self.Buffer:sub(start, stop) == str
end

if jit then
	function META:IsStringSlice(start--[[#: number]], stop--[[#: number]], str--[[#: string]])
		for i = 1, #str do
			local a = self.Buffer:byte(start + i - 1)
			local b = str:byte(i)

			if a ~= b then return false end
		end

		return true
	end
end

function META:GetByte(pos--[[#: number]])
	return self.Buffer:byte(pos) or 0
end

function META:FindNearest(str--[[#: string]], start--[[#: number]])
	local _, pos = self.Buffer:find(str, start, true)

	if not pos then return nil end

	return pos + 1
end

function META:LineCharToSubPos(line, char)
	return helpers.LinePositionToSubPosition(self:GetString(), line, char)
end

function META:SubPosToLineChar(start, stop)
	return helpers.SubPositionToLinePosition(self:GetString(), start, stop)
end

local function remove_bom_header(str--[[#: string]])--[[#: string]]
	if str:sub(1, 2) == "\xFE\xFF" then
		return str:sub(3)
	elseif str:sub(1, 3) == "\xEF\xBB\xBF" then
		return str:sub(4)
	end

	return str
end

local function get_default_name()
	local info = debug.getinfo(3)

	if info then
		local parent_line = info.currentline
		local parent_name = info.source:sub(2)
		return parent_name .. ":" .. parent_line
	end

	return "unknown line : unknown name"
end

function META:BuildSourceCodePointMessage(
	msg--[[#: string]],
	start--[[#: number]],
	stop--[[#: number]],
	size--[[#: number]]
)
	return helpers.BuildSourceCodePointMessage(self:GetString(), self:GetName(), msg, start, stop, size)
end

function META.New(lua_code--[[#: string]], name--[[#: string | nil]])
	local self = setmetatable(
		{
			Buffer = remove_bom_header(lua_code),
			Name = name or get_default_name(),
		},
		META
	)
	return self
end

--[[#type META.Code = META.@Self]]
return META