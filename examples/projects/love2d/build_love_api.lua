os.execute(
	"git clone git@github.com:love2d-community/love-api.git examples/projects/love2d/love-api"
)
local BuildBaseEnvironment = require("nattlua.runtime.base_environment").BuildBaseEnvironment
local tprint = require("nattlua.other.table_print")
local util = require("examples.util")
local LString = require("nattlua.types.string").LString
local nl = require("nattlua")

function string.split(self, separator, plain_search)
	if plain_search == nil then plain_search = true end

	local tbl = {}
	local current_pos = 1

	for i = 1, #self do
		local start_pos, end_pos = self:find(separator, current_pos, plain_search)

		if not start_pos then break end

		tbl[i] = self:sub(current_pos, start_pos - 1)
		current_pos = end_pos + 1
	end

	if current_pos > 1 then
		tbl[#tbl + 1] = self:sub(current_pos)
	else
		tbl[1] = self
	end

	return tbl
end

local wiki_json = require("examples.projects.love2d.love-api.love_api")
-- used for referencing existing types, like if we already have math.pi defined, don't add it
local _, base_env = BuildBaseEnvironment()
-- i prefix all types with I to avoid conflicts when defining functions like Entity(entindex) in the typesystem
local TypeMap = {}
local code = {}
local i = 1
local e = function(str)
	code[i] = str
	i = i + 1
end
local t = 0

local function indent()
	e(string.rep("\t", t))
end

local function sort(a, b)
	return a.key > b.key
end

local function to_list(map)
	local list = {}

	for k, v in pairs(map) do
		table.insert(list, {key = k, val = v})
	end

	table.sort(list, sort)
	return list
end

local function spairs(map)
	local list = to_list(map)
	local i = 0
	return function()
		i = i + 1

		if not list[i] then return end

		return list[i].key, list[i].val
	end
end

local function emit_description(desc)
	desc = desc:gsub("\n", function()
		return "\n" .. ("\t"):rep(t)
	end)
	e("\n")
	indent()
	e("--[[ " .. desc .. " ]]\n")
end

e("local type love = {}\n")
local known_types = {}
local emit_type

local function emit_table(info)
	e("{")

	for i, v in ipairs(info) do
		if v.name and not tonumber(v.name) and v.name ~= "..." then -- TODO
			e(v.name .. " = ")
			emit_type(v)
		else
			emit_type(v)
		end

		e(", ")
	end

	e("}")
end

function emit_type(t)
	if t.type == "RenderTargetSetup" then -- TODO
		e("any")
	elseif t.type == "tables and strings" then -- TODO
		e("(Table | string)")
	elseif t.name == "..." then
		e("...")
		emit_type({type = t.type})
	elseif t.type:find(" or ", nil, true) then
		local tbl = t.type:split(" or ")

		for i, v in ipairs(tbl) do
			emit_type({
				type = v,
			})

			if i ~= #tbl then e(" | ") end
		end
	elseif
		t.type == "number" or
		t.type == "string" or
		t.type == "boolean" or
		t.type == "nil" or
		t.type == "any"
	then
		e(t.type)
	elseif t.type == "Variant" then
		e("any")
	elseif t.type == "table" then
		if t.table then
			if t.name == "format" then
				e("Table") -- TODO
			else
				emit_table(t.table)
			end
		else
			e("Table")
		end
	elseif t.type == "cdata" then
		e("cdata")
	elseif t.type == "function" then
		e("Function")
	elseif t.type == "light userdata" then
		e("userdata")
	elseif known_types[t.type] then
		e(t.type)
	else
		print("NYI " .. t.type)
		table.print(t)
		e("any")
	end

	if t.default then e(" | nil") end
end

local function emit_tuple(tuple)
	for i, t in ipairs(tuple) do
		emit_type(t)

		if i ~= #tuple then e(", ") end
	end
end

local function emit_function_variant(func, self)
	e("function=(")

	if self then
		e(self)

		if func.arguments then e(", ") end
	end

	if func.arguments then emit_tuple(func.arguments) end

	e(")>(")

	if func.returns then emit_tuple(func.returns) end

	e(")")
end

local function emit_function(func_info, self)
	for i, variant in ipairs(func_info.variants) do
		emit_function_variant(variant, self)

		if i ~= #func_info.variants then e("|") end
	end

	e("\n")
end

local function emit_type_declaration(info)
	e("local type " .. info.name .. " = {}" .. "\n")
	e("type " .. info.name .. ".__index = " .. info.name .. "\n")
	e("type " .. info.name .. ".@MetaTable = " .. info.name .. "\n")
	e("type " .. info.name .. ".@Name = \"" .. info.name .. "\"\n")
	known_types[info.name] = true
end

local function emit_type_body(info)
	if info.supertypes then
		e("type " .. info.name .. ".@BaseTable = " .. info.supertypes[1] .. "\n")
	end

	for _, func_info in ipairs(info.functions) do
		e("type " .. info.name .. "." .. func_info.name .. " = ")
		emit_function(func_info, info.name)
	end

	e("\n")
end

local function emit_enum(info)
	e("local type " .. info.name .. " =\n\t")

	for i, constant in ipairs(info.constants) do
		-- TODO: proper escape
		if info.name == "KeyConstant" or info.name == "Scancode" then
			if constant.name == "]" then
				e("\"" .. constant.name .. "\"")
			else
				e("[[" .. constant.name .. "]]")
			end
		else
			e("\"" .. constant.name .. "\"")
		end

		if i ~= #info.constants then e("\n\t| ") end
	end

	e("\n")
	known_types[info.name] = true
end

do
	for _, module in ipairs(wiki_json.modules) do
		for _, info in ipairs(module.enums) do
			emit_enum(info)
		end
	end
end

do
	for _, info in ipairs(wiki_json.types) do
		emit_type_declaration(info)
	end

	for _, module in ipairs(wiki_json.modules) do
		for _, info in ipairs(module.types) do
			emit_type_declaration(info)
		end
	end

	for _, info in ipairs(wiki_json.types) do
		emit_type_body(info)
	end

	for _, module in ipairs(wiki_json.modules) do
		for _, info in ipairs(module.types) do
			emit_type_body(info)
		end
	end
end

do
	for _, info in ipairs(wiki_json.functions) do
		e("type love." .. info.name .. " = ")
		emit_function(info)
		e("\n")
	end

	for _, info in ipairs(wiki_json.callbacks) do
		e("type love." .. info.name .. " = ")
		emit_function(info)
		e("\n")
	end

	for _, module in ipairs(wiki_json.modules) do
		e("type love." .. module.name .. " = {}")
		e("\n")

		for _, info in ipairs(module.functions) do
			e("type love." .. module.name .. "." .. info.name .. " = ")
			emit_function(info)
		end

		e("\n")
	end
end

e([[type love.@MetaTable = {
    __newindex = function(_, key: ref any) 
        if not love[key] then
            type_error("bad!", 2) 
        end
    end
}]])
e("return love")
code = table.concat(code)
-- pixvis and "sensor is never defined on the wiki as a class
local f = io.open("examples/projects/love2d/game/love_api.nlua", "w")
f:write(code)
f:close()
nl.Compiler(code):Analyze()
