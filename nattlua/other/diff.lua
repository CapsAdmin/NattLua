local table = _G.table
local math = _G.math
local setmetatable = _G.setmetatable
local ipairs = _G.ipairs
local assert = _G.assert
local MOD = {}

local function tokenize(text)
	local chars = {}

	for i = 1, #text do
		chars[i] = text:sub(i, i)
	end

	return chars
end

local mt_tbl = {
	__index = function(t, k)
		t[k] = 0
		return 0
	end,
}
local mt_C = {
	__index = function(t, k)
		local tbl = {}
		setmetatable(tbl, mt_tbl)
		t[k] = tbl
		return tbl
	end,
}

local function quick_LCS(t1, t2)
	local m = #t1
	local n = #t2
	-- Build matrix on demand
	local C = {}
	setmetatable(C, mt_C)
	local max = math.max

	for i = 1, m + 1 do
		local ci1 = C[i + 1]
		local ci = C[i]

		for j = 1, n + 1 do
			if t1[i - 1] == t2[j - 1] then
				ci1[j + 1] = ci[j] + 1
			else
				ci1[j + 1] = max(ci1[j], ci[j + 1])
			end
		end
	end

	return C
end

-- ANSI color codes
local reset = "\027[0m"
local green = "\027[32m" -- for additions
local red = "\027[31m" -- for deletions
local dim = "\027[2m" -- for whitespace visualization
local function make_whitespace_visible(str)
	str = str:gsub(" ", dim .. "⣿" .. reset) -- middle dot for spaces
	str = str:gsub("\t", dim .. "\\t\t" .. reset) -- arrow for tabs
	str = str:gsub("\n", dim .. "\\n\n" .. reset) -- pilcrow for newlines
	str = str:gsub("\r", dim .. "\\r\r" .. reset) -- return symbol for carriage returns
	return str
end

local function format_as_ascii(tokens)
	local diff_buffer = ""

	-- Function to make whitespace visible
	for i, token_record in ipairs(tokens) do
		local token = token_record[1]
		local status = token_record[2]

		-- Make whitespace visible for all tokens
		if status == "in" then
			diff_buffer = diff_buffer .. green .. make_whitespace_visible(token) .. reset
		elseif status == "out" then
			diff_buffer = diff_buffer .. red .. make_whitespace_visible(token) .. reset
		else
			diff_buffer = diff_buffer .. token
		end
	end

	return diff_buffer
end

-- this will scan the LCS matrix backwards and build the diff output recursively.
local function get_diff(rev_diff, C, old, new, i, j)
	local old_i = old[i]
	local new_j = new[j]

	if i >= 1 and j >= 1 and old_i == new_j then
		if old_i then table.insert(rev_diff, {old_i, "same"}) end

		return get_diff(rev_diff, C, old, new, i - 1, j - 1)
	else
		local Cij1 = C[i][j - 1]
		local Ci1j = C[i - 1][j]

		if j >= 1 and (i == 0 or Cij1 >= Ci1j) then
			table.insert(rev_diff, {new_j, "in"})
			return get_diff(rev_diff, C, old, new, i, j - 1)
		elseif i >= 1 and (j == 0 or Cij1 < Ci1j) then
			table.insert(rev_diff, {old_i, "out"})
			return get_diff(rev_diff, C, old, new, i - 1, j)
		end
	end
end

local function diff_tokens(old, new)
	-- First, compare the beginnings and ends of strings to remove the common
	-- prefix and suffix.  Chances are, there is only a small number of tokens
	-- in the middle that differ, in which case  we can save ourselves a lot
	-- in terms of LCS computation.
	local prefix = "" -- common text in the beginning
	local suffix = "" -- common text in the end
	while old[1] and old[1] == new[1] do
		local token = table.remove(old, 1)
		table.remove(new, 1)
		prefix = prefix .. token
	end

	while old[#old] and old[#old] == new[#new] do
		local token = table.remove(old)
		table.remove(new)
		suffix = token .. suffix
	end

	-- Setup a table that will store the diff (an upvalue for get_diff). We'll
	-- store it in the reverse order to allow for tail calls.  We'll also keep
	-- in this table functions to handle different events.
	local rev_diff = {}
	-- Put the suffix as the first token (we are storing the diff in the
	-- reverse order)
	table.insert(rev_diff, {suffix, "same"})
	-- Then call it.
	get_diff(rev_diff, quick_LCS(old, new), old, new, #old + 1, #new + 1)
	-- Put the prefix in at the end
	table.insert(rev_diff, {prefix, "same"})
	-- Reverse the diff.
	local diff = {}

	for i = #rev_diff, 1, -1 do
		table.insert(diff, rev_diff[i])
	end

	return diff
end

function MOD.diff(old, new)
	local d = diff_tokens(tokenize(old), tokenize(new))
	return format_as_ascii(d)
end

return MOD
