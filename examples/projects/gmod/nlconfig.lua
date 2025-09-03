-- Some things here are hardcoded for now.
-- When I'm happy with how things are I'll move general code to NattLua and make this more of a config
-- so you could just run something like nlc in the directory
local function GetFilesRecursively(dir, ext)
	ext = ext or ".lua"
	local f = assert(io.popen("find " .. dir .. "/ -print0 | xargs -0 realpath"))
	local lines = f:read("*all")
	local paths = {}

	for line in lines:gmatch("(.-)\n") do
		if line:sub(-4) == ext then table.insert(paths, line) end
	end

	return paths
end

local config = {commands = {}}
config.commands["build-api"] = {
	cb = function()
		os.execute("nattlua run build_glua_base.lua")
	end,
}
config.commands["fmt"] = {
	cb = function()
		local nl = require("nattlua")

		local function read_file(path)
			local f = assert(io.open(path, "r"))
			local contents = f:read("*all")
			f:close()
			return contents
		end

		local function write_file(path, contents)
			local f = assert(io.open(path, "w"))
			f:write(contents)
			f:close()
		end

		local lua_files = GetFilesRecursively("./lua/", ".lua")
		local blacklist = {
			["./lua/entities/gmod_wire_expression2/core/custom/pac.lua"] = true,
		}
		local config = {
			emitter = {
				pretty_print = true,
				string_quote = "\"",
				no_semicolon = true,
				force_parenthesis = true,
				extra_indent = {
					StartStorableVars = {
						to = "EndStorableVars",
					},
					Start2D = {to = "End2D"},
					Start3D = {to = "End3D"},
					Start3D2D = {to = "End3D2D"},
					-- in case it's localized
					cam_Start2D = {to = "cam_End2D"},
					cam_Start3D = {to = "cam_End3D"},
					cam_Start3D2D = {to = "cam_End3D2D"},
					cam_Start = {to = "cam_End"},
					SetPropertyGroup = "toggle",
				},
			},
		}

		for _, path in ipairs(lua_files) do
			if not blacklist[path] then
				local lua_code = read_file(path)
				local new_lua_code = assert(nl.Compiler(lua_code, "@" .. path, config)):Emit()

				if new_lua_code:sub(#new_lua_code, #new_lua_code) ~= "\n" then
					new_lua_code = new_lua_code .. "\n"
				end

				--assert(loadstring(new_lua_code, "@" .. path))
				write_file(path, new_lua_code)
			end
		end
	end,
}
config.commands["get-compiler-config"] = {
	cb = function()
		return {
			lsp = {entry_point = GetFilesRecursively("examples/projects/gmod/lua/autorun")},
			parser = {emit_environment = false},
		}
	end,
}
return config
