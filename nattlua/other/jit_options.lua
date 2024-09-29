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
	--
	maxtrace = 1000, -- 1 > 65535: Max number of of traces in cache. 
	maxrecord = 4000, -- Max number of of recorded IR instructions.
	maxirconst = 500, -- Max number of of IR constants of a trace.
	maxside = 100, -- Max number of of side traces of a root trace.
	maxsnap = 500, -- Max number of of snapshots for a trace.
	minstitch = 0, -- Min number of of IR ins for a stitched trace.
	--
	hotloop = 56, -- number of iter. to detect a hot loop/call.
	hotexit = 10, -- number of taken exits to start a side trace.
	tryside = 4, -- number of attempts to compile a side trace.
	--
	instunroll = 4, -- max unroll for instable loops.
	loopunroll = 15, -- max unroll for loop ops in side traces.
	callunroll = 3, -- max. unroll for recursive calls.
	recunroll = 2, -- min  unroll for true recursion.
	--
	-- size of each machine code area (in KBytes).
	-- See: https://devblogs.microsoft.com/oldnewthing/20031008-00/?p=42223
	-- Could go as low as 4K, but the mmap() overhead would be rather high.
	sizemcode = jit.os == "Windows" or GC64 and 64 or 32,
	maxmcode = 512, -- max total size of all machine code areas (in KBytes).
--
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
	]] fma = false,
}

function jit_options.Set(options, flags)
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

	local args = {}

	for k, v in pairs(p) do
		table.insert(args, k .. "=" .. tostring(v))
	end

	for k, v in pairs(f) do
		if v then
			table.insert(args, "+" .. k)
		else
			table.insert(args, "-" .. k)
		end
	end

	jit.opt.start(unpack(args))
	jit.flush()
end

function jit_options.SetOptimized()
	jit_options.Set(
		{
			maxtrace = 65535,
			maxmcode = 128000,
			minstitch = 3,
			maxrecord = 2000,
			maxirconst = 8000,
			maxside = 5000,
			maxsnap = 5000,
			hotloop = 200,
			hotexit = 30,
			tryside = 4,
			instunroll = 1000,
			loopunroll = 1000,
			callunroll = 1000,
			recunroll = 0,
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
		}
	)
end

return jit_options