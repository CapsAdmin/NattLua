local Union = require("nattlua.types.union").Union
local shared = require("nattlua.types.shared")
local LNumberRange = require("nattlua.types.range").LNumberRange
local math_huge = math.huge
--[[
    Constraint Store for NattLua analyzer
    
    Tracks relationships between upvalues and propagates narrowing:
    - Equality(a, b): when a narrows, b narrows to intersection
    - Inequality(a, b): tracked but not actively propagated (used for query)
    - Arithmetic(result, op, left, right): recomputes when operands narrow
]]
local META = {}
META.__index = META

function META.new()
	local store = {
		domains = {}, -- upvalue -> current Union
		constraints = {}, -- list of all constraints
		dependents = {}, -- upvalue -> list of constraints involving it
		scope_stack = {}, -- snapshots for push/pop
		constraint_id = 0,
		equivalence = {}, -- upvalue -> set of equivalent upvalues (transitive closure)
		equiv_groups = {}, -- Union -> equiv group id (for intermediate results)
		source_values = {}, -- Union -> {result_value = original_value, ...}
		next_equiv_id = 0,
	}
	return setmetatable(store, META)
end

-- Register a domain for an upvalue
function META:RegisterDomain(upvalue, domain)
	self.domains[upvalue] = domain
end

-- Get current domain for an upvalue
function META:GetDomain(upvalue)
	return self.domains[upvalue]
end

-- Apply pending equality narrowing for all equivalence classes
-- Called when entering a truthy branch after equality comparisons
-- Mutates upvalues directly (analyzer is used for scope-aware mutation)
function META:ApplyEqualityNarrowing(analyzer)
	local narrowed = {}
	-- For each equivalence class with > 1 member, narrow all to intersection
	local processed = {}

	for upvalue, class in pairs(self.equivalence) do
		if processed[class] then continue end

		processed[class] = true
		-- Collect all upvalue members in this class (skip literals)
		local members = {}
		local domains = {}

		for member in pairs(class) do
			-- Read current domain from upvalue, not constraint store
			if member.Type ~= "upvalue" then continue end

			local domain = member:GetValue() or self.domains[member]

			if domain then
				table.insert(members, member)
				table.insert(domains, domain)
			end
		end

		if #members <= 1 then continue end

		-- Compute intersection of all domains
		local intersection = nil

		for _, d in ipairs(domains) do
			-- Get iterable elements: unions have GetData() returning a table,
			-- non-unions (ranges, generic number) are treated as single elements
			local d_elems = d.Type == "union" and d:GetData() or {d}

			if not intersection then
				intersection = Union()

				for _, elem in ipairs(d_elems) do
					intersection:AddType(elem)
				end
			else
				local new_intersection = Union()
				local int_data = intersection:GetData()

				for _, elem in ipairs(int_data) do
					for _, elem2 in ipairs(d_elems) do
						if shared.Equal(elem, elem2) then
							new_intersection:AddType(elem)

							break
						end
					end
				end

				intersection = new_intersection
			end
		end

		-- Narrow all members to intersection
		if intersection then
			for _, member in ipairs(members) do
				self.domains[member] = intersection
				narrowed[member] = intersection
			end
		end
	end

	-- Also check equality constraints where one side is a literal
	for _, c in pairs(self.constraints) do
		if c.type ~= "equality" then continue end

		local a_is_upvalue = c.a and c.a.Type == "upvalue"
		local b_is_upvalue = c.b and c.b.Type == "upvalue"

		if a_is_upvalue and not b_is_upvalue then
			if c.op == "==" then
				-- Narrow a to match b (literal)
				narrowed[c.a] = c.b
				self.domains[c.a] = c.b
			else
				-- ~= : remove literal from a's domain
				local current = self:GetEffectiveDomain(c.a)

				if current then
					local complement = self:RemoveTypesFromDomain(current, {c.b})

					if complement then
						narrowed[c.a] = complement
						self.domains[c.a] = complement
					end
				end
			end
		elseif b_is_upvalue and not a_is_upvalue then
			if c.op == "==" then
				-- Narrow b to match a (literal)
				narrowed[c.b] = c.a
				self.domains[c.b] = c.a
			else
				-- ~= : remove literal from b's domain
				local current = self:GetEffectiveDomain(c.b)

				if current then
					local complement = self:RemoveTypesFromDomain(current, {c.a})

					if complement then
						narrowed[c.b] = complement
						self.domains[c.b] = complement
					end
				end
			end
		end
	end

	-- Mutate upvalues with narrowed domains so the changes are visible
	for upvalue, new_domain in pairs(narrowed) do
		if upvalue.Mutate and analyzer then
			local scope = analyzer:GetScope()

			if scope then
				if new_domain and new_domain.SetUpvalue then new_domain:SetUpvalue(upvalue) end

				upvalue:Mutate(new_domain, scope)
			end
		end
	end

	return narrowed
end

-- Apply pending relational narrowing for all relational constraints
-- Called when entering a truthy branch after relational comparisons
-- Returns a table of {upvalue = narrowed_domain} pairs for the caller to apply
function META:ApplyRelationalNarrowing(analyzer)
	local narrowed = {}

	-- For each relational constraint, narrow both domains
	for _, c in pairs(self.constraints) do
		if c.type ~= "relational" then continue end

		local domain_a = self:GetEffectiveDomain(c.a)
		-- For literals (not upvalues), use the value directly
		local domain_b = c.b.Type == "upvalue" and self:GetEffectiveDomain(c.b) or c.b
		-- Handle case where one side is a literal (not an upvalue with a domain)
		-- e.g., x < 4: c.a is upvalue, c.b is LNumber(4)
		local a_is_upvalue = c.a and c.a.Type == "upvalue"
		local b_is_upvalue = c.b and c.b.Type == "upvalue"

		-- If one side is a literal, narrow the other side directly
		if a_is_upvalue and not b_is_upvalue and domain_a then
			-- Narrow domain_a based on literal c.b
			local new_a, empty_a = META:NarrowDomainByLiteral(domain_a, c.b, c.op)

			if new_a then
				self.domains[c.a] = new_a
				narrowed[c.a] = new_a

				if c.a.Mutate and analyzer then
					local scope = analyzer:GetScope()

					if scope then
						new_a:SetUpvalue(c.a)
						c.a:Mutate(new_a, scope)
					end
				end
			elseif empty_a then
				-- Domain became empty
				self.domains[c.a] = nil
				narrowed[c.a] = nil
			end

			continue
		end

		if b_is_upvalue and not a_is_upvalue and domain_b then
			-- Narrow domain_b based on literal c.a (invert operator)
			local inv_op = META:InvertRelationalOp(c.op)
			local new_b, empty_b = META:NarrowDomainByLiteral(domain_b, c.a, inv_op)

			if new_b then
				self.domains[c.b] = new_b
				narrowed[c.b] = new_b

				if c.b.Mutate and analyzer then
					local scope = analyzer:GetScope()

					if scope then
						new_b:SetUpvalue(c.b)
						c.b:Mutate(new_b, scope)
					end
				end
			elseif empty_b then
				-- Domain became empty
				self.domains[c.b] = nil
				narrowed[c.b] = nil
			end

			continue
		end

		-- Both sides are upvalues with domains
		if not domain_a or not domain_b then continue end

		local new_a, new_b = self:NarrowByRelational(domain_a, domain_b, c.op)

		if new_a then
			self.domains[c.a] = new_a
			narrowed[c.a] = new_a

			-- Also mutate the actual upvalue so the narrowed value is visible
			if c.a.Mutate and analyzer then
				local scope = analyzer:GetScope()

				if scope then
					new_a:SetUpvalue(c.a)
					c.a:Mutate(new_a, scope)
				end
			end
		end

		if new_b then
			self.domains[c.b] = new_b
			narrowed[c.b] = new_b

			-- Also mutate the actual upvalue
			if c.b.Mutate and analyzer then
				local scope = analyzer:GetScope()

				if scope then
					new_b:SetUpvalue(c.b)
					c.b:Mutate(new_b, scope)
				end
			end
		end
	end

	return narrowed
end

-- Apply relational narrowing for the else/falsy branch
-- Negates the relational constraints to compute the complement domain
function META:ApplyRelationalNarrowingElse(analyzer)
	local narrowed = {}
	-- Collect all relational constraints per upvalue
	local upvalue_constraints = {}

	for _, c in pairs(self.constraints) do
		if c.type ~= "relational" then continue end

		local a_is_upvalue = c.a and c.a.Type == "upvalue"
		local b_is_upvalue = c.b and c.b.Type == "upvalue"

		if a_is_upvalue and not b_is_upvalue then
			if not upvalue_constraints[c.a] then upvalue_constraints[c.a] = {} end

			table.insert(upvalue_constraints[c.a], {op = META:NegateRelationalOp(c.op), literal = c.b})
		elseif b_is_upvalue and not a_is_upvalue then
			if not upvalue_constraints[c.b] then upvalue_constraints[c.b] = {} end

			table.insert(upvalue_constraints[c.b], {op = META:NegateRelationalOp(c.op), literal = c.a})
		end
	end

	-- For each upvalue with relational constraints, narrow using negated constraints
	for upvalue, constraints in pairs(upvalue_constraints) do
		local current_domain = self:GetEffectiveDomain(upvalue)

		if not current_domain then continue end

		-- Narrow the current domain using each negated constraint
		local narrowed_domain = current_domain

		for _, conc in ipairs(constraints) do
			local new_domain, empty = META:NarrowDomainByLiteral(narrowed_domain, conc.literal, conc.op)

			if empty then
				-- Domain became empty: negated constraints are contradictory.
				-- This means the original domain was fully contained in the truthy branch.
				-- Compute the complement: narrow with original (truthy) constraints, then take complement.
				narrowed_domain = nil

				break
			elseif new_domain then
				narrowed_domain = new_domain
			end
		-- else: no change, keep current narrowed_domain
		end

		if narrowed_domain then
			self.domains[upvalue] = narrowed_domain
			narrowed[upvalue] = narrowed_domain

			if upvalue.Mutate and analyzer then
				local scope = analyzer:GetScope()

				if scope then
					narrowed_domain:SetUpvalue(upvalue)
					upvalue:Mutate(narrowed_domain, scope)
				end
			end
		else
			-- Negated constraints produced empty domain.
			-- Compute complement of the truthy-narrowed domain.
			-- First, narrow current_domain with original (non-negated) constraints
			local truthy_domain = current_domain

			for _, c in pairs(self.constraints) do
				if c.type ~= "relational" then continue end

				local a_is_uv = c.a and c.a == upvalue
				local b_is_uv = c.b and c.b == upvalue

				if a_is_uv then
					local nd, em = META:NarrowDomainByLiteral(truthy_domain, c.b, c.op)

					if em then
						truthy_domain = nil

						break
					end

					if nd then truthy_domain = nd end
				elseif b_is_uv then
					local inv_op = META:InvertRelationalOp(c.op)
					local nd, em = META:NarrowDomainByLiteral(truthy_domain, c.a, inv_op)

					if em then
						truthy_domain = nil

						break
					end

					if nd then truthy_domain = nd end
				end
			end

			if truthy_domain then
				-- Compute complement of truthy_domain within current_domain
				local complement = Union()
				-- Handle number type as infinite range
				local c_min, c_max

				if current_domain.Type == "range" then
					c_min, c_max = current_domain:GetMin(), current_domain:GetMax()
				elseif current_domain.Type == "number" then
					c_min, c_max = -math_huge, math_huge
				else
					c_min, c_max = -math_huge, math_huge
				end

				if truthy_domain.Type == "range" then
					local t_min, t_max = truthy_domain:GetMin(), truthy_domain:GetMax()

					-- Left part: c_min .. (t_min - 1)
					if c_min <= t_min - 1 then
						complement:AddType(LNumberRange(c_min, t_min - 1))
					end

					-- Right part: (t_max + 1) .. c_max
					if t_max + 1 <= c_max then
						complement:AddType(LNumberRange(t_max + 1, c_max))
					end
				end

				if complement:GetCardinality() > 0 then
					self.domains[upvalue] = complement
					narrowed[upvalue] = complement

					if upvalue.Mutate and analyzer then
						local scope = analyzer:GetScope()

						if scope then
							complement:SetUpvalue(upvalue)
							upvalue:Mutate(complement, scope)
						end
					end
				end
			end
		end
	end

	return narrowed
end

-- Add an equality constraint between two upvalues
-- op: optional operator string ("==" or "~=", "!=") to track original comparison
function META:AddEquality(a, b, op)
	local id = self:next_id()
	local constraint = {
		id = id,
		type = "equality",
		a = a,
		b = b,
		op = op or "==",
	}
	self.constraints[id] = constraint
	self:add_dependent(a, id)
	self:add_dependent(b, id)

	-- Auto-register domains from upvalue values
	if a and a.Type == "upvalue" and not self.domains[a] then
		local val = a:GetValue()

		if val then self.domains[a] = val end
	end

	if b and b.Type == "upvalue" and not self.domains[b] then
		local val = b:GetValue()

		if val then self.domains[b] = val end
	end

	-- Update equivalence classes (transitive closure)
	self:union_equivalence(a, b)
	return id
end

-- Union two equivalence classes
function META:union_equivalence(a, b)
	local class_a = self:equiv_class(a)
	local class_b = self:equiv_class(b)

	-- Merge smaller into larger
	if class_a ~= class_b then
		for upvalue in pairs(class_b) do
			class_a[upvalue] = true
			self.equivalence[upvalue] = class_a
		end
	end
end

-- Get equivalence class for an upvalue
function META:equiv_class(upvalue)
	if not self.equivalence[upvalue] then
		self.equivalence[upvalue] = {[upvalue] = true}
	end

	return self.equivalence[upvalue]
end

-- Tag a Union with an equivalence group id
function META:TagEquivalence(union, upvalue)
	local group_id = self:GetEquivalenceGroupId(upvalue)

	if group_id then self.equiv_groups[union] = group_id end
end

-- Get equivalence group id for an upvalue
function META:GetEquivalenceGroupId(upvalue)
	local class = self:equiv_class(upvalue)
	-- Use the class table itself as the id
	return class
end

-- Get equivalence group id from a tagged Union
function META:GetEquivalenceGroupIdFromUnion(union)
	return self.equiv_groups[union]
end

-- Tag a result union with source value mapping
-- result_union: the Union containing computed results
-- source_map: {result_value = original_value, ...}
function META:TagSourceValues(result_union, source_map)
	self.source_values[result_union] = source_map
end

-- Get source value mapping for a union
function META:GetSourceValues(union)
	return self.source_values[union]
end

-- Get the original value that produced a specific result value
function META:GetOriginalValue(union, result_value)
	local source_map = self.source_values[union]

	if not source_map then return nil end

	-- Look up by result value
	for res, orig in pairs(source_map) do
		if shared.Equal(res, result_value) then return orig end
	end

	-- Fallback: try numeric comparison
	for res, orig in pairs(source_map) do
		if res == result_value then return orig end
	end

	return nil
end

-- Add an inequality constraint between two upvalues
function META:AddInequality(a, b)
	local id = self:next_id()
	local constraint = {
		id = id,
		type = "inequality",
		a = a,
		b = b,
	}
	self.constraints[id] = constraint
	self:add_dependent(a, id)
	self:add_dependent(b, id)
	return id
end

-- Add a relational constraint between two upvalues
-- op: "<", ">", "<=", ">="
function META:AddRelational(a, b, op)
	local id = self:next_id()
	local constraint = {
		id = id,
		type = "relational",
		op = op,
		a = a,
		b = b,
	}
	self.constraints[id] = constraint
	self:add_dependent(a, id)
	self:add_dependent(b, id)

	-- Auto-register domains from upvalue values
	if a and a.Type == "upvalue" and not self.domains[a] then
		local val = a:GetValue()

		if val then self.domains[a] = val end
	end

	if b and b.Type == "upvalue" and not self.domains[b] then
		local val = b:GetValue()

		if val then self.domains[b] = val end
	end

	return id
end

-- Narrow a domain based on a relational constraint
-- Given: domain_a, domain_b, op (e.g., "<")
-- Returns: narrowed domain_a, narrowed domain_b (or nil if no change)
-- Handles: union-vs-union, range-vs-range, union-vs-range, range-vs-union, number-vs-anything
-- Note: "number" type is treated like an infinite range (-inf..inf)
-- Note: LNumber literals (Type=="number" but IsLiteral) are NOT treated as ranges
function META:NarrowByRelational(domain_a, domain_b, op)
	if not domain_a or not domain_b then return nil, nil end

	-- Treat "number" type like range (infinite bounds), but not LNumber literals
	local a_is_literal = domain_a.IsLiteral and domain_a:IsLiteral()
	local b_is_literal = domain_b.IsLiteral and domain_b:IsLiteral()
	local a_is_range = domain_a:IsNumeric() and not a_is_literal
	local b_is_range = domain_b:IsNumeric() and not b_is_literal
	local a_is_union = domain_a.Type == "union"
	local b_is_union = domain_b.Type == "union"

	if a_is_range and b_is_range then
		return META:NarrowRangeByRelational(domain_a, domain_b, op)
	elseif a_is_union and b_is_union then
		return META:NarrowUnionByRelational(domain_a, domain_b, op)
	elseif a_is_union and b_is_range then
		return META:NarrowUnionRangeByRelational(domain_a, domain_b, op)
	elseif a_is_range and b_is_union then
		-- Swap and invert operator for range-vs-union
		local inv_op = META:InvertRelationalOp(op)
		local new_b, new_a = META:NarrowUnionRangeByRelational(domain_b, domain_a, inv_op)
		return new_a, new_b
	end

	return nil, nil
end

-- Invert a relational operator (swap sides)
function META:InvertRelationalOp(op)
	if op == "<" then
		return ">"
	elseif op == ">" then
		return "<"
	elseif op == "<=" then
		return ">="
	elseif op == ">=" then
		return "<="
	end

	return op
end

-- Negate a relational operator (for else-branch narrowing)
-- not (a > b) => a <= b, not (a < b) => a >= b, etc.
function META:NegateRelationalOp(op)
	if op == "<" then
		return ">="
	elseif op == ">" then
		return "<="
	elseif op == "<=" then
		return ">"
	elseif op == ">=" then
		return "<"
	end

	return op
end

-- Extract numeric value from a type (LNumber or Union wrapping a single literal)
-- Ranges return nil as they can't represent a single number.
-- Callers always pass NattLua type objects, never raw Lua numbers.
local function extract_numeric(val)
	if not val then return nil end

	if val.Type == "number" and val.GetData then
		local d = val:GetData()
		return type(d) == "number" and d or nil
	end

	if val.Type == "union" then
		-- If it's a union with a single numeric element, extract it
		local data = val:GetData()

		if #data == 1 then
			local elem = data[1]

			if elem.Type == "number" and elem.GetData then
				local d = elem:GetData()
				return type(d) == "number" and d or nil
			end
		end

		return nil
	end

	return nil
end

-- Check if a < b relation holds
local function rel_holds(a_val, b_val, op)
	if op == "<" then
		return a_val < b_val
	elseif op == ">" then
		return a_val > b_val
	elseif op == "<=" then
		return a_val <= b_val
	elseif op == ">=" then
		return a_val >= b_val
	end

	return false
end

-- Narrow a domain (union or range) against a literal numeric value
-- Returns narrowed domain or nil if no change
function META:NarrowDomainByLiteral(domain, literal_val, op)
	local lit_num = extract_numeric(literal_val)

	if not lit_num then return nil end

	if domain.Type == "union" then
		local data = domain:GetData()
		local new_union = Union()
		local changed = false

		for _, elem in ipairs(data) do
			local elem_num = extract_numeric(elem)

			if not elem_num then
				-- elem is a range, generic number, or other non-literal
				-- try to narrow it recursively
				local narrowed, empty = META:NarrowDomainByLiteral(elem, literal_val, op)

				if empty then
					-- Empty result, drop the element
					changed = true
				elseif narrowed then
					new_union:AddType(narrowed)
					changed = true
				else
					-- No change, keep original
					new_union:AddType(elem)
				end

				continue
			end

			if rel_holds(elem_num, lit_num, op) then new_union:AddType(elem) end
		end

		if changed or new_union:GetCardinality() < (#data) then return new_union end
	elseif domain.Type == "range" then
		local min, max = domain:GetMin(), domain:GetMax()
		local new_min, new_max = min, max

		if op == "<" then
			new_max = math.min(max, lit_num - 1)
		elseif op == ">" then
			new_min = math.max(min, lit_num + 1)
		elseif op == "<=" then
			new_max = math.min(max, lit_num)
		elseif op == ">=" then
			new_min = math.max(min, lit_num)
		end

		if new_min ~= min or new_max ~= max then
			if new_min <= new_max then return LNumberRange(new_min, new_max), false end

			-- Empty range
			return nil, true
		-- return nil, false would mean no change
		end

		-- No change
		return nil, false
	elseif domain.Type == "number" then
		-- "number" type represents all numbers; narrow to a range
		local new_min, new_max

		if op == "<" then
			new_min, new_max = -math_huge, lit_num - 1
		elseif op == ">" then
			new_min, new_max = lit_num + 1, math_huge
		elseif op == "<=" then
			new_min, new_max = -math_huge, lit_num
		elseif op == ">=" then
			new_min, new_max = lit_num, math_huge
		end

		if new_min and new_min <= new_max then
			return LNumberRange(new_min, new_max), false
		end

		-- Should not reach here for valid ops, but just in case
		return nil, false
	end

	return nil
end

-- Narrow two ranges based on a relational constraint
-- Also handles "number" type (treated as -inf..inf)
function META:NarrowRangeByRelational(range_a, range_b, op)
	-- Handle "number" type as infinite range
	local a_min, a_max

	if range_a.Type == "number" then
		a_min, a_max = -math_huge, math_huge
	else
		a_min, a_max = range_a:GetMin(), range_a:GetMax()
	end

	local b_min, b_max

	if range_b.Type == "number" then
		b_min, b_max = -math_huge, math_huge
	else
		b_min, b_max = range_b:GetMin(), range_b:GetMax()
	end

	-- Handle infinity: use per-bound checks to avoid narrowing with infinite bounds
	local a_min_finite = a_min ~= -math_huge
	local a_max_finite = a_max ~= math_huge
	local b_min_finite = b_min ~= -math_huge
	local b_max_finite = b_max ~= math_huge
	local new_a_min, new_a_max, new_b_min, new_b_max

	if op == "<" then
		-- a < b: a's max can't exceed b's min - 1, b's min can't go below a's min + 1
		new_a_min = a_min
		new_a_max = b_min_finite and math.min(a_max, b_min - 1) or a_max
		new_b_min = a_min_finite and math.max(b_min, a_min + 1) or b_min
		new_b_max = b_max
	elseif op == ">" then
		-- a > b: a's min must be at least b's max + 1, b's max can't exceed a's max - 1
		new_a_min = b_max_finite and math.max(a_min, b_max + 1) or a_min
		new_a_max = a_max
		new_b_min = b_min
		new_b_max = a_max_finite and math.min(b_max, a_max - 1) or b_max
	elseif op == "<=" then
		-- a <= b: a's max can't exceed b's max, b's min can't go below a's min
		new_a_min = a_min
		new_a_max = b_max_finite and math.min(a_max, b_max) or a_max
		new_b_min = a_min_finite and math.max(b_min, a_min) or b_min
		new_b_max = b_max
	elseif op == ">=" then
		-- a >= b: a's min must be at least b's min, b's max can't exceed a's max
		new_a_min = b_min_finite and math.max(a_min, b_min) or a_min
		new_a_max = a_max
		new_b_min = b_min
		new_b_max = a_max_finite and math.min(b_max, a_max) or b_max
	else
		return nil, nil
	end

	-- Validate ranges (min <= max)
	local a_changed = (new_a_min ~= a_min or new_a_max ~= a_max) and new_a_min <= new_a_max
	local b_changed = (new_b_min ~= b_min or new_b_max ~= b_max) and new_b_min <= new_b_max

	if not a_changed and not b_changed then return nil, nil end

	local new_a = a_changed and LNumberRange(new_a_min, new_a_max) or nil
	local new_b = b_changed and LNumberRange(new_b_min, new_b_max) or nil
	return new_a, new_b
end

-- Helper to extract numeric value from a type element
local function get_num(val)
	if val.Type == "number" and val:IsLiteral() then return val:GetData() end

	return nil
end

-- Narrow two unions based on a relational constraint (extracted from original NarrowByRelational)
function META:NarrowUnionByRelational(domain_a, domain_b, op)
	local a_data = domain_a:GetData()
	local b_data = domain_b:GetData()
	-- Filter domain_a: keep only values where a op b holds for at least one b
	local new_a = Union()

	for _, a_elem in ipairs(a_data) do
		local a_val = get_num(a_elem)

		if not a_val then
			new_a:AddType(a_elem)

			continue
		end

		for _, b_elem in ipairs(b_data) do
			local b_val = get_num(b_elem)

			if not b_val then continue end

			if rel_holds(a_val, b_val, op) then
				new_a:AddType(a_elem)

				continue
			end
		end
	end

	-- Filter domain_b: keep only values where a op b holds for at least one a
	local new_b = Union()

	for _, b_elem in ipairs(b_data) do
		local b_val = get_num(b_elem)

		if not b_val then
			new_b:AddType(b_elem)

			continue
		end

		for _, a_elem in ipairs(a_data) do
			local a_val = get_num(a_elem)

			if not a_val then continue end

			if rel_holds(a_val, b_val, op) then
				new_b:AddType(b_elem)

				continue
			end
		end
	end

	local a_changed = new_a:GetCardinality() < (#a_data)
	local b_changed = new_b:GetCardinality() < (#b_data)

	if not a_changed and not b_changed then return nil, nil end

	return (a_changed and new_a or nil), (b_changed and new_b or nil)
end

-- Narrow union_a vs range_b based on relational constraint
function META:NarrowUnionRangeByRelational(union_a, range_b, op)
	local a_data = union_a:GetData()
	local b_min, b_max

	if range_b.Type == "number" then
		b_min, b_max = -math_huge, math_huge
	else
		b_min, b_max = range_b:GetMin(), range_b:GetMax()
	end

	-- Filter union_a: keep elements where elem op some_value_in_range holds
	local new_a = Union()
	local min_matching, max_matching = nil, nil

	for _, a_elem in ipairs(a_data) do
		local a_val = get_num(a_elem)

		if not a_val then
			new_a:AddType(a_elem)

			continue
		end

		-- Check if a_val op [b_min..b_max] can hold
		local can_hold = false

		if op == "<" then
			can_hold = a_val < b_max
		elseif op == ">" then
			can_hold = a_val > b_min
		elseif op == "<=" then
			can_hold = a_val <= b_max
		elseif op == ">=" then
			can_hold = a_val >= b_min
		end

		if can_hold then
			new_a:AddType(a_elem)

			-- Track matching extremes for range narrowing
			if min_matching == nil or a_val < min_matching then min_matching = a_val end

			if max_matching == nil or a_val > max_matching then max_matching = a_val end
		end
	end

	-- Narrow range_b based on matching union values
	local new_b_min, new_b_max = b_min, b_max

	if min_matching and max_matching then
		if op == "<" then
			new_b_min = math.max(b_min, min_matching + 1)
		elseif op == ">" then
			new_b_max = math.min(b_max, max_matching - 1)
		elseif op == "<=" then
			new_b_min = math.max(b_min, min_matching)
		elseif op == ">=" then
			new_b_max = math.min(b_max, max_matching)
		end
	end

	local a_changed = new_a:GetCardinality() < (#a_data)
	local b_changed = (new_b_min ~= b_min or new_b_max ~= b_max) and new_b_min <= new_b_max

	if not a_changed and not b_changed then return nil, nil end

	local new_b = b_changed and LNumberRange(new_b_min, new_b_max) or nil
	return (a_changed and new_a or nil), new_b
end

-- Add an arithmetic dependency: result = left op right
-- left and right are upvalues, result is an upvalue
function META:AddArithmetic(result, op, left, right)
	local id = self:next_id()
	local constraint = {
		id = id,
		type = "arithmetic",
		op = op,
		result = result,
		left = left,
		right = right,
	}
	self.constraints[id] = constraint
	self:add_dependent(left, id)

	if right then self:add_dependent(right, id) end

	-- Also add result as dependent so HasArithmeticDependencies works
	self:add_dependent(result, id)

	-- Auto-register domains from upvalue values
	if left and left.Type == "upvalue" and not self.domains[left] then
		local val = left:GetValue()

		if val then self.domains[left] = val end
	end

	if right and right.Type == "upvalue" and not self.domains[right] then
		local val = right:GetValue()

		if val then self.domains[right] = val end
	end

	if result and result.Type == "upvalue" and not self.domains[result] then
		local val = result:GetValue()

		if val then self.domains[result] = val end
	end

	return id
end

-- Add a table field dependency: tbl[field] depends on source_upvalue
-- When source_upvalue narrows, the table field should narrow too
function META:AddTableFieldDependency(tbl, field, source_upvalue)
	local id = self:next_id()
	local constraint = {
		id = id,
		type = "table_field",
		table = tbl,
		field = field,
		source = source_upvalue,
	}
	self.constraints[id] = constraint
	self:add_dependent(source_upvalue, id)
	return id
end

-- Get all table field constraints for a source upvalue
function META:GetTableFieldDependencies(source)
	local deps = {}

	for _, cid in ipairs(self.dependents[source] or {}) do
		local c = self.constraints[cid]

		if c and c.type == "table_field" and c.source == source then
			table.insert(deps, c)
		end
	end

	return deps
end

-- Propagate narrowing to table fields when a source upvalue narrows
-- Called during RecomputeArithmeticFor / Narrow propagation
function META:PropagateTableFieldNarrowing(source_upvalue)
	local new_domain = self.domains[source_upvalue]

	if not new_domain then return end

	local deps = self:GetTableFieldDependencies(source_upvalue)

	for _, c in ipairs(deps) do
		local tbl = c.table
		local field = c.field

		if tbl and field then
			-- Store the narrowed domain for this table field
			-- The key is a compound: tbl + field
			local field_key = {table = tbl, field = field}
			self.domains[field_key] = new_domain
		end
	end
end

-- Get narrowed domain for a table field
function META:GetTableFieldDomain(tbl, field)
	local field_key = {table = tbl, field = field}
	return self.domains[field_key]
end

-- Check if a table field has a narrowed domain
function META:HasTableFieldDomain(tbl, field)
	return self:GetTableFieldDomain(tbl, field) ~= nil
end

-- Apply table field narrowing to actual table objects
-- Called after arithmetic dependencies are recomputed in if-block handler
function META:ApplyTableFieldNarrowing(analyzer)
	-- Iterate over all domains that are compound keys (table + field)
	for domain_key, narrowed_domain in pairs(self.domains) do
		-- Check if this is a compound key (table field)
		if type(domain_key) == "table" and domain_key.table and domain_key.field then
			local tbl = domain_key.table
			local field = domain_key.field

			if tbl and field and narrowed_domain then
				-- Set upvalue on the narrowed domain
				if narrowed_domain.SetUpvalue then narrowed_domain:SetUpvalue(nil) end

				-- Mutate the table field with the narrowed value
				if analyzer and analyzer.MutateTable then
					analyzer:MutateTable(tbl, field, narrowed_domain, true)
				end
			end
		end
	end
end

-- Get all arithmetic constraints for a result upvalue
function META:GetArithmeticConstraints(result)
	local constraints = {}

	for _, cid in ipairs(self.dependents[result] or {}) do
		local c = self.constraints[cid]

		if c and c.type == "arithmetic" and c.result == result then
			table.insert(constraints, c)
		end
	end

	return constraints
end

-- Check if an upvalue has arithmetic dependencies
function META:HasArithmeticDependencies(upvalue)
	return #self:GetArithmeticConstraints(upvalue) > 0
end

-- Narrow an upvalue's domain and propagate to dependents (single step)
-- Returns true if the domain actually changed
function META:Narrow(upvalue, new_domain, visited)
	visited = visited or {}

	if visited[upvalue] then return false end

	visited[upvalue] = true
	local current = self.domains[upvalue]

	if not current then
		self.domains[upvalue] = new_domain
		return true
	end

	-- Intersect current domain with new domain
	local changed = false

	if current.Type == "union" and new_domain.Type == "union" then
		local intersection = Union()

		for _, elem in ipairs(current:GetData()) do
			for _, nelem in ipairs(new_domain:GetData()) do
				if shared.Equal(elem, nelem) then
					intersection:AddType(elem)

					break
				end
			end
		end

		if intersection:GetCardinality() > 0 then
			self.domains[upvalue] = intersection
			changed = true
		end
	elseif current.Type == "union" then
		self.domains[upvalue] = new_domain
		changed = true
	end

	-- Propagate to dependent constraints
	local deps = self.dependents[upvalue]

	if not deps then return changed end

	for _, cid in ipairs(deps) do
		local c = self.constraints[cid]

		if not c then continue end

		if c.type == "equality" then
			local other = (c.a == upvalue) and c.b or c.a
			local narrowed = self.domains[upvalue]

			if narrowed then
				if self:Narrow(other, narrowed, visited) then changed = true end
			end
		elseif c.type == "arithmetic" then
			if self:RecomputeArithmetic(c, visited) then changed = true end
		elseif c.type == "table_field" then
			-- Propagate narrowing to table fields
			self:PropagateTableFieldNarrowing(upvalue)
			changed = true
		elseif c.type == "relational" then
			-- Propagate narrowing through relational constraints
			local other = (c.a == upvalue) and c.b or c.a
			local domain_a = self.domains[c.a]
			local domain_b = self.domains[c.b]

			if domain_a and domain_b then
				local new_a, new_b = self:NarrowByRelational(domain_a, domain_b, c.op)

				if new_a and c.a ~= upvalue then
					self.domains[c.a] = new_a

					if self:Narrow(c.a, new_a, visited) then changed = true end
				end

				if new_b and c.b ~= upvalue then
					self.domains[c.b] = new_b

					if self:Narrow(c.b, new_b, visited) then changed = true end
				end

				-- If the other side didn't change recursively but we have a new domain, mark changed
				if new_a or new_b then changed = true end
			end
		end
	end

	return changed
end

-- Propagate all domains until fixed point (no more changes)
-- This handles chains like: x==y, y==z => x+y+z narrows correctly
function META:PropagateUntilFixedPoint(analyzer)
	local max_iterations = 50

	for _ = 1, max_iterations do
		local any_changed = false

		-- Check all arithmetic constraints
		for _, c in pairs(self.constraints) do
			if c.type ~= "arithmetic" then continue end

			-- Use GetEffectiveDomain to fall back to upvalue:GetValue() when domain is nil
			local left_domain = self:GetEffectiveDomain(c.left)
			local right_domain = nil

			if c.right then
				if c.right.Type == "upvalue" then
					right_domain = self:GetEffectiveDomain(c.right)
				else
					-- It's a literal value (e.g., LNumber(1))
					right_domain = c.right
				end
			end

			if not left_domain or not right_domain then continue end

			-- Check if any operand changed since last computation
			if not c.dirty then continue end

			-- Recompute
			local new_result = self:ComputeArithmetic(c)

			if not new_result then continue end

			local current_result = self.domains[c.result]

			if current_result and current_result.Type == "union" and new_result.Type == "union" then
				-- Check if domains are the same
				local same = true
				local cur_data = current_result:GetData()
				local new_data = new_result:GetData()

				if #cur_data ~= #new_data then
					same = false
				else
					for _, cd in ipairs(cur_data) do
						local found = false

						for _, nd in ipairs(new_data) do
							if shared.Equal(cd, nd) then
								found = true

								break
							end
						end

						if not found then
							same = false

							break
						end
					end
				end

				if same then continue end
			end

			-- Update result domain in constraint store
			self.domains[c.result] = new_result
			any_changed = true

			-- Also update the actual upvalue (so GetMutatedUpvalue returns narrowed value)
			if c.result.Mutate and analyzer then
				local scope = analyzer:GetScope()

				if scope then
					new_result:SetUpvalue(c.result)
					c.result:Mutate(new_result, scope)
				end
			end

			-- Mark as clean
			c.dirty = false
			-- Propagate to equality partners of the result
			local result_deps = self.dependents[c.result]

			if result_deps then
				for _, rid in ipairs(result_deps) do
					local rc = self.constraints[rid]

					if rc and rc.type == "equality" then
						local other = (rc.result == c.result) and ((rc.a == c.result) and rc.b or rc.a) or nil

						if other then self:Narrow(other, new_result, {}) end
					elseif rc and rc.type == "arithmetic" then
						-- Mark dependent arithmetic constraints as dirty for chained propagation
						rc.dirty = true
					elseif rc and rc.type == "table_field" then
						-- Propagate narrowing to table fields
						self:PropagateTableFieldNarrowing(c.result)
					end
				end
			end
		end

		if not any_changed then break end
	end
end

-- Check if two upvalues are equality-correlated (same equivalence class)
function META:AreEqualityCorrelated(a, b)
	if not a or not b then return false end

	local class_a = self:equiv_class(a)
	local class_b = self:equiv_class(b)
	return class_a == class_b
end

-- Check if two upvalues have an inequality constraint between them
function META:AreInequalityCorrelated(a, b)
	if not a or not b then return false end

	local deps_a = self.dependents[a]

	if not deps_a then return false end

	for _, cid in ipairs(deps_a) do
		local c = self.constraints[cid]

		if not c then continue end

		if (c.a == a and c.b == b) or (c.a == b and c.b == a) then
			if c.type == "inequality" then return true end
		end
	end

	return false
end

-- Compute the result of an arithmetic constraint
-- Handles equality correlation: if left==right, only compute matching pairs
function META:ComputeArithmetic(constraint)
	-- Use GetEffectiveDomain to fall back to upvalue's own value when domain is nil/empty
	local left_domain = constraint.left and self:GetEffectiveDomain(constraint.left)
	-- For right operand: use domain if it's an upvalue, otherwise use the literal value directly
	local right_domain = nil

	if constraint.right then
		if constraint.right.Type == "upvalue" then
			-- It's an upvalue, use effective domain
			right_domain = self:GetEffectiveDomain(constraint.right)
		else
			-- It's a literal value (e.g., LNumber(1))
			right_domain = constraint.right
		end
	end

	if not left_domain or not right_domain then return nil end

	-- Check if operands are equality-correlated or inequality-correlated
	local eq_correlated = self:AreEqualityCorrelated(constraint.left, constraint.right)
	local neq_correlated = self:AreInequalityCorrelated(constraint.left, constraint.right)
	local new_result = Union()
	local left_data = left_domain.Type == "union" and left_domain:GetData() or {left_domain}
	local right_data = right_domain.Type == "union" and right_domain:GetData() or {right_domain}

	for _, l_elem in ipairs(left_data) do
		for _, r_elem in ipairs(right_data) do
			-- Handle range operands via interval arithmetic
			if l_elem.Type == "range" or r_elem.Type == "range" then
				local l_min, l_max, r_min, r_max

				if l_elem.Type == "range" then
					l_min, l_max = l_elem:GetMin(), l_elem:GetMax()
				elseif l_elem.Type == "number" and l_elem:IsLiteral() then
					l_min, l_max = l_elem:GetData(), l_elem:GetData()
				end

				if r_elem.Type == "range" then
					r_min, r_max = r_elem:GetMin(), r_elem:GetMax()
				elseif r_elem.Type == "number" and r_elem:IsLiteral() then
					r_min, r_max = r_elem:GetData(), r_elem:GetData()
				end

				if l_min ~= nil and r_min ~= nil then
					local res_min, res_max

					if constraint.op == "+" then
						res_min, res_max = l_min + r_min, l_max + r_max
					elseif constraint.op == "-" then
						res_min, res_max = l_min - r_max, l_max - r_min
					elseif constraint.op == "*" then
						-- Full interval multiplication: check all 4 corners
						local candidates = {l_min * r_min, l_min * r_max, l_max * r_min, l_max * r_max}
						res_min, res_max = math.min(unpack(candidates)), math.max(unpack(candidates))
					elseif constraint.op == "/" then
						if r_min >= 0 then
							-- Positive denominator: avoid division by zero
							if r_min == 0 then r_min = 1e-10 end

							res_min, res_max = l_min / r_max, l_max / r_min
						elseif r_max <= 0 then
							-- Negative denominator
							if r_max == 0 then r_max = -1e-10 end

							res_min, res_max = l_max / r_min, l_min / r_max
						else
							-- Denominator spans zero: result is unbounded, skip
							res_min, res_max = nil, nil
						end
					end

					if res_min ~= nil and res_max ~= nil and res_min <= res_max then
						new_result:AddType(LNumberRange(res_min, res_max))
					end
				end
			end

			-- Handle literal number operands
			if l_elem:IsNumeric() and r_elem:IsNumeric() then
				local l_val = l_elem:GetData()
				local r_val = r_elem:GetData()

				if
					l_val ~= nil and
					r_val ~= nil and
					type(l_val) == "number" and
					type(r_val) == "number"
				then
					-- For equality-correlated operands, only compute matching pairs.
					-- For inequality-correlated operands, only compute non-matching pairs.
					if
						not (
							(
								eq_correlated and
								not shared.Equal(l_elem, r_elem)
							)
							or
							(
								neq_correlated and
								shared.Equal(l_elem, r_elem)
							)
						)
					then
						local res_val

						if constraint.op == "+" then
							res_val = l_val + r_val
						elseif constraint.op == "-" then
							res_val = l_val - r_val
						elseif constraint.op == "*" then
							res_val = l_val * r_val
						elseif constraint.op == "/" then
							res_val = r_val ~= 0 and l_val / r_val or nil
						end

						if res_val ~= nil then
							local LNumber = require("nattlua.types.number").LNumber
							new_result:AddType(LNumber(res_val))
						end
					end
				end
			end
		end
	end

	return new_result:GetCardinality() > 0 and new_result:Simplify() or nil
end

-- Recompute an arithmetic constraint if operands are available
-- Returns the new result domain or nil if not available
function META:RecomputeArithmetic(constraint, visited)
	local left_domain = self.domains[constraint.left]
	local right_domain = constraint.right and self.domains[constraint.right]

	if not left_domain then return nil end

	if constraint.right and not right_domain then return nil end

	-- Mark as dirty (caller will handle actual computation)
	constraint.dirty = true
	-- Return the domains for the caller to use
	return {left = left_domain, right = right_domain, op = constraint.op}
end

-- Get all dirty arithmetic constraints
function META:GetDirtyArithmeticConstraints()
	local dirty = {}

	for _, c in pairs(self.constraints) do
		if c.type == "arithmetic" and c.dirty then table.insert(dirty, c) end
	end

	return dirty
end

-- Clear dirty flag for a constraint
function META:ClearDirty(cid)
	local c = self.constraints[cid]

	if c then c.dirty = false end
end

-- Query relationship between two upvalues
-- Returns: true (equal), false (inequal), or nil (unknown)
function META:QueryRelationship(a, b)
	local deps_a = self.dependents[a]

	if not deps_a then return nil end

	for _, cid in ipairs(deps_a) do
		local c = self.constraints[cid]

		if not c then continue end

		if (c.a == a and c.b == b) or (c.a == b and c.b == a) then
			if c.type == "equality" then
				return true
			elseif c.type == "inequality" then
				return false
			end
		end
	end

	return nil
end

-- Scope management
function META:PushScope()
	local snapshot = {
		domains = {},
		constraints = {},
		dependents = {},
		constraint_id = self.constraint_id,
	}

	-- Snapshot domains
	for upvalue, domain in pairs(self.domains) do
		snapshot.domains[upvalue] = domain
	end

	-- Snapshot constraints
	for id, constraint in pairs(self.constraints) do
		snapshot.constraints[id] = constraint
	end

	-- Snapshot dependents
	for upvalue, deps in pairs(self.dependents) do
		snapshot.dependents[upvalue] = {}

		for i, cid in ipairs(deps) do
			snapshot.dependents[upvalue][i] = cid
		end
	end

	table.insert(self.scope_stack, snapshot)
end

function META:PopScope()
	local snapshot = table.remove(self.scope_stack)

	if not snapshot then return end

	-- Restore state
	self.domains = snapshot.domains
	self.constraints = snapshot.constraints
	self.dependents = snapshot.dependents
	self.constraint_id = snapshot.constraint_id
end

-- Fork: create a clone for disjunction handling
function META:Fork()
	local clone = META.new()

	-- Clone domains
	for upvalue, domain in pairs(self.domains) do
		clone.domains[upvalue] = domain
	end

	-- Clone constraints
	for id, constraint in pairs(self.constraints) do
		clone.constraints[id] = constraint

		if constraint.a then clone:add_dependent(constraint.a, id) end

		if constraint.b then clone:add_dependent(constraint.b, id) end

		if constraint.left then clone:add_dependent(constraint.left, id) end

		if constraint.right then clone:add_dependent(constraint.right, id) end
	end

	-- Clone equivalence tracking (needed for chained arithmetic transitivity)
	for upvalue, class in pairs(self.equivalence) do
		clone.equivalence[upvalue] = class
	end

	for union, gid in pairs(self.equiv_groups) do
		clone.equiv_groups[union] = gid
	end

	for union, smap in pairs(self.source_values) do
		clone.source_values[union] = smap
	end

	return clone
end

-- Merge: union domains from two stores (for disjunction branches)
function META:Merge(other)
	local Union = require("nattlua.types.union").Union

	for upvalue, domain in pairs(other.domains) do
		local current = self.domains[upvalue]

		if not current then
			-- No current domain, just copy
			self.domains[upvalue] = domain
		elseif current.Type == "union" and domain.Type == "union" then
			-- Both are unions, union them
			for _, elem in ipairs(domain:GetData()) do
				current:AddType(elem)
			end
		elseif current.Type ~= "union" and domain.Type == "union" then
			-- Current is single value, domain is union - create a new union
			local new_union = Union()
			new_union:AddType(current)

			for _, elem in ipairs(domain:GetData()) do
				new_union:AddType(elem)
			end

			self.domains[upvalue] = new_union
		elseif current.Type == "union" and domain.Type ~= "union" then
			-- Current is union, domain is single value - add to existing union
			current:AddType(domain)
		else
			-- Both are single values - create a union
			local new_union = Union()
			new_union:AddType(current)
			new_union:AddType(domain)
			self.domains[upvalue] = new_union
		end
	end
end

-- Clear equality constraints (keep inequalities and arithmetic deps)
function META:ClearEqualityConstraints()
	local new_constraints = {}
	local new_dependents = {}

	for id, c in pairs(self.constraints) do
		if c.type == "inequality" or c.type == "arithmetic" or c.type == "table_field" then
			new_constraints[id] = c

			if c.a then
				if not new_dependents[c.a] then new_dependents[c.a] = {} end

				table.insert(new_dependents[c.a], id)
			end

			if c.b then
				if not new_dependents[c.b] then new_dependents[c.b] = {} end

				table.insert(new_dependents[c.b], id)
			end

			if c.left then
				if not new_dependents[c.left] then new_dependents[c.left] = {} end

				table.insert(new_dependents[c.left], id)
			end

			if c.right then
				if not new_dependents[c.right] then new_dependents[c.right] = {} end

				table.insert(new_dependents[c.right], id)
			end

			if c.source then
				if not new_dependents[c.source] then new_dependents[c.source] = {} end

				table.insert(new_dependents[c.source], id)
			end

			if c.result then
				if not new_dependents[c.result] then new_dependents[c.result] = {} end

				table.insert(new_dependents[c.result], id)
			end
		end
	end

	self.constraints = new_constraints
	self.dependents = new_dependents
	self.equivalence = {} -- Clear equivalence classes
end

-- Get effective domain for an upvalue (narrowed if available, otherwise from upvalue)
function META:GetEffectiveDomain(upvalue)
	if self.domains[upvalue] then return self.domains[upvalue] end

	return upvalue.Type == "upvalue" and upvalue:GetValue()
end

-- Recompute all arithmetic dependencies (uses ComputeArithmetic which handles correlation)
function META:RecomputeAllArithmetic(analyzer)
	for _, c in pairs(self.constraints) do
		if c.type ~= "arithmetic" then continue end

		if not c.left or not c.right or not c.result then continue end

		-- Use effective domain (narrowed by constraint store if available)
		local left_domain = self:GetEffectiveDomain(c.left)
		local right_domain = self:GetEffectiveDomain(c.right)

		if not left_domain or not right_domain then continue end

		-- Use ComputeArithmetic which handles equality correlation
		local new_result = self:ComputeArithmetic(c)

		if not new_result or type(new_result) ~= "table" or new_result.Type ~= "union" then
			continue
		end

		if new_result:GetCardinality() > 0 and c.result.Mutate then
			local scope = analyzer and analyzer:GetScope()

			if scope then c.result:Mutate(new_result, scope) end
		end
	end
end

-- Private helpers
function META:next_id()
	self.constraint_id = self.constraint_id + 1
	return self.constraint_id
end

function META:add_dependent(upvalue, cid)
	if not self.dependents[upvalue] then self.dependents[upvalue] = {} end

	table.insert(self.dependents[upvalue], cid)
end

-- these have been moved from the analyzer to the constraint store in order to reduce change complexity
-- they might move back once the solution is more final
do
	do
		local LString = require("nattlua.types.string").LString

		function META:TrackTableFieldDependency(analyzer, node, tbl, key)
			local rhs = node.value_expression

			if rhs.Type == "expression_value" and rhs.value then
				local name = rhs.value:GetValueString()

				if name then
					local source_upvalue = analyzer:FindLocalUpvalue(LString(name))

					if source_upvalue and self:HasArithmeticDependencies(source_upvalue) then
						self:AddTableFieldDependency(tbl, key, source_upvalue)
					end
				end
			end
		end
	end

	-- ----------------------------------------------------------------
	-- Correlated / equivalence operand computation.
	--
	-- The constraint store owns two concerns:
	--   1. Query: are the operands correlated? return a predicate + tag info.
	--   2. Tag:  after the caller computes, tag the result union.
	--
	-- The caller (binary.lua) owns the computation loop (BinaryInner calls).
	-- ----------------------------------------------------------------
	local AnalyzeAtomicValue = require("nattlua.analyzer.expressions.atomic_value").AnalyzeAtomicValue

	-- Query whether operands are correlated or equivalent.
	-- Returns nil, or { predicate, tag_key, track_sources }.
	--
	-- predicate(l_elem, r_elem) -> bool : which pairs the caller should compute
	-- tag_key                    : upvalue or union to tag equivalence on
	-- track_sources              : whether to build a source map for tagging
	-- original_l, original_r     : AST operand nodes (for upvalue lookup)
	-- l, r                       : union values being operated on
	-- arith_ops                  : table of arithmetic operator names
	-- op                         : the operator string
	function META:QueryCorrelatedComputation(original_l, original_r, l, r, arith_ops, op)
		local l_upvalue = original_l:GetUpvalue()
		local r_upvalue = original_r:GetUpvalue()
		local has_l_upvalue = l_upvalue ~= nil and l_upvalue ~= false
		local has_r_upvalue = r_upvalue ~= nil and r_upvalue ~= false
		-- --- Correlation branch ---
		local correlation

		if has_l_upvalue and has_r_upvalue then
			correlation = self:QueryRelationship(l_upvalue, r_upvalue)
		end

		if correlation ~= nil then
			local is_valid_op = arith_ops[op] or op == ".." or op == "//" or op == "//idiv//"

			if is_valid_op then
				return {
					predicate = function(l_elem, r_elem)
						local eq = shared.Equal(l_elem, r_elem)
						return (correlation and eq) or (not correlation and not eq)
					end,
					tag_key = correlation and l_upvalue,
					track_sources = correlation ~= false,
				}
			end
		end

		-- --- Equivalence branch ---
		local l_equiv = has_l_upvalue and self:GetEquivalenceGroupId(l_upvalue)
		local r_equiv = has_r_upvalue and self:GetEquivalenceGroupId(r_upvalue)
		local l_union_equiv = self:GetEquivalenceGroupIdFromUnion(l)
		local r_union_equiv = self:GetEquivalenceGroupIdFromUnion(r)
		local same_equiv = (
				l_equiv and
				l_equiv == r_equiv
			)
			or
			(
				l_union_equiv and
				l_union_equiv == r_union_equiv
			)
			or
			(
				l_union_equiv and
				l_union_equiv == r_equiv
			)
			or
			(
				r_union_equiv and
				r_union_equiv == l_equiv
			)

		if same_equiv and arith_ops[op] then
			local l_sources = self:GetSourceValues(l)
			local tag_key = l_upvalue or l
			return {
				predicate = function(l_elem, r_elem)
					if l_sources then
						local orig = self:GetOriginalValue(l, l_elem)
						return orig and shared.Equal(orig, r_elem)
					end

					return shared.Equal(l_elem, r_elem)
				end,
				tag_key = tag_key,
				track_sources = true,
			}
		end

		return nil
	end

	-- Tag the result union after the caller has computed it.
	-- new_union   : the computed result
	-- tag_info    : the table returned by QueryCorrelatedComputation
	-- source_map  : { [result_type] = source_type, ... } built by caller
	function META:TagCorrelatedResult(new_union, tag_info, source_map)
		if tag_info.tag_key then
			self:TagEquivalence(new_union, tag_info.tag_key)

			if tag_info.track_sources and source_map then
				self:TagSourceValues(new_union, source_map)
			end
		end
	end

	-- Track equality/inequality correlation from a binary comparison
	-- op: "==", "!=", "~="
	-- original_l: left operand node
	-- original_r: right operand node
	-- l: left atomic value (for literal tracking)
	-- r: right atomic value (for literal tracking)
	function META:TrackEqualityCorrelation(op, l_upvalue, r_upvalue, l, r)
		if op ~= "==" and op ~= "~=" and op ~= "!=" then return end

		-- Track correlation between upvalues when comparing with == or ~=
		if l_upvalue and r_upvalue and l_upvalue ~= r_upvalue then
			if op == "==" then
				self:AddEquality(l_upvalue, r_upvalue)
			else
				self:AddInequality(l_upvalue, r_upvalue)
			end
		end

		-- Also track literal equality: x == 1 means narrow x to 1
		-- Track the operator so early return narrowing can distinguish == from ~=
		if op == "==" or op == "~=" then
			if l_upvalue and not r_upvalue then
				self:AddEquality(l_upvalue, r, op)
			elseif r_upvalue and not l_upvalue then
				self:AddEquality(r_upvalue, l, op)
			end
		end
	end

	-- Track relational correlation from a binary comparison
	-- op: "<", ">", "<=", ">="
	-- l_upvalue: left operand upvalue (or nil if literal)
	-- r_upvalue: right operand upvalue (or nil if literal)
	-- l: left atomic value (for literal tracking)
	-- r: right atomic value (for literal tracking)
	function META:TrackRelationalCorrelation(op, l_upvalue, r_upvalue, l, r)
		if op ~= "<" and op ~= ">" and op ~= "<=" and op ~= ">=" then return end

		-- Track relational constraint between upvalues
		-- Skip if either side's current value is a single literal number (can't be narrowed)
		local function is_single_literal(domain)
			return domain and domain.Type == "number" and domain.IsLiteral and domain:IsLiteral()
		end

		if l_upvalue and r_upvalue and l_upvalue ~= r_upvalue then
			local l_domain = self.domains[l_upvalue] or l_upvalue:GetValue()
			local r_domain = self.domains[r_upvalue] or r_upvalue:GetValue()

			if not is_single_literal(l_domain) and not is_single_literal(r_domain) then
				self:AddRelational(l_upvalue, r_upvalue, op)
			end
		end

		-- Track relational constraint with literal: x < 5 means narrow x
		-- Only if the upvalue side is not itself a single literal
		if l_upvalue and not r_upvalue then
			local l_domain = self.domains[l_upvalue] or l_upvalue:GetValue()

			if not is_single_literal(l_domain) then
				self:AddRelational(l_upvalue, r, op)
			end
		elseif r_upvalue and not l_upvalue then
			-- For right-side upvalue, invert the operator
			local r_domain = self.domains[r_upvalue] or r_upvalue:GetValue()

			if not is_single_literal(r_domain) then
				local inv_op

				if op == "<" then
					inv_op = ">"
				elseif op == ">" then
					inv_op = "<"
				elseif op == "<=" then
					inv_op = ">="
				elseif op == ">=" then
					inv_op = "<="
				end

				self:AddRelational(r_upvalue, l, inv_op)
			end
		end
	end

	do
		local LString = require("nattlua.types.string").LString

		-- Extract upvalues from an expression
		local function ExtractExpressionUpvalues(analyzer, expr)
			if not expr then return {} end

			local upvalues = {}

			if expr.Type == "expression_value" then
				-- Skip literals (numbers, strings, etc.) - only extract variable references
				if
					expr.value.type == "letter" or
					expr.value.type == "identifier" or
					expr.value.type == "symbol"
				then
					local name = expr.value:GetValueString()
					local val = analyzer:GetLocalOrGlobalValue(LString(name))

					if val then
						local uv = val:GetUpvalue()

						if uv then table.insert(upvalues, uv) end
					end
				end
			elseif expr.Type == "expression_binary_operator" then
				-- Recursively extract from both sides
				for _, uv in ipairs(ExtractExpressionUpvalues(expr.left)) do
					table.insert(upvalues, uv)
				end

				for _, uv in ipairs(ExtractExpressionUpvalues(expr.right)) do
					table.insert(upvalues, uv)
				end
			end

			return upvalues
		end

		-- Track arithmetic dependencies from a binary expression (left op right -> result_upvalue)
		-- analyzer: the analyzer context with ExtractExpressionUpvalues method
		-- statement: the local assignment statement (contains .right)
		function META:TrackArithmeticDependencies(analyzer, result_upvalue, exp_val)
			if not result_upvalue then return end

			local op = exp_val.value.sub_type or exp_val.value:GetValueString()

			if op ~= "+" and op ~= "-" and op ~= "*" and op ~= "/" then return end

			local left_uvs = ExtractExpressionUpvalues(analyzer, exp_val.left)
			local right_uvs = ExtractExpressionUpvalues(analyzer, exp_val.right)

			-- Track if at least one operand is a variable (literals can still be part of deps)
			if (#left_uvs > 0 or #right_uvs > 0) then
				for _, lu in ipairs(left_uvs) do
					for _, ru in ipairs(right_uvs) do
						self:AddArithmetic(result_upvalue, op, lu, ru)
					end
				end

				-- If one operand is a literal, evaluate it and track with the type value
				if #left_uvs > 0 and #right_uvs == 0 then
					local right_val = exp_val.right.Type == "expression_value" and
						AnalyzeAtomicValue(analyzer, exp_val.right)

					if right_val then
						for _, lu in ipairs(left_uvs) do
							self:AddArithmetic(result_upvalue, op, lu, right_val)
						end
					end
				elseif #left_uvs == 0 and #right_uvs > 0 then
					local left_val = exp_val.left.Type == "expression_value" and
						AnalyzeAtomicValue(analyzer, exp_val.left)

					if left_val then
						for _, ru in ipairs(right_uvs) do
							self:AddArithmetic(result_upvalue, op, left_val, ru)
						end
					end
				end
			end
		end
	end

	-- Recompute arithmetic dependencies for an upvalue when it narrows
	-- Uses the constraint store's effective domain (includes narrowed values)
	function META:RecomputeArithmeticFor(upvalue)
		-- Check arithmetic constraints where this upvalue is an operand
		local deps = self.dependents[upvalue]

		if not deps then return end

		for _, cid in ipairs(deps) do
			local c = self.constraints[cid]

			if not c or c.type ~= "arithmetic" then continue end

			-- Use effective domain (includes narrowed domains from constraint store)
			local left_domain = self:GetEffectiveDomain(c.left)
			local right_domain = c.right and self:GetEffectiveDomain(c.right)

			if not left_domain or (c.right and not right_domain) then continue end

			-- Compute new result domain using direct arithmetic
			local new_result = self:ComputeArithmetic(c)

			if not new_result then continue end

			-- Update the constraint store's domain for the result
			self.domains[c.result] = new_result
			-- Also propagate to table fields that depend on the result
			self:PropagateTableFieldNarrowing(c.result)
		end

		-- Also propagate to table fields that depend on this upvalue
		self:PropagateTableFieldNarrowing(upvalue)
	end
end

-- Apply narrowing for code after an early return.
-- When a branch like "if x == 1 then return end" exits, the remaining code
-- should see x narrowed to exclude the value that triggered the return.
--
-- NOTE: This only handles "==" comparisons with literals. "~=" comparisons
-- are already handled correctly by the existing mutation tracking system
-- (truthy/falsy union splitting).
--
-- Parameters:
--   analyzer: the analyzer context (for mutating upvalues)
--   original_values: table mapping upvalue -> original domain (saved before if)
--   returning_branch_truthy: boolean, true if the returning branch was truthy
function META:ApplyEarlyReturnNarrowing(analyzer, original_values, returning_branch_truthy)
	if not original_values then return end

	-- Collect equality constraints with literals (only "==", not "~=")
	local narrowed_upvalues = {} -- upvalue -> new domain
	-- Process equality constraints with literals (only "==", not "~=")
	for _, c in pairs(self.constraints) do
		if c.type ~= "equality" then continue end

		if (c.op or "==") ~= "==" then continue end

		local a_is_upvalue = c.a and c.a.Type == "upvalue"
		local b_is_upvalue = c.b and c.b.Type == "upvalue"
		local upvalue, literal = nil, nil

		if a_is_upvalue and not b_is_upvalue then
			upvalue, literal = c.a, c.b
		elseif b_is_upvalue and not a_is_upvalue then
			upvalue, literal = c.b, c.a
		else
			continue
		end

		local current_domain = self:GetEffectiveDomain(upvalue)

		if not current_domain then current_domain = original_values[upvalue] end

		if not current_domain then continue end

		-- Truthy branch: x == literal was true → x IS literal
		-- After return: exclude literal from domain
		local complement = self:RemoveTypesFromDomain(current_domain, {literal})

		if complement then narrowed_upvalues[upvalue] = complement end
	end

	-- Process relational constraints: apply negated operator for complement narrowing
	for _, c in pairs(self.constraints) do
		if c.type ~= "relational" then continue end

		local a_is_upvalue = c.a and c.a.Type == "upvalue"
		local b_is_upvalue = c.b and c.b.Type == "upvalue"

		if a_is_upvalue and not b_is_upvalue then
			local current_domain = self:GetEffectiveDomain(c.a)

			if not current_domain then current_domain = original_values[c.a] end

			if not current_domain then continue end

			-- Negate the operator: truthy was x >= 5, complement is x < 5
			local neg_op = META:NegateRelationalOp(c.op)
			local narrowed, empty = META:NarrowDomainByLiteral(current_domain, c.b, neg_op)

			if empty then
				-- Complement is empty (unreachable code)
				narrowed_upvalues[c.a] = nil
			elseif narrowed then
				narrowed_upvalues[c.a] = narrowed
			end
		elseif b_is_upvalue and not a_is_upvalue then
			local current_domain = self:GetEffectiveDomain(c.b)

			if not current_domain then current_domain = original_values[c.b] end

			if not current_domain then continue end

			-- Invert then negate: for "x >= 5" where x is on right side
			local inv_op = META:InvertRelationalOp(c.op)
			local neg_op = META:NegateRelationalOp(inv_op)
			local narrowed, empty = META:NarrowDomainByLiteral(current_domain, c.a, neg_op)

			if empty then
				narrowed_upvalues[c.b] = nil
			elseif narrowed then
				narrowed_upvalues[c.b] = narrowed
			end
		end
	end

	-- Apply narrowed domains
	for upvalue, new_domain in pairs(narrowed_upvalues) do
		self.domains[upvalue] = new_domain

		-- Mutate the actual upvalue so narrowed value is visible
		if upvalue.Mutate and analyzer then
			local scope = analyzer:GetScope()

			if scope then
				if new_domain and new_domain.SetUpvalue then new_domain:SetUpvalue(upvalue) end

				if new_domain then upvalue:Mutate(new_domain, scope) end
			end
		end
	end

	-- Propagate narrowing through arithmetic dependencies
	if next(narrowed_upvalues) and analyzer then
		self:PropagateUntilFixedPoint(analyzer)
	end
end

-- Remove specific types from a domain (union or range)
-- Returns a new domain with the specified types removed, or nil if no change
function META:RemoveTypesFromDomain(domain, types_to_remove)
	if not domain then return nil end

	if domain.Type == "union" then
		local data = domain:GetData()
		local new_union = Union()
		local changed = false

		for _, elem in ipairs(data) do
			local should_remove = false

			for _, remove_type in ipairs(types_to_remove) do
				if shared.Equal(elem, remove_type) then
					should_remove = true

					break
				end
			end

			if not should_remove then
				new_union:AddType(elem)
			else
				changed = true
			end
		end

		return changed and new_union or nil
	elseif domain.Type == "range" or domain.Type == "number" then
		-- For ranges, we can only remove if types_to_remove contains a range
		-- that overlaps with the original
		for _, remove_type in ipairs(types_to_remove) do
			if remove_type.Type == "range" then
				local min, max = domain:GetMin(), domain:GetMax()
				local r_min, r_max = remove_type:GetMin(), remove_type:GetMax()
				-- Compute complement: parts of [min, max] not in [r_min, r_max]
				local complement = Union()

				if min < r_min then complement:AddType(LNumberRange(min, r_min - 1)) end

				if max > r_max then complement:AddType(LNumberRange(r_max + 1, max)) end

				return complement:GetCardinality() > 0 and complement or nil
			end
		end
	end

	return nil
end

-- Get all unique upvalues tracked by the constraint store (from domains + constraints)
function META:GetAllTrackedUpvalues()
	local upvalues = {}

	for upvalue in pairs(self.domains) do
		if upvalue.Type == "upvalue" then upvalues[upvalue] = true end
	end

	for _, c in pairs(self.constraints) do
		if c.a and c.a.Type == "upvalue" then upvalues[c.a] = true end

		if c.b and c.b.Type == "upvalue" then upvalues[c.b] = true end

		if c.left and c.left.Type == "upvalue" then upvalues[c.left] = true end

		if c.right and c.right.Type == "upvalue" then upvalues[c.right] = true end

		if c.result and c.result.Type == "upvalue" then upvalues[c.result] = true end
	end

	return upvalues
end

-- Clear domains for a set of upvalues
function META:ClearDomainsFor(upvalues)
	for upvalue in pairs(upvalues) do
		self.domains[upvalue] = nil
	end
end

-- Mark all arithmetic constraints as dirty
function META:MarkConstraintsDirty(what)
	for _, c in pairs(self.constraints) do
		if c.type == what then c.dirty = true end
	end
end

-- Reset constraint store state for a new loop iteration.
-- Clears narrowed domains and relational/equality constraints so narrowing
-- doesn't compound across iterations. Keeps arithmetic and table_field
-- dependencies intact (they are structural, not narrowing-specific).
function META:ResetForLoopIteration()
	-- Clear all narrowed domains so they fall back to upvalue:GetValue()
	self.domains = {}
	-- Keep only arithmetic and table_field constraints
	local new_constraints = {}
	local new_dependents = {}

	for id, c in pairs(self.constraints) do
		if c.type == "arithmetic" or c.type == "table_field" then
			new_constraints[id] = c

			-- Rebuild dependents for kept constraints
			if c.left and c.left.Type == "upvalue" then
				if not new_dependents[c.left] then
					new_dependents[c.left] = {}
					table.insert(new_dependents[c.left], id)
				end
			end

			if c.right and c.right.Type == "upvalue" then
				if not new_dependents[c.right] then
					new_dependents[c.right] = {}
					table.insert(new_dependents[c.right], id)
				end
			end

			if c.result and c.result.Type == "upvalue" then
				if not new_dependents[c.result] then
					new_dependents[c.result] = {}
					table.insert(new_dependents[c.result], id)
				end
			end

			if c.source and c.source.Type == "upvalue" then
				if not new_dependents[c.source] then
					new_dependents[c.source] = {}
					table.insert(new_dependents[c.source], id)
				end
			end

			if c.table and c.table.Type == "upvalue" then
				if not new_dependents[c.table] then
					new_dependents[c.table] = {}
					table.insert(new_dependents[c.table], id)
				end
			end
		end
	end

	self.constraints = new_constraints
	self.dependents = new_dependents
	-- Clear equivalence classes and source tracking
	self.equivalence = {}
	self.equiv_groups = {}
	self.source_values = {}

	-- Mark arithmetic constraints dirty so they recompute with fresh domains
	for _, c in pairs(self.constraints) do
		if c.type == "arithmetic" then c.dirty = true end
	end
end

return META
