local type_hash

local function number_hash(a)
	if not a.Data then return a.Type end

	if a.Max then
		return a.Type .. "-" .. tostring(a.Data) .. ".." .. tostring(a.Max)
	end

	return a.Type .. "-" .. tostring(a.Data)
end

local function tuple_hash(a, visited)
	visited = visited or {}

	if visited[a] then return "*circular*" end

	visited[a] = true
	local str = {a.Type .. "-"}

	for i = 1, #a.Data do
		str[i + 1] = type_hash(a.Data[i], visited)
	end

	return table.concat(str, ",")
end

local function string_equal(a, b)
	if a.Type ~= b.Type then return false, "types differ" end

	return a.Data == b.Data, "string values are equal"
end

local function any_hash(a)
	return a.Type
end

local function union_hash(a, visited)
	visited = visited or {}

	if visited[a] then return "*circular*" end

	visited[a] = true
	local str = {a.Type .. "-"}

	for i = 1, #a.Data do
		str[i + 1] = type_hash(a.Data[i], visited)
	end

	return table.concat(str, ",")
end

local function function_hash(a, visited)
	visited = visited or {}
	local input_hash = type_hash(a:GetInputSignature(), visited)
	local output_hash = type_hash(a:GetOutputSignature(), visited)
	return a.Type .. "-" .. input_hash .. "->" .. output_hash
end

local function symbol_hash(a)
	if not a.Data then return a.Type end

	return a.Type .. "-" .. tostring(a.Data)
end

local function table_hash(a, visited)
	visited = visited or {}

	if visited[a] then return "*circular*" end

	if a:IsUnique() then
		return a.Type .. "-unique-" .. tostring(a:GetUniqueID())
	end

	if a:GetContract() and a:GetContract().Name then
		return a.Type .. "-contract-" .. a:GetContract().Name:GetData()
	end

	if a.Name then return a.Type .. "-named-" .. a.Name:GetData() end

	visited[a] = true
	local adata = a:GetData()
	local str = {a.Type .. "-"}

	for i = 1, #adata do
		local kv = adata[i]
		str[i + 1] = type_hash(kv.key, visited) .. ":" .. type_hash(kv.val, visited)
	end

	return table.concat(str, ",")
end

function type_hash(a, visited)
	if a.Type == "number" then
		return number_hash(a)
	elseif a.Type == "any" then
		return any_hash(a)
	elseif a.Type == "string" then
		return string_hash(a)
	elseif a.Type == "tuple" then
		return tuple_hash(a, visited)
	elseif a.Type == "union" then
		return union_hash(a, visited)
	elseif a.Type == "function" then
		return function_hash(a, visited)
	elseif a.Type == "symbol" then
		return symbol_hash(a)
	elseif a.Type == "table" then
		return table_hash(a, visited)
	end

	error("NYI hash for type " .. a.Type)
end

return type_hash
