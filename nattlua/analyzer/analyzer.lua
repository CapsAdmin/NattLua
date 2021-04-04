local types = require("nattlua.types.types")
types.Initialize()
local META = {}
META.__index = META
META.OnInitialize = {}
require("nattlua.analyzer.base.base_analyzer")(META)
require("nattlua.analyzer.control_flow")(META)
require("nattlua.analyzer.operators.index")(META)
require("nattlua.analyzer.operators.newindex")(META)
require("nattlua.analyzer.operators.call")(META)
require("nattlua.analyzer.statements")(META)
require("nattlua.analyzer.expressions")(META)

function META:NewType(node, type, data, literal)
	local obj

	if type == "table" then
		obj = self:Assert(node, types.Table(data))
		obj.creation_scope = self:GetScope()
	elseif type == "list" then
		obj = self:Assert(node, types.List(data))
	elseif type == "..." then
		obj = self:Assert(node, types.Tuple(data or {types.Any()}))
		obj:SetRepeat(math.huge)
	elseif type == "number" then
		obj = self:Assert(node, types.Number(data):SetLiteral(literal))
	elseif type == "string" then
		obj = self:Assert(node, types.String(data):SetLiteral(literal))
	elseif type == "boolean" then
		if literal then
			obj = types.Symbol(data)
		else
			obj = types.Boolean()
		end
	elseif type == "nil" then
		obj = self:Assert(node, types.Symbol(nil))
	elseif type == "any" then
		obj = self:Assert(node, types.Any())
	elseif type == "function" then
		obj = self:Assert(node, types.Function(data))
		obj:SetNode(node)

		if node.statements then
			obj.function_body_node = node
		end
	end

	if not obj then
		error("NYI: " .. type)
	end

	obj:SetNode(obj:GetNode() or node)
	obj:GetNode().inferred_type = obj
	return obj
end

function META:ResolvePath(path)
	return path
end

function META:GetPreferTypesystem()
	return self.prefer_typesystem_stack and self.prefer_typesystem_stack[1]
end

function META:PushPreferTypesystem(b)
	self.prefer_typesystem_stack = self.prefer_typesystem_stack or {}
	table.insert(self.prefer_typesystem_stack, 1, b)
end

function META:PopPreferTypesystem()
	table.remove(self.prefer_typesystem_stack, 1)
end

do
	local guesses = {
			{pattern = "count", type = "number"},
        --{pattern = "tbl", type = "table", ctor = function(obj) obj:Set(types.Any(), types.Any()) end},
        {
				pattern = "str",
				type = "string",
			},
		}

	table.sort(guesses, function(a, b)
		return #a.pattern > #b.pattern
	end)

	function META:GuessTypeFromIdentifier(node, env)
		if node.value then
			local str = node.value.value:lower()

			for _, v in ipairs(guesses) do
				if str:find(v.pattern, nil, true) then
					local obj = self:NewType(node, v.type)

					if v.ctor then
						v.ctor(obj)
					end

					return obj
				end
			end
		end

		if env == "typesystem" then return self:NewType(node, "nil") -- TEST ME
        end
		return self:NewType(node, "any")
	end
end

return function(config)
	config = config or {}
	local self = setmetatable({config = config}, META)

	for _, func in ipairs(META.OnInitialize) do
		func(self)
	end

	return self
end
