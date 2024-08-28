local trace_abort = require("nattlua.other.jit_trace_abort")
trace_abort.Start()
local nl = require("nattlua.compiler")
local profiler = require("nattlua.other.jit_profiler2")
local code = io.open("/home/caps/projects/NattLua/examples/projects/gmod/nattlua/glua_base.nlua", "r"):read("*all")
--code = "local SERVER = true\nlocal CLIENT = true\nlocal MENU = true\n" .. code
local c = nl.New(code)
c:Parse()

--profiler.Start({depth = 1000, sampling_rate = 0})
for i = 1, 1 do
	c:Analyze()
end

--print(profiler.Stop())
print(trace_abort.Stop())