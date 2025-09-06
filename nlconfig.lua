local config = {}
config.entry_point = "./nattlua.lua"
config.ignorefiles = {
	"test_focus_result%.lua",
	"test_focus%.lua",
	"build_output%.lua",
	"nattlua_for_ai%.lua",
	"language_server/json%.lua",
	"examples/benchmarks/temp/10mb%.lua",
	"examples/projects/luajit/out%.lua",
	"examples/projects/love2d/love%-api/.*",
	"test/tests/nattlua/analyzer/file_importing/deep_error/.*",
}
config.commands = {}

do -- custom commands specific for nattlua
	config.commands["build-vscode"] = {
		description = "Build and install the NattLua VSCode extension",
		cb = function()
			os.execute(
				"cd vscode_extension && yarn && yarn build && code --install-extension nattlua-0.0.1.vsix"
			)
		end,
	}
	config.commands["install"] = {
		description = "Install NattLua binary to ~/.local/bin (Linux only)",
		cb = function()
			config.commands.build.cb({"fast"})
			os.execute("mkdir -p ~/.local/bin")
			os.execute("cp build_output.lua ~/.local/bin/nattlua")
			os.execute("chmod +x ~/.local/bin/nattlua")
		end,
	}
	config.commands["test"] = {
		description = "Run NattLua test suite with optional test filter",
		cb = function(args)
			require("test.run")(args[1])
			os.exit() -- no need to wait for gc to complete
		end,
	}
	config.commands["remove-coverage"] = {
		description = "Remove all .coverage files from the project directory",
		cb = function(args)
			local util = require("examples.util")
			local paths = util.GetFilesRecursively("./", "lua.coverage")

			for _, path in ipairs(paths) do
				os.remove(path)
			end
		end,
	}
	config.commands["coverage"] = {
		description = "Generate code coverage reports by running tests with instrumentation",
		cb = function(args)
			local covered = {}
			local fs = require("nattlua.other.fs")
			local preprocess = require("test.helpers.preprocess")
			local coverage = require("test.helpers.coverage")
			preprocess.Init(
				(
					function()
						local tbl = {}

						for k, v in pairs(package.loaded) do
							if k:find("nattlua") then table.insert(tbl, k) end
						end

						return tbl
					end
				)()
			)

			function preprocess.Preprocess(code, name, path, from)
				if from == "package" then
					if path and path:find("^nattlua/") then
						covered[name] = path
						return coverage.Preprocess(code, name)
					end
				end

				return code
			end

			require("test.run")()

			for name, path in pairs(covered) do
				local content = coverage.Collect(name)

				if content then
					local f = assert(io.open(path .. ".coverage", "w"))
					f:write(content)
					f:close()
				else
					print("unable to find coverage information for " .. name)
				end
			end
		end,
	}
	config.commands["build-markdown"] = {
		description = "Generate markdown documentation for AI assistants (modes: all, core, minimal, tests)",
		cb = function(args)
			local mode = args[1]
			-- this is just for something like a single file you can paste into gemini 1.5 or chatgpt. gemini's ai studio interface kind of doesn't work with many files, so this is easier.
			local paths = {}

			for path in (
				io.popen("git ls-tree --full-tree --name-only -r HEAD"):read("*a")
			):gmatch("(.-)\n") do
				if path:find("%.lua") or path:find("%.nlua") then
					table.insert(paths, path)
				end
			end

			if mode == "all" then

			elseif mode == "core" or mode == "minimal" then
				local new_paths = {}

				for _, path in ipairs(paths) do
					if path:sub(1, #"nattlua/") == "nattlua/" then
						table.insert(new_paths, path)
					end
				end

				paths = new_paths
			elseif mode == "tests" then
				local new_paths = {}

				for _, path in ipairs(paths) do
					if path:sub(1, #"test/tests/nattlua/analyzer/") == "test/tests/nattlua/analyzer/" then
						table.insert(new_paths, path)
					end
				end

				paths = new_paths
			end

			local summarize = {
				["other/fs.lua"] = "a file system library, very similar to lua's io library",
				["other/utf8.lua"] = "a polyfill utf8 library",
				["other/bit.lua"] = "a polyfill bit library",
				["nattlua/parser/teal.lua"] = "parser code for dealing with teal syntax, not very relevant",
				["nattlua/definitions/glua.nlua"] = "garry's mode lua type defintions, not very relevant",
				["nattlua/cli/"] = "code for handling command line arguments, not very relevant",
				["nattlua/lexer/"] = "tokenizes the code into a table",
				["nattlua/emitter/"] = "emits a root node back to lua code",
				["nattlua/parser/"] = "parses lua code into an AST",
			}
			local tokens = {}
			local f = io.open("nattlua.md", "w")

			for _, path in ipairs(paths) do
				local str

				if mode == "minimal" then
					for k, v in pairs(summarize) do
						if path:find(k, nil, true) then
							str = v

							break
						end
					end
				end

				if not str then
					str = io.open(path):read("*a")
					str = str:gsub("\n+", "\n")
					str = str:gsub("\t", " ")
				end

				local ext = path:match(".+%.(.+)")
				str = "### " .. path .. " ###\n" .. "```" .. ext .. "\n" .. str .. "\n```\n"
				f:write(str)
				table.insert(tokens, {path = path, count = #str / 2.5})
			end

			f:close()

			table.sort(tokens, function(a, b)
				return a.count < b.count
			end)

			local total_tokens = 0

			for path, info in ipairs(tokens) do
				print("added " .. info.path .. ": " .. info.count .. " tokens")
				total_tokens = total_tokens + info.count
			end

			print("roughly " .. math.floor(total_tokens) .. "k tokens for claude")
		end,
	}
end

do -- these override existing commands and should probably be made more generic
	config.commands["build"] = {
		description = "Build NattLua into a single distributable Lua file with optional modes (fast)",
		cb = function(args)
			local mode = args[1]
			local Compiler = require("nattlua.compiler")
			io.write("parsing " .. config.entry_point)
			local c = assert(
				Compiler.New(
					[[
					_G.ARGS = {...}
		
					if _G.IMPORTS then
						for k, v in pairs(_G.IMPORTS) do
							if not k:find("/") then package.preload[k] = v end
						end
				
						package.preload.nattlua = package.preload["nattlua.init"]
					end
					
					require("nattlua.c_declarations.parser")
					require("nattlua.c_declarations.emitter")
					require("nattlua.c_declarations.analyzer")
					require("nattlua.c_declarations.main")
					require("examples.util")
		
					return require("nattlua")
				]],
					"nattlua",
					{
						emitter = {
							type_annotations = false,
						},
						parser = {
							inline_require = true,
							emit_environment = true,
						},
					}
				)
			)
			local lua_code = c:Emit(
				{
					pretty_print = true,
					string_quote = "\"",
					no_semicolon = true,
					omit_invalid_code = true,
					comment_type_annotations = true,
					type_annotations = true,
					force_parenthesis = true,
					module_encapsulation_method = "loadstring",
					no_newlines = false,
					extra_indent = {
						Start = {to = "Stop"},
						Toggle = "toggle",
					},
				}
			)
			lua_code = "_G.BUNDLE = true\n" .. lua_code
			lua_code = lua_code:gsub("%#%!%/usr%/local%/bin%/luajit\n", "\n")
			io.write(" - OK\n")
			io.write("output is " .. #lua_code .. " bytes\n")
			-- double check that the lua_code is valid
			io.write("checking if lua_code is loadable")
			local func, err = loadstring(lua_code)

			if not func then
				io.write(" - FAILED\n")
				io.write(err .. "\n")
				local f = io.open("temp_build_output.lua", "w")
				f:write(lua_code)
				f:close()
				Compiler.FromFile("temp_build_output.lua"):Parse()
				return
			end

			io.write(" - OK\n")

			if mode ~= "fast" then
				-- run tests before we write the file
				local f = io.open("temp_build_output.lua", "w")
				f:write(lua_code)
				f:close()
				io.write("running tests with temp_build_output.lua ")
				io.flush()
				local exit_code = os.execute("luajit -e 'require(\"temp_build_output\") require(\"test.run\")()'")

				if exit_code ~= 0 then
					io.write(" - FAIL\n")
					return
				end

				io.write(" - OK\n")
				io.write("checking if file can be required outside of the working directory")
				io.flush()
				local exit_code = os.execute("cd .github && luajit -e 'local nl = loadfile(\"../temp_build_output.lua\")'")

				if exit_code ~= 0 then
					io.write(" - FAIL\n")
					return
				end

				io.write(" - OK\n")
			end

			io.write("writing build_output.lua")
			local f = assert(io.open("build_output.lua", "w"))
			local shebang = "#!/usr/bin/env luajit\n"
			f:write(shebang .. lua_code)
			f:close()
			os.execute("chmod +x ./build_output.lua")
			io.write(" - OK\n")
			os.remove("temp_build_output.lua")
		end,
	}
end

return config
