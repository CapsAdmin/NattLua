--ANALYZE
local table = _G.table
local type = _G.type
local ipairs = _G.ipairs
local table_insert = table.insert
local debug_traceback = _G.debug.traceback
local type_errors = {}
--[[#local type Reason = string | {[number] = any | string}]]

function type_errors.because(msg--[[#: Reason]], reason--[[#: nil | Reason]])--[[#: Reason]]
	if type(msg) ~= "table" then msg = {msg} end

	if reason then
		if type(reason) ~= "table" then reason = {reason} end

		table_insert(msg, "because")
		table_insert(msg, reason)
	end

	return msg
end

function type_errors.context(context--[[#: Reason]], reason--[[#: Reason]])--[[#: Reason]]
	if type(context) ~= "table" then context = {context} end

	if type(reason) ~= "table" then
		reason = {context, reason}
	else
		reason = {context, table.unpack(reason)}
	end

	return reason
end

do -- string pattern
	function type_errors.string_pattern_invalid_construction(a--[[#: any]])--[[#: Reason]]
		return type_errors.context(
			"string pattern must be a string literal, but",
			type_errors.subset(a, "literal string")
		)
	end

	function type_errors.string_pattern_match_fail(a--[[#: any]], b--[[#: any]])--[[#: Reason]]
		return {
			"cannot find",
			a,
			"in pattern \"",
			b:GetPatternContract(),
			"\"",
		}
	end

	function type_errors.string_pattern_type_mismatch(a--[[#: any]])--[[#: Reason]]
		return type_errors.context(
			{"to compare against a string pattern,", a, "must be a string literal, but"},
			type_errors.subset(a, "literal string")
		)
	end
end

do -- type errors
	-- proper subset is the same as <, while subset is the same as <=
	function type_errors.invalid_table_index(val--[[#: any]])--[[#: Reason]]
		return {"table index is", val}
	end
end

do -- modifier errors
	function type_errors.unique_type_type_mismatch(a--[[#: any]], b--[[#: any]])--[[#: Reason]]
		return {a, "is a unique type but", b, "is not"}
	end

	function type_errors.unique_type_mismatch(a--[[#: any]], b--[[#: any]])--[[#: Reason]]
		return {a, "is not the same unique type as", b}
	end

	function type_errors.unique_must_be_table(a--[[#: any]])--[[#: Reason]]
		return {a, "must be a table"}
	end

	function type_errors.not_literal(a--[[#: any]])--[[#: Reason]]
		return {a, "is not a literal"}
	end
end

do -- index errors
	function type_errors.undefined_set(self--[[#: any]], key--[[#: any]], val--[[#: any]], type_name--[[#: string]])--[[#: Reason]]
		return {
			"undefined set:",
			self,
			"[",
			key,
			"] =",
			val,
			"on type",
			type_name,
		}
	end

	function type_errors.undefined_get(self--[[#: any]], key--[[#: any]], type_name--[[#: string]])--[[#: Reason]]
		return {
			"undefined get:",
			self,
			"[",
			key,
			"] on type",
			type_name,
		}
	end

	function type_errors.table_index(a--[[#: any]], b--[[#: any]])--[[#: Reason]]
		return {a, "has no key", b}
	end

	function type_errors.key_missing_contract(key--[[#: any]], contract--[[#: any]])--[[#: Reason]]
		return {key, "is missing from", contract}
	end

	function type_errors.numerically_indexed(obj--[[#: any]])--[[#: Reason]]
		return {obj, "is not numerically indexed"}
	end

	function type_errors.missing_index(i--[[#: number]])--[[#: Reason]]
		return {"index", i, "does not exist"}
	end

	function type_errors.index_string_attempt()--[[#: Reason]]
		return {"attempt to index a string value"}
	end
end

do -- union errors
	function type_errors.union_key_empty()--[[#: Reason]]
		return {"union key is empty"}
	end

	function type_errors.empty_union()--[[#: Reason]]
		return {"union is empty"}
	end

	function type_errors.union_numbers_only(self--[[#: any]])--[[#: Reason]]
		return {"union must contain numbers only", self}
	end
end

do -- subset errors
	function type_errors.table_subset(a_key--[[#: any]], b_key--[[#: any]], a--[[#: any]], b--[[#: any]])--[[#: Reason]]
		return {"[", a_key, "]", a, "is not a subset of", "[", b_key, "]", b}
	end

	function type_errors.subset(a--[[#: any]], b--[[#: any]])--[[#: Reason]]
		return {a, "is not a subset of", b}
	end
end

do -- operator errors
	function type_errors.invalid_type_call(type_name--[[#: string]], obj--[[#: any]])--[[#: Reason]]
		return {
			"type",
			type_name,
			":",
			obj,
			"cannot be called",
		}
	end

	function type_errors.operation(op--[[#: any]], obj--[[#: any]], subject--[[#: string]])--[[#: Reason]]
		return {"cannot", op, subject}
	end

	function type_errors.binary(op--[[#: string]], l--[[#: any]], r--[[#: any]])--[[#: Reason]]
		return {
			l,
			op,
			r,
			"is not a valid binary operation",
		}
	end

	function type_errors.prefix(op--[[#: string]], l--[[#: any]])--[[#: Reason]]
		return {op, l, "is not a valid prefix operation"}
	end

	function type_errors.postfix(op--[[#: string]], r--[[#: any]])--[[#: Reason]]
		return {op, r, "is not a valid postfix operation"}
	end

	function type_errors.no_operator(op--[[#: string]], self--[[#: any]])--[[#: Reason]]
		return {"no operator", op, "on", self}
	end

	function type_errors.union_contains_non_callable(obj--[[#: any]], v--[[#: any]])--[[#: Reason]]
		return {"union", obj, "contains uncallable object", v}
	end

	function type_errors.number_overflow()--[[#: Reason]]
		return {"number overflow"}
	end

	function type_errors.number_underflow(l--[[#: any]], r--[[#: any]])--[[#: Reason]]
		return {"number underflow", l, r}
	end
end

function type_errors.mutating_function_argument(obj--[[#: any]], i--[[#: number]])--[[#: Reason]]
	return {
		"mutating function argument ",
		obj,
		" #" .. i,
		" without a contract",
	}
end

function type_errors.return_type_mismatch(
	function_node--[[#: any]],
	output_signature--[[#: any]],
	output--[[#: any]],
	reason--[[#: Reason]],
	i--[[#: number]]
)
	return type_errors.context(
		"expected return type " .. tostring(output_signature) .. ", but found " .. tostring(output) .. " at return #" .. i .. ":",
		reason
	)
end

function type_errors.global_assignment(key--[[#: any]], val--[[#: any]])--[[#: Reason]]
	return {"_G[", key, "] = ", val}
end

function type_errors.if_always_false()--[[#: Reason]]
	return {"if condition is always false"}
end

function type_errors.if_always_true()--[[#: Reason]]
	return {"if condition is always true"}
end

function type_errors.if_else_always_true()--[[#: Reason]]
	return {"else part of if condition is always true"}
end

function type_errors.destructure_assignment(type_name--[[#: string]])--[[#: Reason]]
	return {"expected a table on the right hand side, got", type_name}
end

function type_errors.destructure_assignment_missing(name--[[#: string]])--[[#: Reason]]
	return {"field", name, "does not exist"}
end

function type_errors.mutating_immutable_function_argument(obj--[[#: any]], i--[[#: number]])--[[#: Reason]]
	return {
		"mutating function argument",
		obj,
		"#" .. i,
		"with an immutable contract",
	}
end

function type_errors.loop_always_false()--[[#: Reason]]
	return {"loop expression is always false"}
end

function type_errors.too_many_iterations()--[[#: Reason]]
	return {"too many iterations"}
end

function type_errors.useless_while_loop()--[[#: Reason]]
	return {"while loop only executed once"}
end

function type_errors.too_many_arguments()--[[#: Reason]]
	return {"too many iterations"}
end

function type_errors.untyped_argument()--[[#: Reason]]
	return {"argument is untyped"}
end

function type_errors.argument_mutation(i--[[#: number]], arg--[[#: any]])--[[#: Reason]]
	return {
		"argument #" .. i,
		arg,
		"can be mutated by external call",
	}
end

function type_errors.const_assignment(key--[[#: any]])--[[#: Reason]]
	return {"cannot assign to const variable", key}
end

function type_errors.invalid_number(value--[[#: any]])--[[#: Reason]]
	return {"unable to convert", value, "to number"}
end

function type_errors.typeof_lookup_missing(type_name--[[#: string]])--[[#: Reason]]
	return {"cannot find '" .. type_name .. "' in the current typesystem scope"}
end

function type_errors.plain_error(msg--[[#: any]])--[[#: Reason]]
	return {msg}
end

function type_errors.analyzer_error(msg, trace)--[[#: Reason]]
	return {msg, " at ", trace or debug_traceback()}
end

do
	function type_errors.analyzer_callstack_too_deep(len1, len2)
		return {
			"call stack is too deep. ",
			len1,
			" analyzer call frames and ",
			len2,
			" lua call stack frames ",
		}
	end

	function type_errors.too_many_mutations()
		return {"too many mutations"}
	end
end

return type_errors
