--ANALYZE
local setmetatable = _G.setmetatable
local debug_getinfo = _G.debug.getinfo
local formating = require("nattlua.other.formating")
local class = require("nattlua.other.class")
local META = class.CreateTemplate("code")
--[[#type META.@Name = "Code"]]
--[[#type META.@Self = {
	Buffer = string,
	Name = string,
}]]

function META:LineCharToSubPos(line--[[#: number]], char--[[[#: number]])
	return formating.LineCharToSubPosCached(self:GetString(), line, char)
end

function META:SubPosToLineChar(start--[[#: number]], stop--[[#: number]])
	return formating.SubPosToLineCharCached(self:GetString(), start, stop)
end

local function get_default_name()
	local info = debug_getinfo(3)

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
	return formating.BuildSourceCodePointMessage(self:GetString(), self:GetName(), msg, start, stop, size)
end

local has_ffi, ffi = pcall(require, "ffi")

if has_ffi--[[# as false]] then
	--[[#-- todo, ffimetatype inference
	type META.@Self = {
		Buffer = string,
		buffer_len = number,
		Name = string,
		name_len = number,
	}]]

	function META:GetString()
		return ffi.string(self.Buffer, self.buffer_len)
	end

	function META:GetName()
		return ffi.string(self.Name, self.name_length)
	end

	function META:GetByteSize()
		return self.buffer_len
	end

	local ffi_string = ffi.string

	function META:GetStringSlice(start--[[#: number]], stop--[[#: number]])
		start = start - 1
		stop = stop - 1

		if start >= self.buffer_len then return "" end

		return ffi_string(self.Buffer + start, (stop - start) + 1)
	end

	function META:GetByte(pos--[[#: number]])
		return self.Buffer[pos - 1]
	end

	function META:FindNearest(str--[[#: string]], start--[[#: number]])
		local len = #str

		for i = start, self.buffer_len - 1 do
			if self:IsStringSlice(i, len, str) then return i + len end
		end
	end

	function META:IsStringSlice(start--[[#: number]], stop--[[#: number]], str--[[#: string]])
		start = start - 2

		for i = 1, #str do
			if self.Buffer[start + i] ~= str:byte(i) then return false end
		end

		return true
	end

	local ctype
	local refs = setmetatable({}, {_mode = "kv"})

	function META.New(lua_code--[[#: string]], name--[[#: string | nil]])
		name = name or get_default_name()
		local self = ctype(
			{
				Buffer = lua_code,
				buffer_len = #lua_code,
				Name = name,
				name_length = #name,
			}
		)

		if lua_code:sub(1, 2) == "\xFE\xFF" then
			self.Buffer = self.Buffer + 2
			self.buffer_len = self.buffer_len - 2
		elseif lua_code:sub(1, 3) == "\xEF\xBB\xBF" then
			self.Buffer = self.Buffer + 3
			self.buffer_len = self.buffer_len - 3
		end

		refs[self] = {lua_code, name}
		return self
	end

	ctype = ffi.metatype(
		ffi.typeof([[
			struct { 
				const uint8_t * Buffer; 
				uint32_t buffer_len; 
				const char * Name; 
				uint32_t name_length;
			}
			]]),
		META
	)
else
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

	function META:GetByte(pos--[[#: number]])
		return self.Buffer:byte(pos) or 0
	end

	function META:FindNearest(str--[[#: string]], start--[[#: number]])
		local _, pos = self.Buffer:find(str, start, true)

		if not pos then return nil end

		return pos + 1
	end

	if jit then
		-- this is faster in luajit than the else block
		function META:IsStringSlice(start--[[#: number]], stop--[[#: number]], str--[[#: string]])
			for i = 1, #str do
				local a = self.Buffer:byte(start + i - 1)
				local b = str:byte(i)

				if a ~= b then return false end
			end

			return true
		end
	else
		function META:IsStringSlice(start--[[#: number]], stop--[[#: number]], str--[[#: string]])
			return self.Buffer:sub(start, stop) == str
		end
	end

	local function remove_bom_header(str--[[#: string]])--[[#: string]]
		if str:sub(1, 2) == "\xFE\xFF" then
			return str:sub(3)
		elseif str:sub(1, 3) == "\xEF\xBB\xBF" then
			return str:sub(4)
		end

		return str
	end

	function META.New(lua_code--[[#: string]], name--[[#: string | nil]])
		return META.NewObject({
			Buffer = remove_bom_header(lua_code),
			Name = name or get_default_name(),
		})
	end
end

--[[#type META.Code = META.@Self]]
return META
