local ARGS = _G.ARGS or {...}
local cmd = ARGS[1]

local function run_nlconfig()
	if not io.open("./nlconfig.lua") then
		io.write("No nlconfig.lua found.\n")
		return
	end

	if _G.IMPORTS then
		for k, v in pairs(_G.IMPORTS) do
			if not k:find("/") then package.preload[k] = v end
		end

		package.preload.nattlua = package.preload["nattlua.init"]
	end

	assert(_G["load" .. "file"]("./nlconfig.lua"))(unpack(ARGS))
end

if cmd == "run" then
	if unpack(ARGS, 2) then
		local path = assert(unpack(ARGS, 2))
		local compiler = assert(m.File(path))
		compiler:Analyze()
		assert(loadstring(compiler:Emit(), "@" .. path))(unpack(ARGS, 3))
	else
		run_nlconfig()
	end
elseif cmd == "check" then
	if unpack(ARGS, 2) then
		local path = assert(unpack(ARGS, 2))
		local compiler = assert(m.File(path))
		assert(compiler:Analyze())
	else
		run_nlconfig()
	end
elseif cmd == "build" then
	if unpack(ARGS, 2) then
		local path_from = assert(unpack(ARGS, 2))
		local compiler = assert(m.File(path_from))
		local path_to = assert(unpack(ARGS, 3))
		local f = assert(io.open(path_to, "w"))
		f:write(compiler:Emit())
		f:close()
	else
		run_nlconfig()
	end
else
	run_nlconfig()
end