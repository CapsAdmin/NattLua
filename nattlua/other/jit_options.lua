--ANALYZE
local jit = _G.jit--[[# as jit | nil]]
return function()
	if not jit then return end

	local GC64 = #tostring({}) == 19
	local params = {
		maxtrace = 1000, -- 1 > 65535: Max number of of traces in cache. 
		maxrecord = 4000, -- Max number of of recorded IR instructions.
		maxirconst = 500, -- Max number of of IR constants of a trace.
		maxside = 100, -- Max number of of side traces of a root trace.
		maxsnap = 500, -- Max number of of snapshots for a trace.
		minstitch = jit.version_num >= 20100 and 0 or nil, -- Min number of of IR ins for a stitched trace.
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
		sizemcode = jit.os == "Windows" or GC64 and 64 or 32, -- size of each machine code area (in KBytes).
		maxmcode = 512, -- max total size of all machine code areas (in KBytes).
	}
	params.maxtrace = 65535

	if jit.arch == "arm64" then
		-- initially i used these settings, but it didn't work that well
		-- https://github.com/love2d/love/blob/8e7fd10b6fd9b6dce6d61d728271019c28a7213e/src/modules/love/jitsetup.lua#L36
		-- this makes it not crash as much and improves performance a lot, the size is crazy high i guess but it works
		params.maxmcode = 1024 * 40
		-- this should be 32 or 64 or something, but setting it to the same as maxmcode seems to work much better
		params.sizemcode = params.maxmcode
	else
		params.maxrecord = 4000
		params.maxirconst = 1500
		params.maxsnap = 1500
		params.minstitch = 3
		params.maxmcode = 128000
		params.sizemcode = params.maxmcode
		params.loopunroll = 3
		params.recunroll = 2
	end

	local flags = {
		"fold", -- Constant Folding, Simplifications and Reassociation
		"cse", -- Common-Subexpression Elimination
		"dce", -- Dead-Code Elimination
		"narrow", -- Narrowing of numbers to integers
		"loop", -- Loop Optimizations (code hoisting)
		"fwd", -- Load Forwarding (L2L) and Store Forwarding (S2L)
		"dse", -- Dead-Store Elimination
		"abc", -- Array Bounds Check Elimination
		"sink", -- Allocation/Store Sinking
		"fuse", -- Fusion of operands into instructions
	}
	local args = {}

	for k, v in pairs(params) do
		table.insert(args, k .. "=" .. tostring(v))
	end

	for _, v in ipairs(flags) do
		table.insert(args, "+" .. v)
	end

	jit.opt.start(unpack(args))
	jit.flush()
end