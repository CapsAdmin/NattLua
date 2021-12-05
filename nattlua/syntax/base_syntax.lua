--[[#local type { Token } = import_type("nattlua/lexer/token.nlua")]]

return function(syntax--[[#: literal mutable (
	{
		BinaryOperators = {[number] = {[number] = string}},
		PrefixOperators = {[number] = string},
		PostfixOperators = {[number] = string},
		PrimaryBinaryOperators = {[number] = string},
		SymbolCharacters = {[number] = string},
		KeywordValues = {[number] = string},
		Keywords = {[number] = string},
		NonStandardKeywords = {[number] = string},
		BinaryOperatorFunctionTranslate = {[string] = string} | nil,
		PostfixOperatorFunctionTranslate = {[string] = string} | nil,
		PrefixOperatorFunctionTranslate = {[string] = string} | nil,
		[string] = any,
	}
)]])
	local symbols = {}

	local function add_symbols(tbl--[[#: literal {[number] = string}]])
		if not tbl then return end

		for _, symbol in pairs(tbl) do
			if symbol:find("%p") then
				table.insert(symbols, symbol)
			end
		end
	end

	do -- extend the symbol characters from grammar rules
        local function add_binary_symbols(tbl--[[#: literal {[number] = {[number] = string}}]])
			if not tbl then return end

			for _, group in ipairs(tbl) do
				for _, token in ipairs(group) do
					if token:find("%p") then
						if token:sub(1, 1) == "R" then
							token = token:sub(2)
						end

						table.insert(symbols, token)
					end
				end
			end
		end

		add_binary_symbols(syntax.BinaryOperators)
		add_symbols(syntax.PrefixOperators)
		add_symbols(syntax.PostfixOperators)
		add_symbols(syntax.PrimaryBinaryOperators)

		for _, str in ipairs(syntax.SymbolCharacters) do
			table.insert(symbols, str)
		end

		syntax.Symbols = symbols

		function syntax.GetSymbols()
			return syntax.Symbols
		end
	end

	do
		local lookup = {}

		for k, v in pairs(syntax.BinaryOperatorFunctionTranslate or {}) do
			local a, b, c = v:match("(.-)A(.-)B(.*)")

			if a then
				if b then
					if c then
						lookup[k] = {" " .. a, b, c .. " "}
					end
				end
			end
		end

		function syntax.GetFunctionForBinaryOperator(token--[[#: Token]])
			return lookup[token.value]
		end
	end

	do
		local lookup = {}

		for k, v in pairs(syntax.PrefixOperatorFunctionTranslate or {}) do
			local a, b = v:match("^(.-)A(.-)$")

			if a then -- TODO
                if b then -- TODO
                    lookup[k] = {" " .. a, b .. " "}
				end
			end
		end

		function syntax.GetFunctionForPrefixOperator(token--[[#: Token]])
			return lookup[token.value]
		end
	end

	do
		local lookup = {}

		for k, v in pairs(syntax.PostfixOperatorFunctionTranslate or {}) do
			local a, b = v:match("^(.-)A(.-)$")

			if a then
				if b then
					lookup[k] = {" " .. a, b .. " "}
				end
			end
		end

		function syntax.GetFunctionForPostfixOperator(token--[[#: Token]])
			return lookup[token.value]
		end
	end

	do -- grammar rules
        function syntax.IsValue(token--[[#: Token]])
			if token.type == "number" or token.type == "string" then return true end
			if syntax.IsKeywordValue(token) then return true end
			if syntax.IsKeyword(token) then return false end
			if token.type == "letter" then return true end
			return false
		end

		function syntax.GetTokenType(tk--[[#: Token]])
			if tk.type == "letter" and syntax.IsKeyword(tk) then
				return "keyword"
			elseif tk.type == "symbol" then
				if syntax.IsPrefixOperator(tk) then
					return "operator_prefix"
				elseif syntax.IsPostfixOperator(tk) then
					return "operator_postfix"
				elseif syntax.GetBinaryOperatorInfo(tk) then
					return "operator_binary"
				end
			end

			return tk.type
		end

		do
			local lookup = {}

			for priority, group in ipairs(syntax.BinaryOperators or {}) do
				for _, token in ipairs(group) do
					if token:sub(1, 1) == "R" then
						lookup[token:sub(2)] = {
								left_priority = priority + 1,
								right_priority = priority,
							}
					else
						lookup[token] = {
							left_priority = priority,
							right_priority = priority,
						}
					end
				end
			end

			function syntax.GetBinaryOperatorInfo(tk--[[#: Token]])
				return lookup[tk.value]
			end
		end

		do
			local function build_lookup(tbl--[[#: literal {[number] = string}]], func_name--[[#: string]])
				local lookup = {}

				for _, v in pairs(tbl or {}) do
					lookup[v] = v
				end

				syntax[func_name] = function(token--[[#: Token]])--[[#: boolean]]
					return lookup[token.value] ~= nil
				end
			end

			build_lookup(syntax.PrimaryBinaryOperators, "IsPrimaryBinaryOperator")
			build_lookup(syntax.PrefixOperators, "IsPrefixOperator")
			build_lookup(syntax.PostfixOperators, "IsPostfixOperator")
			build_lookup(syntax.KeywordValues, "IsKeywordValue")

			do
				local keywords = {}

				for _, str in ipairs(syntax.KeywordValues) do
					table.insert(keywords, str)
				end

				for _, str in ipairs(syntax.Keywords) do
					table.insert(keywords, str)
				end

				add_symbols(keywords)
				build_lookup(keywords, "IsKeyword")
			end

			do
				local keywords = {}

				for _, str in ipairs(syntax.NonStandardKeywords) do
					table.insert(keywords, str)
				end

				build_lookup(keywords, "IsNonStandardKeyword")
			end
		end

		local function remove_duplicates_from_array(tbl--[[#: literal {[number] = string}]])
			local lookup = {}

			for _, v in ipairs(tbl) do
				lookup[v] = true
			end

			local result = {}

			for k, _ in pairs(lookup) do
				table.insert(result, k)
			end

			return result
		end

		syntax.NumberAnnotations = remove_duplicates_from_array(syntax.NumberAnnotations)
		syntax.Symbols = remove_duplicates_from_array(syntax.Symbols)

		table.sort(syntax.NumberAnnotations, function(a, b)
			return #a > #b
		end)

		table.sort(syntax.Symbols, function(a, b)
			return #a > #b
		end)

	end
end
