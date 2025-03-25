local cli = require("nattlua.cli.init")
local colors = require("nattlua.cli.colors")
local fs = require("nattlua.other.fs")
local path = require("nattlua.other.path")
local TEST_DIR = "./test/tests/cli_temp"
local CONFIG_FILE = TEST_DIR .. "/nlconfig.lua"
local SAMPLE_FILE = TEST_DIR .. "/sample.nlua"
local OUTPUT_FILE = TEST_DIR .. "/output.lua"
-- Disable colors for tests
colors.set_enabled(false)

-- Setup test environment
local function setup()
	-- Create test directory
	fs.create_directory(TEST_DIR)
	-- Create a sample NattLua file
	fs.write(
		SAMPLE_FILE,
		[[
--!strict
local function add(a: number, b: number): number
    return a + b
end

return {
    add = add,
}
]]
	)
	-- Create a test config file
	fs.write(
		CONFIG_FILE,
		[[
local config = {}

config.compiler = {
    type_annotations = true,
}

config.emit = {
    preserve_whitespace = true,
}

config.commands = {
    test_custom = function(...)
        return "test_custom", {...}
    end,
}

return config
]]
	)
end

-- Clean up test environment
local function teardown()
	if fs.is_file(SAMPLE_FILE) then fs.remove_file(SAMPLE_FILE) end

	if fs.is_file(CONFIG_FILE) then fs.remove_file(CONFIG_FILE) end

	if fs.is_file(OUTPUT_FILE) then fs.remove_file(OUTPUT_FILE) end

	if fs.is_directory(TEST_DIR) then fs.remove_directory(TEST_DIR) end
end

-- Capture output
local function capture_output(func, ...)
	local original_write = io.write
	local original_stderr = io.stderr
	local output = {}
	local stderr_output = {}
	io.write = function(...)
		for i = 1, select("#", ...) do
			table.insert(output, tostring(select(i, ...)))
		end
	end
	-- Create a temporary stderr replacement with a write method
	local temp_stderr = {}

	function temp_stderr:write(...)
		for i = 1, select("#", ...) do
			table.insert(stderr_output, tostring(select(i, ...)))
		end
	end

	io.stderr = temp_stderr
	local success, result = pcall(func, ...)
	io.write = original_write
	io.stderr = original_stderr
	return table.concat(output), table.concat(stderr_output), success, result
end

-- Test helpers
local function assert_contains(haystack, needle)
	assert(
		haystack:find(needle, 1, true),
		"Expected to find '" .. needle .. "' in '" .. haystack .. "'"
	)
end

test("help", function()
	local stdout, stderr = capture_output(function()
		cli.help()
	end)
	assert(stdout ~= "", "Help output should not be empty")
	assert(stdout:find("Usage"), "Help output should contain 'Usage'")
	assert(stdout:find("Commands"), "Help output should contain 'Commands'")
end)

test("version", function()
	local stdout, stderr = capture_output(function()
		cli.version()
	end)
	assert(stdout ~= "", "Version output should not be empty")
	assert(stdout:find("NattLua version"), "Version output should contain version info")
	assert(stdout:find("LuaJIT"), "Version output should mention LuaJIT")
end)

test(
	"load config",
	function()
		local config = cli.load_config(CONFIG_FILE)
		assert(type(config) == "table", "Config should be a table")
		assert(type(config.compiler) == "table", "Config should have compiler options")
		assert(type(config.emit) == "table", "Config should have emit options")
		assert(type(config.commands) == "table", "Config should have commands")
		assert(
			type(config.commands.test_custom) == "function",
			"Config should have test_custom command"
		)
	end,
	setup,
	teardown
)

test(
	"custom command",
	function()
		-- Since we can't easily test command redirection from nlconfig.lua,
		-- we'll just test the custom command function directly
		local config = cli.load_config(CONFIG_FILE)
		local cmd_name, args = config.commands.test_custom("arg1", "arg2")
		assert(cmd_name == "test_custom", "Custom command name should be returned")
		assert(#args == 2, "Custom command should get 2 arguments")
		assert(args[1] == "arg1", "First argument should be 'arg1'")
		assert(args[2] == "arg2", "Second argument should be 'arg2'")
	end,
	setup,
	teardown
)

test("colors", function()
	local colors = require("nattlua.cli.colors")
	-- Test with colors enabled
	colors.set_enabled(true)
	local text = "test"
	local colored_text = colors.red(text)
	assert(colored_text ~= text, "Colored text should be different from original")
	assert(colored_text:find("\27"), "Red text should contain ANSI escape code")
	assert(colored_text:find("0m"), "Colored text should contain reset code")
	-- Test with colors disabled
	colors.set_enabled(false)
	colored_text = colors.red(text)
	assert(colored_text == text, "With colors disabled, text should be unchanged")
	-- Test other color functions
	colors.set_enabled(true)
	assert(colors.green(text) ~= text, "Green text should be colored")
	assert(colors.blue(text) ~= text, "Blue text should be colored")
	assert(colors.yellow(text) ~= text, "Yellow text should be colored")
	assert(colors.cyan(text) ~= text, "Cyan text should be colored")
	assert(colors.magenta(text) ~= text, "Magenta text should be colored")
	-- Test style functions
	assert(colors.bold(text) ~= text, "Bold text should be styled")
	assert(colors.underline(text) ~= text, "Underlined text should be styled")
	-- Reset for other tests
	colors.set_enabled(true)
end)
