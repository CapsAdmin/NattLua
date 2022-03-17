// prettier-ignore
export const assortedExamples = {
ffi:
`local ffi = require("ffi")
ffi.cdef[[
    unsigned long compressBound(unsigned long sourceLen);
    int compress2(char *dest, unsigned long *destLen, const char *source, unsigned long sourceLen, int level);
    int uncompress(char *dest, unsigned long *destLen, const char *source, unsigned long sourceLen);
]]
local zlib = ffi.load(ffi.os == "Windows" and "zlib1" or "z")

local function compress(txt: string)
	local n = zlib.compressBound(#txt)
	local buf = ffi.new("uint8_t[?]", n)
	local buflen = ffi.new("unsigned long[1]", n)
	local res = zlib.compress2(buf, buflen, txt, #txt, 9)
	assert(res == 0)
	return ffi.string(buf, buflen[0])
end

local function uncompress(comp: string, n: number)
	local buf = ffi.new("uint8_t[?]", n)
	local buflen = ffi.new("unsigned long[1]", n)
	local res = zlib.uncompress(buf, buflen, comp, #comp)
	assert(res == 0)
	return ffi.string(buf, buflen[0])
end

-- Simple test code.
local txt = string.rep("abcd", 10)
print("Uncompressed size: ", #txt)
local c = compress(txt)
print("Compressed size: ", #c)
local txt2 = uncompress(c, #txt)
assert(txt2 == txt)`,
string_parse: 
`local cfg = [[
    name=Lua
    cycle=123
    debug=yes
]]

local function parse(str: ref string)
    local tbl = {}
    for key, val in str:gmatch("(%S-)=(.-)\\n") do
        tbl[key] = val
    end
    return tbl
end

local tbl = parse(cfg) -- hover me`,


type_assert: 
`local function assert_whole_number<|T: number|>
	assert(math.floor(T) == T, "Expected whole number", 2)
end

local x = assert_whole_number<|5.5|>`,


array:
`local function Array<|T: any, L: number|>
	return {[1..L] = T}
end

local list: Array<|number, 3|> = {1, 2, 3, 4}`,


list_generic: 
`function List<|T: any|>
	return {[1..inf] = T | nil}
end

local names: List<|string|> = {} -- the | nil above is required to allow nil values, or an empty table in this case
names[1] = "foo"
names[2] = "bar"
names[-1] = "faz"`,


load_evaluation:
`local function build_summary_function(tbl)
	local lua = {}
	table.insert(lua, "local sum = 0")
	table.insert(lua, "for i = " .. tbl.init .. ", " .. tbl.max .. " do")
	table.insert(lua, tbl.body)
	table.insert(lua, "end")
	table.insert(lua, "return sum")
	return load(table.concat(lua, "\\n"), tbl.name)
end

local func = build_summary_function({
	name = "myfunc",
	init = 1,
	max = 10,
	body = "sum = sum + i !!ManuallyInsertedSyntaxError!!"
})`,


anagram_proof:
`local bytes = {}
for i,v in ipairs({
    "P", "S", "E", "L", "E",
}) do
    bytes[i] = string.byte(v)
end
local all_letters = _ as bytes[number] ~ nil -- remove nil from the union
local anagram = string.char(all_letters, all_letters, all_letters, all_letters, all_letters)

assert(anagram == "SLEEP")
print<|anagram|> -- see console or hover me`,

base64:
`local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' -- You will need this for encoding/decoding
-- encoding
local function enc(data: ref string)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        if not b then return r end
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

-- decoding
local function dec(data: ref string)
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
            return string.char(c)
    end))
end

local b64 = enc("hello world")
local txt = dec(b64)

attest.equal(txt, "hello world")`,

typescript:
`do
	local function Required<|tbl: Table|>
		local copy = {}
	
		for key, val in pairs(tbl) do
			copy[key] = val ~ nil
		end
	
		return copy
	end

	local type Props = {
		a = nil | number,
		b = nil | string,
	  }
	   
	  local obj: Props = { a = 5 }
	  local obj2 = Required<|Props|> = { a = 5 }
end

do
	local function Required<|tbl: Table|>
		local copy = {}

		for key, val in pairs(tbl) do
			copy[key] = val ~ nil
		end

		return copy
	end

	local type Props = {
		a = nil | number,
		b = nil | string,
	}
	local obj: Props = {a = 5}
	local obj2: Required<|Props|> = {a = 5}
end

do
	local function Readonly<|tbl: Table|>
		local copy = {}
	
		for key, val in pairs(tbl) do
			copy[key] = val
		end
	
		setmetatable<|
			copy,
			{
				__newindex = function(_, key)
					error("Cannot assign to '" .. key .. "' because it is a read-only property.", 2)
				end,
			}
		|>

		return copy
	end
	
	local type Todo = {
        title = string
    }

	local todo: Readonly<|Todo|> = {
		title = "Delete inactive users",
	}
    
	todo.title = "Hello"
end`
}
