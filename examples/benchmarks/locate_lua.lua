local nl = require("nattlua")
require("test.helpers.profiler").Start()

for full_path in io.popen("locate .lua"):read("*all"):gmatch("(.-)\n") do
	if full_path:sub(-4) == ".lua" then
		local ok, err = loadfile(full_path)

		if ok then
			io.write("PARSE ", full_path)
			local func, err = nl.loadfile(full_path, {
				skip_import = true,
			})

			if not func then io.write(err, " - FAIL\n") else io.write(" - OK\n") end
		else
			io.write("SKIP ", full_path, " - FAIL : ", err, "\n")
		end
	end
end

require("test.helpers.profiler").Stop()