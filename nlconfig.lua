local analyzer_config = {
	working_directory = input_dir,
	inline_require = true,
}
local config = {}
config["build:vscode"] = function()
	os.execute(
		"cd vscode_extension && yarn && yarn build && code --install-extension nattlua-0.0.1.vsix"
	)
end
config.install = function()
	-- only linux for now
	os.execute("mkdir -p ~/.local/bin")
	os.execute("cp build_output.lua ~/.local/bin/nattlua")
	os.execute("chmod +x ~/.local/bin/nattlua")
end
config.format = function()
	require("format")
end
config.test = function(path)
	assert(loadfile("test/run.lua"))(path)
end
config["build-for-ai"] = function(mode)
	-- this is just for something like a single file you can paste into gemini 1.5 or chatgpt. gemini's ai studio interface kind of doesn't work with many files, so this is easier.
	local f = io.open("nattlua_for_ai.lua", "w")
	local paths = {}

	for path in (
		io.popen("git ls-tree --full-tree --name-only -r HEAD"):read("*a")
	):gmatch("(.-)\n") do
		if path:find("%.lua") or path:find("%.nlua") then
			table.insert(paths, path)
		end
	end

	if mode == "all" then

	elseif mode == "core" then
		local new_paths = {}

		for _, path in ipairs(paths) do
			if path:sub(1, #"nattlua/") == "nattlua/" then
				table.insert(new_paths, path)
			end
		end

		paths = new_paths
	end

	local tokens = {}

	for _, path in ipairs(paths) do
		local str = io.open(path):read("*a")
		str = ">>>" .. path .. ">>>\n" .. str .. "\n<<<" .. path .. "<<<\n\n"
		f:write(str)
		table.insert(tokens, {path = path, count = #str * 2.88})
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

	print("roughly " .. math.floor(total_tokens / 10000) .. "k tokens")
end
config.build = function(mode)
	local nl = require("nattlua.init")
	local entry = "./nattlua.lua"
	io.write("parsing " .. entry)
	local c = assert(
		nl.Compiler(
			[[
            _G.ARGS = {...}

            if _G.IMPORTS then
                for k, v in pairs(_G.IMPORTS) do
                    if not k:find("/") then package.preload[k] = v end
                end
        
                package.preload.nattlua = package.preload["nattlua.init"]
            end

			require("nattlua.c_declarations.lexer")
			require("nattlua.c_declarations.parser")
			require("nattlua.c_declarations.emitter")
			require("nattlua.c_declarations.analyzer")
			require("nattlua.c_declarations.main")

            return require("nattlua")
        ]],
			"nattlua",
			{
				type_annotations = false,
				inline_require = true,
				emit_environment = true,
			}
		)
	)
	local lua_code = c:Emit(
		{
			preserve_whitespace = false,
			string_quote = "\"",
			no_semicolon = true,
			omit_invalid_code = true,
			comment_type_annotations = true,
			type_annotations = true,
			force_parenthesis = true,
			module_encapsulation_method = "loadstring",
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
		nl.File("temp_build_output.lua"):Parse()
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
		local exit_code = os.execute("luajit -e 'require(\"temp_build_output\") assert(loadfile(\"test/run.lua\"))()'")

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
	local shebang = "#!/usr/local/bin/luajit\n"
	f:write(shebang .. lua_code)
	f:close()
	os.execute("chmod +x ./build_output.lua")
	io.write(" - OK\n")
	os.remove("temp_build_output.lua")
end
config["get-analyzer-config"] = function()
	local analyzer_config = {}
	return analyzer_config
end
config.check = function()
	require("test.helpers.profiler").Start()
	local nl = require("nattlua.init")
	local compiler = assert(
		nl.Compiler(
			[[return import("]] .. "./nattlua.lua" .. [[")]],
			"./nattlua.lua",
			analyzer_config
		)
	)
	print("parsing")
	compiler:Parse()

	for k, v in pairs(compiler.SyntaxTree.imported) do
		print(k)
	end

	print("analyzing")
	compiler:Analyze()

	for node, res in pairs(compiler.analyzer.analyzed_root_statements) do
		local found = false

		for path, node2 in pairs(compiler.SyntaxTree.imported) do
			if node == node2 then
				print("analyzed " .. path)
				found = true

				break
			end
		end

		if not found then print("cannot find ", node.path) end
	end

	require("test.helpers.profiler").Stop()
end
return config
