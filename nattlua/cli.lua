local nattlua = require("nattlua.init")
local default = {}
default.run = function(path, ...)
	assert(path)
	local compiler = assert(nattlua.File(path))
	compiler:Analyze()
	assert(loadstring(compiler:Emit(), "@" .. path))(...)
end
default.check = function(path)
	assert(path)
	local path = assert(unpack(ARGS, 2))
	local compiler = assert(nattlua.File(path))
	assert(compiler:Analyze())
end
default.build = function(path, path_to)
	assert(path)
	assert(path_to)
	local compiler = assert(nattlua.File(path_from))
	local f = assert(io.open(path_to, "w"))
	f:write(compiler:Emit())
	f:close()
end
default["language-server"] = function()
	require("language_server.server.main")()
end

function _G.RUN_CLI(cmd, ...)
	local nlconfig_path = "./nlconfig.lua"
	local args = {...}

	if type(cmd) == "string" and cmd:find("nlconfig.lua", nil, true) then
		nlconfig_path = cmd
		cmd = args[1]
		table.remove(args, 1)
	end

	local function run_nlconfig()
		local load_file = _G["load" .. "file"]

		if not load_file(nlconfig_path) then
			io.write("No nlconfig.lua found.\n")
			return
		end

		return assert(load_file(nlconfig_path))()
	end

	local override = run_nlconfig()

	if override then
		for k, v in pairs(override) do
			if default[k] then
				io.write("nlconfig.lua overrides default command ", k, "\n")
			end

			default[k] = v
		end
	end

	local func = assert(default[cmd], "Unknown command " .. cmd)
	io.write("running ", cmd, " with arguments ", table.concat(args, " "), "\n")
	func(unpack(args))
end