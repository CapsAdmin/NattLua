--ANALYZE
local table = _G.table
local type = _G.type
local ipairs = _G.ipairs
local table_insert = table.insert
local callstack = require("nattlua.other.callstack")
local error_messages = {}
--[[#local type Reason = string | {[number] = any | string}]]

function error_messages.because(msg--[[#: Reason]], reason--[[#: nil | Reason]])--[[#: Reason]]
	if type(msg) ~= "table" then msg = {msg} end

	if reason then
		if type(reason) ~= "table" then reason = {reason} end

		table_insert(msg, "because")
		table_insert(msg, reason)
	end

	return msg
end

function error_messages.context(context--[[#: Reason]], reason--[[#: Reason]])--[[#: Reason]]
	if type(context) ~= "table" then context = {context} end

	if type(reason) ~= "table" then
		reason = {context, reason}
	else
		reason = {context, reason[1], reason[2], reason[3], reason[4], reason[5], reason[6]}
	end

	return reason
end

do -- string pattern
	function error_messages.string_pattern_invalid_construction(a--[[#: any]])--[[#: Reason]]
		return error_messages.context(
			"string pattern must be a string literal, but",
			error_messages.subset(a, "literal string")
		)
	end

	function error_messages.string_pattern_match_fail(a--[[#: any]], b--[[#: any]])--[[#: Reason]]
		return {
			"cannot find",
			a,
			"in pattern \"",
			b:GetPatternContract(),
			"\"",
		}
	end

	function error_messages.string_pattern_type_mismatch(a--[[#: any]])--[[#: Reason]]
		return error_messages.context(
			{"to compare against a string pattern,", a, "must be a string literal, but"},
			error_messages.subset(a, "literal string")
		)
	end
end

do -- type errors
	-- proper subset is the same as <, while subset is the same as <=
	function error_messages.invalid_table_index(val--[[#: any]])--[[#: Reason]]
		return {"table index is", val}
	end
end

do -- modifier errors
	function error_messages.unique_type_type_mismatch(a--[[#: any]], b--[[#: any]])--[[#: Reason]]
		return {a, "is a unique type but", b, "is not"}
	end

	function error_messages.unique_type_mismatch(a--[[#: any]], b--[[#: any]])--[[#: Reason]]
		return {a, "is not the same unique type as", b}
	end

	function error_messages.unique_must_be_table(a--[[#: any]])--[[#: Reason]]
		return {a, "must be a table"}
	end

	function error_messages.not_literal(a--[[#: any]])--[[#: Reason]]
		return {a, "is not a literal"}
	end
end

do -- index errors
	function error_messages.undefined_set(self--[[#: any]], key--[[#: any]], val--[[#: any]], type_name--[[#: string]])--[[#: Reason]]
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

	function error_messages.undefined_get(self--[[#: any]], key--[[#: any]], type_name--[[#: string]])--[[#: Reason]]
		return {
			"undefined get:",
			self,
			"[",
			key,
			"] on type",
			type_name,
		}
	end

	function error_messages.table_index(a--[[#: any]], b--[[#: any]])--[[#: Reason]]
		return {a, "has no key", b}
	end

	function error_messages.key_missing_contract(key--[[#: any]], contract--[[#: any]])--[[#: Reason]]
		return {key, "is missing from", contract}
	end

	function error_messages.numerically_indexed(obj--[[#: any]])--[[#: Reason]]
		return {obj, "is not numerically indexed"}
	end

	function error_messages.missing_index(i--[[#: number]])--[[#: Reason]]
		return {"index", i, "does not exist"}
	end

	function error_messages.index_string_attempt()--[[#: Reason]]
		return {"attempt to index a string value"}
	end
end

do -- union errors
	function error_messages.union_key_empty()--[[#: Reason]]
		return {"union key is empty"}
	end

	function error_messages.empty_union()--[[#: Reason]]
		return {"union is empty"}
	end

	function error_messages.union_numbers_only(self--[[#: any]])--[[#: Reason]]
		return {"union must contain numbers only", self}
	end
end

do -- subset errors
	function error_messages.table_subset(a_key--[[#: any]], b_key--[[#: any]], a--[[#: any]], b--[[#: any]])--[[#: Reason]]
		return {"[", a_key, "]", a, "is not a subset of", "[", b_key, "]", b}
	end

	function error_messages.subset(a--[[#: any]], b--[[#: any]])--[[#: Reason]]
		return {a, "is not a subset of", b}
	end
end

do -- operator errors
	function error_messages.invalid_type_call(type_name--[[#: string]], obj--[[#: any]])--[[#: Reason]]
		return {
			"type",
			type_name,
			":",
			obj,
			"cannot be called",
		}
	end

	function error_messages.operation(op--[[#: any]], obj--[[#: any]], subject--[[#: string]])--[[#: Reason]]
		return {"cannot", op, subject}
	end

	function error_messages.binary(op--[[#: string]], l--[[#: any]], r--[[#: any]])--[[#: Reason]]
		return {
			l,
			op,
			r,
			"is not a valid binary operation",
		}
	end

	function error_messages.prefix(op--[[#: string]], l--[[#: any]])--[[#: Reason]]
		return {op, l, "is not a valid prefix operation"}
	end

	function error_messages.postfix(op--[[#: string]], r--[[#: any]])--[[#: Reason]]
		return {op, r, "is not a valid postfix operation"}
	end

	function error_messages.no_operator(op--[[#: string]], self--[[#: any]])--[[#: Reason]]
		return {"no operator", op, "on", self}
	end

	function error_messages.union_contains_non_callable(obj--[[#: any]], v--[[#: any]])--[[#: Reason]]
		return {"union", obj, "contains uncallable object", v}
	end

	function error_messages.number_overflow()--[[#: Reason]]
		return {"number overflow"}
	end

	function error_messages.number_underflow(l--[[#: any]], r--[[#: any]])--[[#: Reason]]
		return {"number underflow", l, r}
	end
end

function error_messages.mutating_function_argument(obj--[[#: any]], i--[[#: number]])--[[#: Reason]]
	return {
		"mutating function argument ",
		obj,
		" #" .. i,
		" without a contract",
	}
end

function error_messages.return_type_mismatch(
	function_node--[[#: any]],
	output_signature--[[#: any]],
	output--[[#: any]],
	reason--[[#: Reason]],
	i--[[#: number]]
)
	return error_messages.context(
		"expected return type " .. tostring(output_signature) .. ", but found " .. tostring(output) .. " at return #" .. i .. ":",
		reason
	)
end

function error_messages.global_assignment(key--[[#: any]], val--[[#: any]])--[[#: Reason]]
	return {"_G[", key, "] = ", val}
end

function error_messages.if_always_false()--[[#: Reason]]
	return {"if condition is always false"}
end

function error_messages.if_always_true()--[[#: Reason]]
	return {"if condition is always true"}
end

function error_messages.if_else_always_true()--[[#: Reason]]
	return {"else part of if condition is always true"}
end

function error_messages.destructure_assignment(type_name--[[#: string]])--[[#: Reason]]
	return {"expected a table on the right hand side, got", type_name}
end

function error_messages.destructure_assignment_missing(name--[[#: string]])--[[#: Reason]]
	return {"field", name, "does not exist"}
end

function error_messages.mutating_immutable_function_argument(obj--[[#: any]], i--[[#: number]])--[[#: Reason]]
	return {
		"mutating function argument",
		obj,
		"#" .. i,
		"with an immutable contract",
	}
end

function error_messages.loop_always_false()--[[#: Reason]]
	return {"loop expression is always false"}
end

function error_messages.loop_always_true()--[[#: Reason]]
	return {"loop expression is always true"}
end

function error_messages.too_many_iterations()--[[#: Reason]]
	return {"too many iterations"}
end

function error_messages.useless_while_loop()--[[#: Reason]]
	return {"while loop only executed once"}
end

function error_messages.too_many_arguments()--[[#: Reason]]
	return {"too many iterations"}
end

function error_messages.untyped_argument()--[[#: Reason]]
	return {"argument is untyped"}
end

function error_messages.argument_mutation(i--[[#: number]], arg--[[#: any]])--[[#: Reason]]
	return {
		"argument #" .. i,
		arg,
		"can be mutated by external call",
	}
end

function error_messages.argument_contract_mutation(obj--[[#: any]])--[[#: Reason]]
	return {
		"cannot mutate argument with contract ",
		obj,
	}
end

function error_messages.analyzer_timeout(count--[[#: number]], node--[[#: any]])--[[#: Reason]]
	return {node, " was crawled ", count, " times"}
end

function error_messages.const_assignment(key--[[#: any]])--[[#: Reason]]
	return {"cannot assign to const variable", key}
end

function error_messages.invalid_number(value--[[#: any]])--[[#: Reason]]
	return {"unable to convert", value, "to number"}
end

function error_messages.typeof_lookup_missing(type_name--[[#: string]])--[[#: Reason]]
	return {"cannot find '" .. type_name .. "' in the current typesystem scope"}
end

function error_messages.plain_error(msg--[[#: any]])--[[#: Reason]]
	return {msg}
end

function error_messages.analyzer_error(msg, trace)--[[#: Reason]]
	return {msg, " at ", trace or callstack.traceback()}
end

function error_messages.too_many_combinations(total--[[#: number]], max--[[#: number]])--[[#: Reason]]
	return {"too many argument combinations (" .. total .. " > " .. max .. ")"}
end

do
	function error_messages.analyzer_callstack_too_deep(len1, len2)
		return {
			"call stack is too deep. ",
			len1,
			" analyzer call frames and ",
			len2,
			" lua call stack frames ",
		}
	end

	function error_messages.too_many_mutations()
		return {"too many mutations"}
	end
end

return error_messages
