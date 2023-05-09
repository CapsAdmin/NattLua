local table = _G.table
local type = _G.type
local ipairs = _G.ipairs
local type_errors = {}
--[[#local type Reason = string | {[number] = any | string}]]

function type_errors.key_nil()
	return "key is nil"
end

function type_errors.key_nan()
	return "key is nan"
end

function type_errors.no_such_function_table(key--[[#: any]])
	return {"no such function on table: ", key}
end

function type_errors.union_key_empty()
	return "union key is empty"
end

function type_errors.key_not_literal(key--[[#: any]], reason--[[#: Reason]])
	return {"the key ", key, " is not a literal because ", reason}
end

function type_errors.value_not_literal(val--[[#: any]], reason--[[#: Reason]])
	return {"the value ", val, " is not a literal because ", reason}
end

function type_errors.empty_union()
	return "union is empty"
end

function type_errors.union_numbers_only(self--[[#: any]])
	return {"union must contain numbers only", self}
end

function type_errors.value_not_literal_because_union(val--[[#: any]])
	return {"the value ", val, " is not a literal because it's a union"}
end

function type_errors.key_subset(key--[[#: any]], val--[[#: any]], err--[[#: Reason]])
	return {
		"the key ",
		key,
		" is not a subset of ",
		val,
		" because ",
		err,
	}
end

function type_errors.missing_value_on_table(key--[[#: any]])
	return {"missing value on table ", key}
end

function type_errors.key_missing_contract(key--[[#: any]], contract--[[#: any]])
	return {key, " is missing from ", contract}
end

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

function type_errors.undefined_set(self--[[#: any]], key--[[#: any]], val--[[#: any]], type_name--[[#: string]])
	return {
		"undefined set: ",
		self,
		"[",
		key,
		"] = ",
		val,
		" on type ",
		type_name,
	}
end

function type_errors.undefined_get(self--[[#: any]], key--[[#: any]], type_name--[[#: type_name]])
	return {
		"undefined get: ",
		self,
		"[",
		key,
		"] on type ",
		type_name,
	}
end

function type_errors.no_operator(op--[[#: string]], self--[[#: any]])
	return {"no operator ", op, " on ", self}
end

function type_errors.unique_type(a--[[#: any]])--[[#: Reason]]
	return {a, "is a unique type"}
end

function type_errors.not_unique_type(a--[[#: any]], b--[[#: any]])--[[#: Reason]]
	return {a, "is not the same unique type as ", b}
end

function type_errors.must_evauluate_to_string()
	return "must evaluate to a string"
end

function type_errors.typeof_lookup_missing(type_name--[[#: string]])--[[#: Reason]]
	return {"cannot find '" .. node.right:Render() .. "' in the current typesystem scope"}
end

function type_errors.index_string_attempt()
	return "attempt to index a string value"
end

function type_errors.invalid_type_call(type_name--[[#: string]], obj--[[#: any]])--[[#: Reason]]
	return {
		"type ",
		type_name,
		": ",
		obj,
		" cannot be called",
	}
end

function type_errors.missing_call_metamethod()--[[#: Reason]]
	return "table has no __call metamethod"
end

function type_errors.expected_argument_got_nil(i--[[#: number]], contract--[[#: string]])--[[#: Reason]]
	return {
		"argument #",
		i,
		" expected ",
		contract,
		" got nil",
	}
end

function type_errors.missing_argument(i--[[#: number]], arg--[[#: any]], reason--[[#: Reason]])--[[#: Reason]]
	return {"argument #", i, " ", arg, ": ", reason}
end

function type_errors.missing_index(i--[[#: number]])--[[#: Reason]]
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

function type_errors.key_subset(keya--[[#: any]], keyb--[[#: any]], err--[[#: Reason]])
	return {
		"the key ",
		keya,
		" is not a subset of ",
		keyb,
		" because ",
		err,
	}
end

function type_errors.expected_max_number(a--[[#: a]])
	return {"max must be a number, got ", val}
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