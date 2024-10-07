analyze[[
    local lol
    do
        lol = 1
    end

    do
        attest.equal(lol, 1)
    end
]]
analyze([[
    -- test shadow upvalues
    local foo = 1337

    local function test()
        attest.equal(foo, 1337)
    end
    
    local foo = 666
]])
analyze[[
    local foo = 1337

    local function test()
        if math.random() > 0.5 then
            attest.equal(foo, 1337)
        end
    end

    local foo = 666
]]
analyze[[
    local x = 0

    local function lol()
        attest.equal(x, _ as 0 | 1 | 2)
    end
    
    local function foo()
        x = x + 1
    end
    
    local function bar()
        x = x + 1
    end
]]
analyze[[
	local x = {foo = true}
	local lol
	do
		function lol()
			attest.equal<|x, {foo = true}|>
		end
	end

	local x = {foo = false}
	attest.equal<|x, {foo = false}|>
	lol()
]]
analyze[[
local socket = {}

function socket.create()
	if _  as boolean then return nil, "test" end

	return _  as number
end

local M = {}

do
	local meta = {}
	meta.__index = meta
	type meta.@Self = {hello = boolean}

	function M.create(family: string)
		local fd, err, num = socket.create()

		if not fd then return fd, err, num end

		return setmetatable({hello = true}, meta)
	end

	function meta:accept()
		if math.random() > 0.5 then
			local client = setmetatable({hello = false}, meta)
			return client
		end
	end

	function meta:read()
		return "foo"
	end
end

local client = M.create("info.family")

if client then
	local other = assert(client:accept())
	local test = client:read()
end
]]
