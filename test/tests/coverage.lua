local coverage = require("test.helpers.coverage")

local function collect(code)
	assert(load(coverage.Preprocess(code, "test")))()
	local res = coverage.Collect("test")
	coverage.Clear("test")
	return res
end

collect([[

    local foo = {
        bar = function() 
            local x = 1
            x = x + 1
            do return x end
            return x
        end
    }

    --foo:bar()

    for i = 1, 10 do
        -- lol
        if i == 15 then
            while false do
                notCovered:Test()
            end
        end
    end
]])
collect([=[
    local analyze = function() end
    analyze([[]])
    analyze[[]]  
]=])
collect[[
    local tbl = {}
    function tbl.ReceiveJSON(data, methods, ...)

    end
]]

collect[=[
--[[# print<|1|> ]]
]=]

assert(
	collect[[
local x = 1
local y = 2
local z = x + y or true]] == [=[local x = --[[1]]1
local y = --[[1]]2
local z = --[[1]]--[[1]]--[[1]]x + --[[1]]y or true]=]
)
collect([=[
--ANALYZE
local setmetatable = _G.setmetatable
local formating = require("nattlua.other.formating")
local class = require("nattlua.other.class")
local META = class.CreateTemplate("code")
--[[#type META.@Name = "Code"]]
--[[#type META.@Self = {
	Buffer = string,
	Name = string,
}]]

function META:LineCharToSubPos(line, char)
	return formating.LineCharToSubPosCached(self:GetString(), line, char)
end

function META:SubPosToLineChar(start, stop)
	return formating.SubPosToLineCharCached(self:GetString(), start, stop)
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
		lua_code = remove_bom_header(lua_code)
		name = name or get_default_name()
		local self = ctype(
			{
				Buffer = lua_code,
				buffer_len = #lua_code,
				Name = name,
				name_length = #name,
			}
		)
		refs[self] = lua_code
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
end

--[[#type META.Code = META.@Self]]
local code = META.New([[
    local foo = 1
    print(foo)
]], "test")


]=])
