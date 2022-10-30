local nl = require("nattlua")
local in_node = {}
local found = {}

local function read_statement(node)
	local str = node:Render({preserve_whitespace = false})

	if str:find("StartNode") and node.kind ~= "root" then
		local local_name, type, kind = str:match("(%S-) = self:StartNode%(\"(.-)\", \"(.-)\"%)")

		if not local_name then
			local_name, type, kind = str:match("(%S-) = self:StartNode%(\"(.-)\", \"(.-)\",.-%)")
		end

		table.insert(
			in_node,
			1,
			{
				type = type,
				kind = kind,
				local_name = local_name,
				tokens = {},
				fields = {},
				node = tostring(node),
			}
		)
	end

	if in_node[1] and str:find(in_node[1].local_name .. ".", nil, true) then
		if str:find("tokens%[") then
			local name = str:match("tokens%[\"(.-)\"%]")

			if name then in_node[1].tokens[name] = true end
		else
			local field = str:match(in_node[1].local_name .. ".([a-z_]+)")

			if field then in_node[1].fields[field] = true end
		end
	end

	if str:find("EndNode", nil, true) then
		local data = table.remove(in_node, 1)

		if data then
			local existing = found[data.type .. "_" .. data.kind]

			if found[data.type .. "_" .. data.kind] then
				for k, v in pairs(data.tokens) do
					existing.tokens[k] = v
				end

				for k, v in pairs(data.fields) do
					existing.tokens[k] = v
				end
			else
				found[data.type .. "_" .. data.kind] = data
			end
		end
	end
end

local function crawl_statement(node)
	if node.kind == "function" then
		if
			(
				node.Code:GetName():find("parser/statements", nil, true) or
				node.Code:GetName():find("parser/expressions", nil, true) or
				node.Code:GetName():find("parser", nil, true)
			)
		then
			for _, node in ipairs(node.statements) do
				crawl_statement(node)
			end
		end
	elseif node.kind == "if" then
		for _, nodes in ipairs(node.statements) do
			for _, node in ipairs(nodes) do
				crawl_statement(node)
			end
		end
	elseif
		node.kind == "while" or
		node.kind == "repeat" or
		node.kind == "generic_for" or
		node.kind == "numeric_for" or
		node.kind == "do"
	then
		for _, node in ipairs(node.statements) do
			crawl_statement(node)
		end
	else
		read_statement(node)
	end
end

local compiler = assert(
	nl.File(
		"nattlua/parser.lua",
		{
			inline_require = true,
			preserve_whitespace = false,
			on_parsed_node = function(self, node)
				if node.type == "statement" then crawl_statement(node) end
			end,
		}
	):Parse()
)
local code = [[
    local type statement = {}
    local type expression = {}
]]

local function sorted_pairs(tbl)
	local keys = {}

	for k in pairs(tbl) do
		table.insert(keys, k)
	end

	table.sort(keys, function(a, b)
		return tostring(a) > tostring(b)
	end)

	local i = 0
	return function()
		i = i + 1
		return keys[i], tbl[keys[i]]
	end
end

for _, v in sorted_pairs(found) do
	code = code .. "type " .. v.type .. "[\"" .. v.kind .. "\"] = { -- " .. v.node .. "\n"
	code = code .. "tokens = {\n"

	for k, v in sorted_pairs(v.tokens) do
		code = code .. "[\"" .. k .. "\"] = Token,\n"
	end

	code = code .. "},\n"

	for k, v in sorted_pairs(v.fields) do
		code = code .. k .. " = any,\n"
	end

	code = code .. "}\n"
end

local res = nl.Compiler(code, "", {preserve_whitespace = false, comment_type_annotations = false}):Emit()
print(res, #res)