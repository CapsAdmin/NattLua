local LSPClient = require("test.helpers.lsp_client")
local lsp = require("language_server.lsp")
local fs = require("nattlua.other.fs")
local diff = require("nattlua.other.diff")
local last_written_content = {}
local old_fs_write = fs.write
local old_fs_read = fs.read
fs.write = function(path, content)
	last_written_content[path] = content
end
fs.read = function(path)
	return last_written_content[path]
end

local function test(marked_code, config)
	-- Parse >>...<< markers to extract code and expectations
	local code = marked_code:gsub(">>", ""):gsub("<<", "")
	local expected_removed = {}

	for removed in marked_code:gmatch(">>(.-)<<") do
		local trimmed = removed:match("^%s*(.-)%s*$")

		if trimmed ~= "" then table.insert(expected_removed, trimmed) end
	end

	if #expected_removed == 0 then expected_removed = nil end

	local without_marked = marked_code:gsub(">>.-<<", "")
	local expected_kept = {}

	for line in without_marked:gmatch("[^\n]+") do
		local trimmed = line:match("^%s*(.-)%s*$")

		if trimmed ~= "" and trimmed ~= "--ANALYZE" then
			table.insert(expected_kept, trimmed)
		end
	end

	if #expected_kept == 0 then expected_kept = nil end

	local client = LSPClient.New()
	client:SetWorkingDirectory("/workspace")
	local root_uri = "file:///workspace"
	client:Initialize(lsp, root_uri)
	local file_uri = root_uri .. "/test.nlua"
	local file_path = "/workspace/test.nlua"
	-- initially "write" it so fs.read works
	last_written_content[file_path] = code

	lsp.editor_helper:SetConfigFunction(function(path)
		local cfg = config or
			{
				analyzer = {remove_unused = true},
				emitter = {remove_unused = true},
			}
		cfg.lsp = {entry_point = path}
		return {
			["get-compiler-config"] = function()
				return cfg
			end,
		}
	end)

	client:Notify(
		lsp,
		"textDocument/didOpen",
		{
			textDocument = {
				uri = file_uri,
				languageId = "nattlua",
				version = 1,
				text = code,
			},
		}
	)
	client:Notify(lsp, "textDocument/didSave", {textDocument = {uri = file_uri}})
	local saved_code = last_written_content[file_path]
	local expected_output = without_marked

	local function fail(msg)
		print(msg)
		print("DIFF (expected vs actual):")
		print(diff.diff(expected_output, saved_code or ""))
		error(msg, 2)
	end

	if expected_removed then
		assert(saved_code, "File should have been written to")

		for _, s in ipairs(expected_removed) do
			if saved_code:find(s, 1, true) then
				fail("Should have removed '" .. s .. "'")
			end
		end
	end

	if expected_kept then
		assert(
			saved_code or not expected_removed,
			"File should have been written to if changes expected"
		)

		if saved_code then
			for _, s in ipairs(expected_kept) do
				if not saved_code:find(s, 1, true) then
					fail("Should have kept '" .. s .. "'")
				end
			end
		end
	end
end

test([[
	local a = 1
	>>local b = 2<<
	math.sin(a)
]])
test([[
	local a = 1
	>>local b = 2<<
	math.sin(a)
]])
test([[
	local a = require("module_a")
	>>local b = require("module_b")<<
	math.sin(a)
]])
test([[
	>>local x = require("string")<<
	>>local a = 2222<<
]])
test([[
	local function foo() return 1 end
	>>local function bar() return 2 end<<
	math.sin(foo())
]])
test([===[
>>local abc<<
]===])
test([[
	>>local table_insert = table.insert<<
	return function()
		local t = {}
		table.insert(t, 1)
		return t[1]
	end
]])
-- this is an exception, local x = 1 is not used anywhere because if false then, but it should not be removed
test([===[
	local x = 1
	if false then x = 2 return x end
]===])
test([[
	local table_insert = table.insert
	return function()
		local t = {}
		table_insert(t, 1)
		return t[1]
	end
]])
test([[
	>>local table_insert = 1<<
	return function()
		local t = {}
		table.insert(t, 1)
		return t[1]
	end
]])
test(
	[[
		local a = 1
		local b = 2
		math.sin(a)
	]],
	{
		analyzer = {remove_unused = false},
		emitter = {remove_unused = false},
	}
)
test(
	[[
		local a = 1
		local b = os.clock()
		math.sin(a)
	]],
	{
		analyzer = {remove_unused = true},
		emitter = {remove_unused = true},
	}
)

-- nlua files should NOT have type annotations converted to comments on save
do
	local client = LSPClient.New()
	client:SetWorkingDirectory("/workspace")
	local root_uri = "file:///workspace"
	client:Initialize(lsp, root_uri)
	local file_uri = root_uri .. "/test.nlua"
	local file_path = "/workspace/test.nlua"
	local code = [[
		local a: number = 1
		local b: number = 2
		math.sin(a)
	]]
	last_written_content[file_path] = code

	lsp.editor_helper:SetConfigFunction(function(path)
		return {
			["get-compiler-config"] = function()
				return {
					analyzer = {remove_unused = true},
					emitter = {remove_unused = true},
					lsp = {entry_point = path},
				}
			end,
		}
	end)

	client:Notify(
		lsp,
		"textDocument/didOpen",
		{
			textDocument = {
				uri = file_uri,
				languageId = "nattlua",
				version = 1,
				text = code,
			},
		}
	)
	client:Notify(lsp, "textDocument/didSave", {textDocument = {uri = file_uri}})
	local saved_code = last_written_content[file_path]
	assert(saved_code, "File should have been written to")

	-- nlua files should keep type annotations as-is (not wrapped in --[[# ]])
	if saved_code:find("--[[#", 1, true) then
		print("CODE:\n" .. saved_code)
		error(
			"nlua file should NOT have type annotations converted to comments, but found --[[# in output"
		)
	end

	-- type annotations should be preserved
	if not saved_code:find(": number", 1, true) then
		print("CODE:\n" .. saved_code)
		error("nlua file should preserve type annotations like ': number'")
	end

	-- unused variable b should still be removed
	if saved_code:find("local b", 1, true) then
		print("CODE:\n" .. saved_code)
		error("unused variable b should have been removed")
	end
end

-- local function used inside a table member function should NOT be removed
test([[
	local M = {}
	local function helper()
		return 42
	end
	function M.foo()
		return helper()
	end
	return M
]])
-- local function used inside a table member function should NOT be removed
-- (without returning M - closer to ljsocket pattern where M might not be externally used)
test([[
	local bit = require("bit")
	local M = {}
	local function flags_to_table(flags: ref number, valid_flags: ref {[string] = number}, operation: ref function=(number, number)>(number))
		if not flags then return nil end
		operation = operation or bit.band
		local out = {}
		for k, v in pairs(valid_flags) do
			if operation(flags, v) > 0 then out[k] = true end
		end
		return out
	end
	function M.poll(timeout: nil | number)
		return flags_to_table(1, {a = 1}, bit.bor)
	end
]])

-- Format (formatOnSave) should NOT do remove_unused; only the save path should
do
	local client = LSPClient.New()
	client:SetWorkingDirectory("/workspace")
	local root_uri = "file:///workspace"
	client:Initialize(lsp, root_uri)
	local file_uri = root_uri .. "/test.nlua"
	local file_path = "/workspace/test.nlua"
	local code = [[
		--ANALYZE
		local a = 1
		local unused = 2
		math.sin(a)
	]]
	last_written_content[file_path] = code
	lsp.editor_helper.workspace_config = {removeUnusedOnSave = true}

	lsp.editor_helper:SetConfigFunction(function(path)
		return {
			["get-compiler-config"] = function()
				return {
					lsp = {entry_point = path},
				}
			end,
		}
	end)

	client:Notify(
		lsp,
		"textDocument/didOpen",
		{
			textDocument = {
				uri = file_uri,
				languageId = "nattlua",
				version = 1,
				text = code,
			},
		}
	)
	-- Format should NOT remove unused vars (that's what save does)
	local formatted = lsp.editor_helper:Format(code, file_path)
	assert(formatted, "Format should return code")

	if not formatted:find("unused", 1, true) then
		print("CODE:\n" .. formatted)
		error(
			"Format() should NOT remove unused variables (removeUnusedOnSave should only apply on save, not format)"
		)
	end

	-- But explicit remove_unused via extra_emitter_config (code action) should work
	local with_removal = lsp.editor_helper:Format(code, file_path, {remove_unused = true})
	assert(with_removal, "Format with remove_unused should return code")

	if with_removal:find("unused", 1, true) then
		print("CODE:\n" .. with_removal)
		error("Format(code, path, {remove_unused=true}) should remove unused variables")
	end

	lsp.editor_helper.workspace_config = nil
end

fs.write = old_fs_write
fs.read = old_fs_read