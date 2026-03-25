--[[HOTRELOAD
os.execute("luajit nattlua.lua test")
]]
local type = _G.type
local table_insert = _G.table.insert
local tostring = _G.tostring
local pairs = _G.pairs
local jit = _G.jit--[[# as jit | nil]]
local jit_options = {}

if not jit then
	function jit_options.Set() end

	function jit_options.SetOptimized() end

	return jit_options
end

local GC64 = #tostring({}) == 19
-- https://github.com/LuaJIT/LuaJIT/blob/v2.1/src/lj_jit.h#L116-L137
local default_options = {
	maxtrace = 1000,
	maxmcode = 512,
	sizemcode = jit.os == "Windows" or GC64 and 64 or 32,
	maxrecord = 4000,
	maxirconst = 500,
	maxsnap = 500,
	minstitch = 0,
	maxside = 100,
	hotloop = 56,
	hotexit = 10,
	tryside = 4,
	instunroll = 4,
	loopunroll = 15,
	callunroll = 3,
	recunroll = 2,
}
-- https://github.com/LuaJIT/LuaJIT/blob/v2.1/src/lj_jit.h#L93-L103
local default_flags = {
	fold = true,
	cse = true,
	dce = true,
	narrow = true,
	loop = true,
	fwd = true,
	dse = true,
	abc = true,
	sink = true,
	fuse = true,
	--[[
		Note that fma is not enabled by default at any level, because it affects floating-point result accuracy. 
		Only enable this, if you fully understand the trade-offs:
			performance (higher)
			determinism (lower) 
			numerical accuracy (higher)
	]]
	fma = false,
}
local last_options = {options = {}, flags = {}}

function jit_options.Set(options--[[#: AnyTable | nil]], flags--[[#: AnyTable | nil]])
	if not jit then return end

	options = options or {}
	flags = flags or {}

	do -- validate
		for k, v in pairs(options) do
			if default_options[k] == nil then
				error("invalid parameter ." .. k .. "=" .. tostring(v), 2)
			end
		end

		for k, v in pairs(flags) do
			if default_flags[k] == nil then
				error("invalid flag .flags." .. k .. "=" .. tostring(v), 2)
			end
		end
	end

	local p = {}

	for k, v in pairs(default_options) do
		if options[k] == nil then
			p[k] = v
		else
			p[k] = options[k]

			if type(p[k]) ~= "number" then
				error(
					"parameter ." .. k .. "=" .. tostring(options[k]) .. " must be a number or nil",
					2
				)
			end
		end
	end

	local f = {}

	for k, v in pairs(default_flags) do
		if flags[k] == nil then
			f[k] = v
		else
			f[k] = flags[k]

			if type(f[k]) ~= "boolean" then
				error(
					"parameter ." .. k .. "=" .. tostring(options[k]) .. " must be true, false or nil",
					2
				)
			end
		end
	end

	_G.JIT_PARAMS = p
	last_options = {options = p, flags = f}
	local args = {}

	for k, v in pairs(p) do
		table_insert(args, k .. "=" .. tostring(v))
	end

	for k, v in pairs(f) do
		if v then
			table_insert(args, "+" .. k)
		else
			table_insert(args, "-" .. k)
		end
	end

	jit.opt.start(unpack(args))
	jit.flush()
end

function jit_options.Get()
	return last_options
end

function jit_options.SetOptimized()
	jit_options.Set(
		{
			-- trace cache limits
			maxtrace = 65535, -- default: 1000 | 1 >= 65535: Max number of traces in cache
			maxmcode = 128000, -- default: 512 | max total size of all machine code areas (in KBytes).
			-- size of each machine code area (in KBytes).
			-- See: https://devblogs.microsoft.com/oldnewthing/20031008-00/?p=42223
			-- Could go as low as 4K, but the mmap() overhead would be rather high.
			sizemcode = 64, -- default: jit.os == "Windows" or GC64 and 64 or 32
			-- trace size limits
			maxrecord = 8000, -- default: 4000 | Max number of recorded IR instructions
			maxirconst = 2000, -- default: 500 | Max number of IR constants of a trace
			maxsnap = 1000, -- default: 500 | Max number of snapshots for a trace
			-- side trace limits
			minstitch = 0, -- default: 0 | Min number of IR instructions for a stitched trace. depends on maxrecord
			maxside = 10, -- default: 100 | Max number of side traces of a root trace
			-- hotness thresholds
			hotloop = 10000, -- default: 56 | loop iterations to start a trace (functions need hotloop*2 calls)
			hotexit = 0, -- default: 10 | times a trace exit must be taken to start a side trace. depends on maxside
			tryside = 0, -- default: 4 | number of attempts to compile a side trace
			-- unroll heuristics
			instunroll = 0, -- default: 4 | max unroll attempts for loops with instable types.
			loopunroll = 1000, -- default: 15 | max unroll for loop ops in side traces.
			callunroll = 300, -- default: 3 | max depth for recursive calls.
			recunroll = 0, -- default: 2 | min unroll for true recursion.
		},
		{
			fold = true,
			cse = true,
			dce = true,
			narrow = true,
			loop = true,
			fwd = true,
			dse = true,
			abc = true,
			sink = true,
			fuse = true,
			fma = true,
		}
	)
end

return jit_options
