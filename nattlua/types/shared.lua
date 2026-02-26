local shared = {}
local error_messages = require("nattlua.error_messages")

function shared.Equal(a--[[#: TBaseType]], b--[[#: TBaseType]], visited--[[#: any]])--[[#: boolean, string | nil]]
	if a.Type == "string" then
		if a.Type ~= b.Type then return false, "types differ" end

		return a.Hash == b.Hash, "string values are equal"
	elseif a.Type == "symbol" then
		if a.Type ~= b.Type then return false, "types differ" end

		if a.Data == b.Data then return true, "symbol values match" end

		return false, "values are not equal"
	elseif a.Type == "table" then
		if a.Type ~= b.Type then return false, "types differ" end

		if a:IsUnique() then
			return a:GetUniqueID() == b:GetUniqueID(), "unique ids match"
		end

		do
			local contract = a:GetContract()

			if contract and contract.Type == "table" and (contract--[[# as TTable]]).Name then
				if
					not (
						b
					--[[# as TTable]]):GetContract() or
					not (
						(
							b
						--[[# as TTable]]):GetContract()
					--[[# as TTable]]).Name
				then
					return false, "contract name mismatch"
				end

				-- never called
				return (
						(
							contract
						--[[# as TTable]]).Name
					--[[# as TBaseType]]):GetData() == (
						(
							(
								b
							--[[# as TTable]]):GetContract()
						--[[# as TTable]]).Name
					--[[# as TBaseType]]):GetData(),
				"contract names match"
			end
		end

		if a.Name then
			if not (b--[[# as TTable]]).Name then return false, "name property mismatch" end

			return a.Name:GetData() == ((b--[[# as TTable]]).Name--[[# as TBaseType]]):GetData(),
			"names match"
		end

		visited = visited or {}

		if visited[a] then return true, "circular reference detected" end

		visited[a] = true
		local adata = a:GetData()
		local bdata = (b--[[# as TTable]]):GetData()

		if #adata ~= #bdata then return false, "table size mismatch" end

		local matched = {}

		for i = 1, #adata do
			local akv = adata[i]
			local ok = false

			for i = 1, #bdata do
				if not matched[i] then -- Skip already matched entries
					if
						shared.Equal(akv.key, bdata[i].key, visited) and
						shared.Equal(akv.val, bdata[i].val, visited)
					then
						ok = true
						matched[i] = true

						break
					end
				end
			end

			if not ok then return false, "table key-value mismatch" end
		end

		return true, "all table entries match"
	elseif a.Type == "range" then
		return a.Hash == b.Hash
	elseif a.Type == "tuple" then
		if a.Type ~= b.Type then return false, "types differ" end

		visited = visited or {}

		if visited[a] then return true, "circular reference detected" end

		if #a.Data ~= #b.Data then return false, "length mismatch" end

		local ok, reason = true, "all match"
		visited[a] = true

		for i = 1, #a.Data do
			ok, reason = shared.Equal(a.Data[i]--[[# as any]], b.Data[i]--[[# as any]], visited)

			if not ok then break end
		end

		if not ok then reason = reason or "unknown reason" end

		return ok, reason
	elseif a.Type == "union" then
		visited = visited or {}

		if visited[a] then return true, "circular reference detected" end

		if b.Type ~= "union" and a:GetCardinality() == 1 and a.Data[1] then
			return shared.Equal(a.Data[1], b, visited)
		end

		if a.Type ~= b.Type then return false, "types differ" end

		local b = b
		local len = #a.Data

		if len ~= #b.Data then return false, "length mismatch" end

		for i = 1, len do
			local a = assert(a.Data[i])
			local ok = false
			local reasons = {}

			for i = 1, len do
				local b = b.Data[i]
				local reason
				ok, reason = shared.Equal(a, b, visited)

				if ok then break end

				table.insert(reasons, reason--[[# as string]])
			end

			if a.Type == "table" then visited[a] = true end

			if not ok then
				return false, "union value mismatch: " .. table.concat(reasons, "\n")
			end
		end

		return true, "all union values match"
	elseif a.Type == "number" then
		if a.Type ~= b.Type then return false, "types differ" end

		return a.Hash == b.Hash, "hash values are equal"
	elseif a.Type == "function" then
		if a.Type ~= b.Type then return false, "types differ" end

		local a_input = a:GetInputSignature()
		local b_input = b:GetInputSignature()--[[# as TTuple]]

		if not a_input or not b_input then return false, "missing input signature" end

		local ok, reason = shared.Equal(a_input, b_input, visited)

		if not ok then return false, "input signature mismatch: " .. reason end

		local a_output = a:GetOutputSignature()
		local b_output = b:GetOutputSignature()--[[# as TTuple]]

		if not a_output or not b_output then return false, "missing output signature" end

		local ok, reason = shared.Equal(a_output, b_output, visited)

		if not ok then return false, "output signature mismatch: " .. reason end

		return true, "ok"
	elseif a.Type == "deferred" then
		local unwrapped = a:Unwrap()

		if unwrapped == a then return b == a end

		return shared.Equal(unwrapped, b, visited)
	elseif a.Type == "any" then
		return a.Type == b.Type, "any types match"
	end

	return false, "nyi"
end

function shared.IsSubsetOf(a--[[#: TBaseType]], b--[[#: TBaseType]], visited--[[#: any]])--[[#: boolean, string | nil]]
	if a.Type == "any" then return true end

	if a.Type == "number" then
		if b.Type == "tuple" then b = b:GetWithNumber(1) end

		if b.Type == "any" then return true end

		if b.Type == "union" then return b:IsTargetSubsetOfChild(a) end

		if b.Type == "range" then
			if a.Data and a.Data >= b:GetMin() and a.Data <= b:GetMax() then
				return true
			end

			return false, error_messages.subset(a, b)
		end

		if b.Type ~= "number" then return false, error_messages.subset(a, b) end

		if a.Data and b.Data then
			if a:IsNan() and b:IsNan() then return true end

			if a.Data == b.Data then return true end

			return false, error_messages.subset(a, b)
		elseif a.Data == false and b.Data == false then
			-- number contains number
			return true
		elseif a.Data and not b.Data then
			-- 42 subset of number?
			return true
		elseif not a.Data and b.Data then
			-- number subset of 42 ?
			return false, error_messages.subset(a, b)
		end

		-- number == number
		return true
	end

	if a.Type == "deferred" then
		if b.Type == "any" then return true end

		local unwrapped = a:Unwrap()

		if unwrapped == a then return b == a end

		return shared.IsSubsetOf(unwrapped, b, visited)
	end

	if a.Type == "string" then
		local A, B = a, b

		if B.Type == "tuple" then B = B:GetWithNumber(1) end

		if B.Type == "any" then return true end

		if B.Type == "union" then return B:IsTargetSubsetOfChild(A) end

		if B.Type ~= "string" then return false, error_messages.subset(A, B) end

		if not A.Data and B.PatternContract then
			if A.PatternContract == B.PatternContract then return true end

			return false, error_messages.string_pattern_type_mismatch(A)
		end

		if A.Data == B.Data and not B.PatternContract then -- "A" subsetof "B" or string subsetof string
			return true
		end

		if A.Data and not B.Data and not B.PatternContract then -- "A" subsetof string
			return true
		end

		if B.PatternContract then
			local str = A.Data

			if not str then -- TODO: this is not correct, it should be .Data but I have not yet decided this behavior yet
				return false, error_messages.string_pattern_type_mismatch(A)
			end

			if not str:find(B.PatternContract) then
				return false, error_messages.string_pattern_match_fail(A, B)
			end

			return true
		end

		return false, error_messages.subset(A, B)
	end

	if a.Type == "symbol" then
		if b.Type == "tuple" then b = b:GetWithNumber(1) end

		if b.Type == "any" then return true end

		if b.Type == "union" then return b:IsTargetSubsetOfChild(a--[[# as any]]) end

		if b.Type ~= "symbol" then return false, error_messages.subset(a, b) end

		if a.Data ~= b.Data then return false, error_messages.subset(a, b) end

		return true
	end

	if a.Type == "table" then
		if b.Type == "deferred" then b = b:Unwrap() end

		if a.suppress then return true, "suppressed" end

		if b.Type == "tuple" then b = (b--[[# as any]]):GetWithNumber(1) end

		if b.Type == "any" then return true, "b is any" end

		if b.Type == "table" then
			if a == b then return true, "same type" end

			local ok, err = a:IsSameUniqueType(b--[[# as TTable]])

			if not ok then return ok, err end
		end

		if b.Type == "table" then
			if (b--[[# as TTable]]):GetMetaTable() and (b--[[# as TTable]]):GetMetaTable() == a then
				return true, "same metatable"
			end

			if a:IsEmpty() then
				if (b--[[# as TTable]]):CanBeEmpty() then return true, "can be empty" end

				return false, error_messages.subset(a, b)
			end

			for _, bkeyval in ipairs((b--[[# as TTable]]):GetData()) do
				local akeyval, reason = a:FindKeyValWide(bkeyval.key, true)

				if not bkeyval.val:CanBeNil() then
					if not akeyval then return (akeyval--[[# as any]]), reason end

					local a_any = a--[[# as any]]
					local old = a_any.suppress
					a_any.suppress = true
					local ok, err = shared.IsSubsetOf((akeyval--[[# as any]]).val, bkeyval.val)
					a_any.suppress = old

					if not ok then
						return false,
						error_messages.because(
							error_messages.table_subset(bkeyval.key, (akeyval--[[# as any]]).key, bkeyval.val, (akeyval--[[# as any]]).val),
							err
						)
					end
				end
			end

			if (b--[[# as TTable]]):IsNumericallyIndexed() and not a:IsNumericallyIndexed() then
				return false, error_messages.subset(a, b)
			end

			return true, "all is equal"
		elseif b.Type == "union" then
			for _, obj in ipairs((b--[[# as any]]).Data) do
				local ok, err = a:IsSubsetOf(obj)

				if ok then return true, "a is subset of one in the union" end
			end

			return false, error_messages.subset(a, b)
		end

		return false, error_messages.subset(a, b)
	end

	if a.Type == "tuple" then
		if b.Type == "deferred" then b = b:Unwrap() end

		if a == b then return true end

		if a.suppress then return true end

		if a.Remainder then
			local t = a:GetWithNumber(1)

			if t and t.Type == "any" and #a:GetData() == 0 then return true end
		end

		if b.Type == "union" then return b:IsTargetSubsetOfChild(a--[[# as any]]) end

		do
			local t = a:GetWithNumber(1)

			if t and t.Type == "any" and b.Type == "tuple" and b:IsEmpty() then
				return true
			end
		end

		if b.Type == "any" then return true end

		if b.Type == "table" then
			if not b:IsNumericallyIndexed() then
				return false, error_messages.numerically_indexed(b)
			end
		end

		if b.Type ~= "tuple" then return false, error_messages.subset(a, b) end

		-- TODO
		local max_length = visited or math.max(a:GetMinimumLength(), b:GetMinimumLength())

		for i = 1, max_length do
			local a_val, err = a:GetWithNumber(i)

			if not a_val then return false, error_messages.subset(a, b, err) end

			local b_val, err = b:GetWithNumber(i)

			if not b_val and a_val.Type == "any" then break end

			if not b_val then
				return false, error_messages.because(error_messages.table_index(b, i), err)
			end

			a.suppress = true
			local ok, reason = shared.IsSubsetOf(a_val, b_val)
			a.suppress = false

			if not ok then
				return false, error_messages.because(error_messages.subset(a_val, b_val), reason)
			end
		end

		return true
	end

	if a.Type == "union" then
		if b.Type == "deferred" then b = b:Unwrap() end

		if a.suppress then return true, "suppressed" end

		if b.Type == "tuple" then b = b:GetWithNumber(1) end

		if b.Type == "any" then return true end

		if a:IsEmpty() then
			return false,
			error_messages.because(error_messages.subset(a, b), {"union is empty"})
		end

		for _, a_val in ipairs(a.Data) do
			a.suppress = true
			local b_val, reason
			local ok

			if b.Type == "union" then
				b_val, reason = b:IsTypeObjectSubsetOf(a_val)
			else
				ok, reason = shared.IsSubsetOf(a_val, b)

				if ok then
					b_val = b
				else
					b_val = false
					reason = reason
				end
			end

			a.suppress = false

			if not b_val then
				return false, error_messages.because(error_messages.subset(b, a_val), reason)
			end

			a.suppress = true
			local ok, reason = shared.IsSubsetOf(a_val, b_val)
			a.suppress = false

			if not ok then
				return false, error_messages.because(error_messages.subset(a_val, b_val), reason)
			end
		end

		return true
	end

	if a.Type == "range" then
		if b.Type == "tuple" then b = b:GetWithNumber(1) end

		if b.Type == "any" then return true end

		if b.Type == "union" then return b:IsTargetSubsetOfChild(a) end

		if b.Type == "number" and not b.Data then return true end

		if b.Type ~= "range" then return false, error_messages.subset(a, b) end

		if a:GetMin() >= b:GetMin() and a:GetMax() <= b:GetMax() then return true end

		return false, error_messages.subset(a, b)
	end

	if a.Type == "function" then
		if b.Type == "deferred" then b = b:Unwrap() end

		if b.Type == "tuple" then
			b = assert(b:GetWithNumber(1--[[# as any]]))--[[# as TBaseType]]
		end

		if b.Type == "union" then return b:IsTargetSubsetOfChild(a) end

		if b.Type == "any" then return true end

		if b.Type ~= "function" then return false, error_messages.subset(a, b) end

		local a_input = a:GetInputSignature()
		local b_input = b:GetInputSignature()

		if not a_input or not b_input then return false, "missing input signature" end

		local ok, reason = shared.IsSubsetOf(a_input, b_input)

		if not ok then
			return false,
			error_messages.because(error_messages.subset(a_input, b_input), reason)
		end

		local a_output = a:GetOutputSignature()
		local b_output = b:GetOutputSignature()

		if not a_output or not b_output then return false, "missing output signature" end

		local ok, reason = shared.IsSubsetOf(a_output, b_output)

		if
			not ok and
			(
				(
					not b:IsCalled() and
					not b:IsExplicitOutputSignature()
				)
				or
				(
					not a:IsCalled() and
					not a:IsExplicitOutputSignature()
				)
			)
		then
			return true
		end

		if not ok then
			return false,
			error_messages.because(error_messages.subset(a_output, b_output), reason)
		end

		return true
	end

	do -- base
		if b.Type == "deferred" then b = b:Unwrap() end

		return false, error_messages.subset(a, b)
	end
end

function shared.LogicalComparison(l--[[#: TBaseType]], r--[[#: TBaseType]], op--[[#: string]], env)
	if l.Type == "any" then
		if op == "==" then return true -- TODO: should be nil (true | false)?
		end

		return false, error_messages.binary(op, l, r)
	end

	if l.Type == "function" then
		if op == "==" then
			local ok = shared.Equal(l, r)
			return ok
		end

		return false, error_messages.binary(op, l, r)
	end

	if l.Type == "symbol" then
		if op == "==" then return l.Data == r.Data end

		return false, error_messages.binary(op, l, r)
	end

	if l.Type == "string" then
		local a, b = l, r

		if b.Type ~= "string" then return false, error_messages.binary(op, a, b) end

		if not a.Data or not b.Data then return nil end -- undefined comparison, nil is the same as true | false
		if op == ">" then
			return a.Data > b.Data
		elseif op == "<" then
			return a.Data < b.Data
		elseif op == "<=" then
			return a.Data <= b.Data
		elseif op == ">=" then
			return a.Data >= b.Data
		elseif op == "==" then
			return a.Data == b.Data
		end

		return false, error_messages.binary(op, a, b)
	end

	if l.Type == "table" then
		if op == "==" then
			if env == "runtime" then
				if l:GetReferenceId() and r:GetReferenceId() then
					return l:GetReferenceId() == r:GetReferenceId()
				end

				return nil
			elseif env == "typesystem" then
				return shared.IsSubsetOf(l, r) and shared.IsSubsetOf(r, l)
			end
		end

		return false, error_messages.binary(op, l, r)
	end

	return false, error_messages.binary(op, l, r)
end

return shared