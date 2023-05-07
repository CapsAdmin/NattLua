local table = _G.table
local type = _G.type
local ipairs = _G.ipairs
local type_errors = {}
--[[#local type Reason = string | {[number] = any | string}]]

function type_errors.subset(a--[[#: any]], b--[[#: any]], reason--[[#: Reason | nil]])--[[#: Reason]]
	local msg = {a, " is not a subset of ", b}

	if reason then
		table.insert(msg, " because ")

		if type(reason) == "table" then
			for i, v in ipairs(reason) do
				table.insert(msg, v)
			end
		else
			table.insert(msg, reason)
		end
	end

	return msg
end

function type_errors.missing_argument(i--[[#: number]], arg--[[#: any]], reason--[[#: Reason]])
	return {"argument #", i, " ", arg, ": ", reason}
end

function type_errors.missing_index(i--[[#: number]])
	return {"index ", i, " does not exist"}
end

function type_errors.table_subset(
	a_key--[[#: any]],
	b_key--[[#: any]],
	a--[[#: any]],
	b--[[#: any]],
	reason--[[#: Reason]]
)--[[#: Reason]]
	local msg = {"[", a_key, "]", a, " is not a subset of ", "[", b_key, "]", b}

	if reason then
		table.insert(msg, " because ")

		if type(reason) == "table" then
			for i, v in ipairs(reason) do
				table.insert(msg, v)
			end
		else
			table.insert(msg, reason)
		end
	end

	return msg
end

function type_errors.missing(a--[[#: any]], b--[[#: any]], reason--[[#: Reason]])--[[#: Reason]]
	local msg = {a, " has no field ", b, " because ", reason}
	return msg
end

function type_errors.other(msg--[[#: Reason]])--[[#: Reason]]
	return msg
end

function type_errors.type_mismatch(a--[[#: any]], b--[[#: any]])--[[#: Reason]]
	return {a, " is not the same type as ", b}
end

function type_errors.value_mismatch(a--[[#: any]], b--[[#: any]])--[[#: Reason]]
	return {a, " is not the same value as ", b}
end

function type_errors.operation(op--[[#: any]], obj--[[#: any]], subject--[[#: string]])--[[#: Reason]]
	return {"cannot ", op, " ", subject}
end

function type_errors.numerically_indexed(obj--[[#: any]])--[[#: Reason]]
	return {obj, " is not numerically indexed"}
end

function type_errors.binary(op--[[#: string]], l--[[#: any]], r--[[#: any]])--[[#: Reason]]
	return {
		l,
		" ",
		op,
		" ",
		r,
		" is not a valid binary operation",
	}
end

function type_errors.prefix(op--[[#: string]], l--[[#: any]])--[[#: Reason]]
	return {op, " ", l, " is not a valid prefix operation"}
end

function type_errors.postfix(op--[[#: string]], r--[[#: any]])--[[#: Reason]]
	return {op, " ", r, " is not a valid postfix operation"}
end

function type_errors.literal(obj--[[#: any]], reason--[[#: Reason | nil]])--[[#: Reason]]
	local msg = {obj, " needs to be a literal"}

	if reason then
		table.insert(msg, " because ")
		table.insert(msg, reason)
	end

	return msg
end

function type_errors.string_pattern(a--[[#: any]], b--[[#: any]])--[[#: Reason]]
	return {
		"cannot find ",
		a,
		" in pattern \"",
		b:GetPatternContract(),
		"\"",
	}
end

return type_errors