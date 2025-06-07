local Compiler = require("nattlua.compiler")
local fs = require("nattlua.other.fs")
local path = require("nattlua.other.path")
local colors = require("nattlua.cli.colors")
local version = "forever pre alpha"
local DEFAULT_CONFIG_NAME = "nlconfig.lua"
local config_path = "./" .. DEFAULT_CONFIG_NAME

local function parse_args(args, allowed_options)
	local options = {}
	local parsed_args = {}

	if allowed_options then
		for _, option in ipairs(allowed_options) do
			options[option.name] = false
		end
	end

	for _, arg in ipairs(args) do
		if arg:sub(1, 2) == "--" then
			local option = arg:sub(3)
			local val = true

			if arg:sub(-#"=true") == "=true" then
				arg = arg:sub(1, -#"=true" - 1)
				val = true
			elseif arg:sub(-#"=false") == "=false" then
				arg = arg:sub(1, -#"=false" - 1)
				val = false
			end

			if allowed_options and options[option] == nil then
				error("unknown option " .. option)
			end

			options[option] = val
		else
			table.insert(parsed_args, arg)
		end
	end

	return parsed_args, options
end

local function get_compiler_config(config)
	local compiler_config = {}

	for k, v in pairs(config.lexer) do
		compiler_config[k] = v
	end

	for k, v in pairs(config.parser) do
		compiler_config[k] = v
	end

	for k, v in pairs(config.analyzer) do
		compiler_config[k] = v
	end

	for k, v in pairs(config.emitter) do
		compiler_config[k] = v
	end

	return compiler_config
end

local config = {}
config.analyzer = {
	inline_require = true,
}
config.parser = {
	skip_import = true,
}
config.lexer = {}
config.emitter = {
	preserve_whitespace = false,
	string_quote = "\"",
	no_semicolon = true,
	type_annotations = "explicit",
	force_parenthesis = true,
	trailing_newline = true,
	comment_type_annotations_in_lua_files = true,
}
config.commands = {}
local cli = {}
config.commands["run"] = {
	description = "Run a NattLua file",
	usage = "nattlua run <file> [args...]",
	options = {},
	cb = function(args)
		assert(Compiler.LoadFile(args[1]))(table.unpack(args, 2))
	end,
}
config.commands["check"] = {
	description = "type check a nattlua or lua script",
	usage = "nattlua check <file>",
	cb = function(args, options, config, cli)
		require("test.helpers.profiler").Start()
		args[1] = args[1] or "./*"

		if #args == 1 and args[1] == "-" then
			local input = io.read("*all")
			io.write(assert(Compiler.New(input, "stdin-", config):Analyze()))
		else
			for _, path in ipairs(
				cli.get_files({path = args, blacklist = config.ignorefiles, ext = {".lua", ".nlua"}})
			) do
				assert(Compiler.FromFile(path, config):Analyze())
			end
		end

		require("test.helpers.profiler").Stop()
	end,
}
config.commands["build"] = {
	description = "Build a NattLua file to Lua",
	usage = "nattlua build <input> <output> [options]",
	cb = function(args, options, config, cli)
		local input_path = args[1]
		local output_path = args[2]

		if not input_path or not output_path then
			cli.print_error("Missing input or output path")
			io.write(config.commands.build.usage .. "\n")
			os.exit(1)
		end

		if not fs.is_file(input_path) then
			cli.print_error("Input file not found: " .. input_path)
			os.exit(1)
		end

		config.parser.skip_import = false
		local lua_code = assert(Compiler.FromFile(input_path, config)):Emit()
		local file, err = io.open(output_path, "w")

		if not file then
			cli.print_error("Failed to open output file: " .. tostring(err))
			os.exit(1)
		end

		file:write(lua_code)
		file:close()
		cli.print_success("Built " .. input_path .. " -> " .. output_path)
	end,
}
config.commands["fmt"] = {
	description = "Format NattLua files",
	usage = "nattlua fmt <file|directory> [options]",
	options = {
		{name = "check", description = "checks if the files are formated"},
	},
	cb = function(args, options, config, cli)
		args[1] = args[1] or "./*"

		if #args == 1 and args[1] == "-" then
			local input = io.read("*all")
			io.write(assert(Compiler.New(input, "stdin-", config):Emit()))
		else
			for _, path in ipairs(
				cli.get_files({path = args, blacklist = config.ignorefiles, ext = {".lua", ".nlua"}})
			) do
				local old = config.emitter.comment_type_annotations
				config.emitter.comment_type_annotations = config.emitter.comment_type_annotations_in_lua_files and
					path:sub(-#".lua") == ".lua"
				local new_lua_code = assert(Compiler.FromFile(path, config):Emit())
				config.emitter.comment_type_annotations = old

				if options.check then
					local A = new_lua_code
					local B = fs.read(path)

					if A ~= B then
						local a = os.tmpname()
						local b = os.tmpname()

						do
							local f = assert(io.open(a, "w"))
							f:write(A)
							f:close()
						end

						do
							local f = assert(io.open(b, "w"))
							f:write(B)
							f:close()
						end

						os.execute("git --no-pager diff --no-index " .. a .. " " .. b)
					end
				else
					fs.write(path, new_lua_code)
				end
			end
		end
	end,
}
config.commands["init"] = {
	{
		description = "Initialize a new NattLua project",
		usage = "nattlua init [directory]",
		options = {},
	},
	cb = function(args, options, cli)
		local directory = args[1] or "."

		if not fs.is_directory(directory) then
			local create_result = fs.create_directory(directory)

			if not create_result then
				cli.print_error("Failed to create directory: " .. directory)
				os.exit(1)
			end
		end

		local config_path = path.Join(directory, DEFAULT_CONFIG_NAME)

		if fs.is_file(config_path) then
			cli.print_warning("Config file already exists: " .. config_path)
			io.write("Overwrite? (y/N) ")
			local answer = io.read("*l")

			if answer ~= "y" and answer ~= "Y" then return end
		end

		local template = [[
    -- NattLua Configuration File
    
    local config = {}
    config.parser = {
        inline_require = false,
    }

	config.emitter = {
		type_annotations = true,
        preserve_whitespace = true,
        string_quote = "\"",
        no_semicolon = true,
        force_parenthesis = true,
        max_line_length = 80,
    }
    
    config.analyzer = {
        working_directory = ".",
    }
    
        config.commands["build"] = {
			description = "Build a NattLua file to Lua",
			usage = "nattlua build <input> <output> [options]",
			options = {
				{name = "minify", description = "Minify the output"},
				{name = "no-comments", description = "Remove comments from output"},
				{name = "config", description = "Specify a config file path", arg = "path"},
			},
			cb = function(args, options, cli) end,
		}
    }
    
    return config
    ]]
		local result, err = fs.write(config_path, template)

		if not result then
			cli.print_error("Failed to write config file: " .. tostring(err))
			os.exit(1)
		end

		-- Create a basic project structure
		fs.create_directory(path.Join(directory, "src"))
		fs.create_directory(path.Join(directory, "test"))
		-- Create a basic hello world file
		local main_file = path.Join(directory, "src", "main.nlua")
		fs.write(
			main_file,
			[[
    local function greet(name: string): string
        return "Hello, " .. name .. "!"
    end
    
    print(greet("NattLua"))
    ]]
		)
		-- Create a basic test file
		local test_file = path.Join(directory, "test", "test_main.nlua")
		fs.write(
			test_file,
			[[
    local main = require("src.main")
    
    assert(main.greet("Test") == "Hello, Test!")
    print("Tests passed!")
    ]]
		)
		cli.print_success("Initialized NattLua project in " .. directory)
		io.write("\nNext steps:\n")
		io.write("  1. Edit " .. config_path .. " to configure your project\n")
		io.write("  2. Add your code in the src directory\n")
		io.write("  3. Run your code with: nattlua run " .. main_file .. "\n")
	end,
}
config.commands["lsp"] = {
	description = "Start the NattLua language server",
	usage = "nattlua lsp",
	options = {
		{name = "stdio", description = "Use stdio for communication"},
		{name = "port", description = "TCP port to listen on", arg = "number"},
	},
	cb = function(args, options, cli)
		local options = {
			stdio = options.stdio,
			port = tonumber(options.port) or 8080,
		}
		require("language_server.main")(options)
	end,
}

function cli.print_error(msg)
	io.stderr:write(colors.red("error") .. ": " .. msg .. "\n")
end

function cli.print_warning(msg)
	io.stderr:write(colors.yellow("warning") .. ": " .. msg .. "\n")
end

function cli.print_success(msg)
	io.write(colors.green("success") .. ": " .. msg .. "\n")
end

function cli.version()
	io.write("NattLua version " .. colors.cyan(version) .. "\n")
	io.write("LuaJIT " .. jit.version .. "\n")
end

local function sorted_pairs(tbl)
	local keys = {}

	for k in pairs(tbl) do
		table.insert(keys, k)
	end

	table.sort(keys)
	local i = 0
	return function()
		i = i + 1

		if keys[i] then return keys[i], tbl[keys[i]] end
	end
end

function cli.help(command)
	local commands = cli.get_config().commands

	if command and commands[command] then
		local cmd = commands[command]
		io.write(colors.bold(cmd.description) .. "\n\n")
		io.write(colors.bold("Usage:") .. "\n  " .. cmd.usage .. "\n\n")

		if #cmd.options > 0 then
			io.write(colors.bold("Options:") .. "\n")

			for _, option in ipairs(cmd.options) do
				local option_text = "  " .. option.name

				if option.arg then
					option_text = option_text .. " <" .. option.arg .. ">"
				end

				io.write(colors.yellow(option_text) .. "\n    " .. option.description .. "\n")
			end

			io.write("\n")
		end
	else
		cli.version()
		io.write("\n" .. colors.bold("Usage:") .. "\n  nattlua <command> [options]\n\n")
		io.write(colors.bold("Commands:") .. "\n")

		for name, cmd in sorted_pairs(commands) do
			io.write(
				"  " .. colors.yellow(name) .. "\n    " .. (
						cmd.description or
						"*no description*"
					) .. "\n"
			)
		end

		io.write(
			"\nRun " .. colors.yellow("nattlua help <command>") .. " for more information about a command.\n"
		)
	end
end

local function copy_and_deep_merge(a, b)
	local result = {}

	for k, v in pairs(a) do
		if type(v) == "table" then
			result[k] = copy_and_deep_merge(v, {}) -- Deep copy the table
		else
			result[k] = v
		end
	end

	-- Then merge in values from 'b'
	for k, v in pairs(b) do
		if type(v) == "table" and type(result[k]) == "table" then
			-- Both 'a' and 'b' have a table at this key, so merge them recursively
			result[k] = copy_and_deep_merge(result[k], v)
		elseif type(v) == "table" then
			-- 'b' has a table but 'a' doesn't have this key or has a non-table value
			result[k] = copy_and_deep_merge({}, v) -- Deep copy the table from 'b'
		else
			-- 'b' has a non-table value, which takes precedence
			result[k] = v
		end
	end

	return result
end

function cli.get_config()
	if fs.is_file(config_path) then
		io.write("loading config ", config_path, "\n")
		return copy_and_deep_merge(config, cli.load_config(config_path))
	end

	return copy_and_deep_merge(config, {})
end

function cli.load_config(config_path)
	config_path = config_path or DEFAULT_CONFIG_NAME

	if not fs.is_file(config_path) then
		if config_path ~= DEFAULT_CONFIG_NAME then
			cli.print_error("Config file not found: " .. config_path)
			os.exit(1)
		end

		return {}
	end

	local load_func, err = loadfile(config_path)

	if not load_func then
		cli.print_error("Failed to load config: " .. err)
		os.exit(1)
	end

	local success, config = pcall(load_func)

	if not success then
		cli.print_error("Failed to execute config: " .. config)
		os.exit(1)
	end

	if type(config) ~= "table" then
		cli.print_error("Config must return a table")
		os.exit(1)
	end

	return config
end

function cli.main(...)
	local args = {...}

	if #args == 0 then
		cli.help()
		os.exit(0)
	end

	local command = args[1]
	table.remove(args, 1)

	if command == "help" then
		cli.help(args)
		os.exit(0)
	end

	if command == "version" or command == "-v" or command == "--version" then
		cli.version()
		os.exit(0)
	end

	local config = cli.get_config()

	if not config.commands[command] then
		cli.print_error("Unknown command: " .. command)
		cli.help()
		os.exit(1)
	end

	local ok, args, options = pcall(parse_args, args, config.commands[command].options)

	if not ok then
		cli.print_error("Failed to parse command " .. command .. ": " .. args)
		os.exit(1)
	end

	local ok, err = xpcall(config.commands[command].cb, debug.traceback, args, options, config, cli)

	if not ok then
		cli.print_error("Failed to execute command " .. command .. ": " .. err)
		os.exit(1)
	end
end

function cli.get_files(tbl)
	local out = {}

	if type(tbl.path) == "table" then
		for _, path in ipairs(tbl.path) do
			for i, v in ipairs(
				cli.get_files({
					path = path,
					ext = tbl.ext,
					blacklist = tbl.blacklist,
				})
			) do
				table.insert(out, v)
			end
		end

		return out
	end

	if fs.is_file(tbl.path) then
		out[1] = tbl.path
		return out
	end

	local function is_path_allowed(path)
		if not tbl.blacklist then return true end

		for _, pattern in ipairs(tbl.blacklist) do
			if path:find(pattern) then return false end
		end

		return true
	end

	local function is_ext_allowed(path)
		if not tbl.ext then return true end

		for i, ext in ipairs(tbl.ext) do
			if path:sub(-#ext) == ext then return true end
		end

		return false
	end

	if tbl.path:sub(-2) == "/*" then
		for _, path in ipairs(assert(fs.get_files_recursive(tbl.path:sub(1, -2)))) do
			if is_ext_allowed(path) and is_path_allowed(path) then
				table.insert(out, path)
			end
		end
	else
		for _, path in ipairs(assert(fs.get_files(tbl.path))) do
			path = tbl.path .. path

			if is_ext_allowed(path) and is_path_allowed(path) then
				table.insert(out, path)
			end
		end
	end

	return out
end

return cli
