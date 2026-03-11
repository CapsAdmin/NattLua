-- if start then → stop should be number
analyze[[
    local str = _ as string
    local start, stop = str:find(_ as string)
    attest.equal(start, _ as nil | number)
    attest.equal(stop, _ as nil | number)
    if start then
        attest.equal(start, _ as number)
        attest.equal(stop, _ as number)
    end
]]
-- else branch: if not start → stop should be nil
analyze[[
    local str = _ as string
    local start, stop = str:find(_ as string)
    if start then
        attest.equal(stop, _ as number)
    else
        attest.equal(start, _ as nil)
        attest.equal(stop, _ as nil)
    end
]]
-- checking stop instead of start also narrows start
analyze[[
    local str = _ as string
    local start, stop = str:find(_ as string)
    if stop then
        attest.equal(start, _ as number)
        attest.equal(stop, _ as number)
    end
]]
-- user-defined function returning union of tuples
analyze[[
    local function foo()
        return _ as (number, string) | (nil, nil)
    end
    local a, b = foo()
    attest.equal(a, _ as nil | number)
    attest.equal(b, _ as nil | string)
    if a then
        attest.equal(a, _ as number)
        attest.equal(b, _ as string)
    end
]]
-- three-element tuple entanglement
analyze[[
    local function foo()
        return _ as (true, number, string) | (false, nil, nil)
    end
    local ok, num, str = foo()
    if ok then
        attest.equal(num, _ as number)
        attest.equal(str, _ as string)
    else
        attest.equal(num, _ as nil)
        attest.equal(str, _ as nil)
    end
]]
-- pcall with uncertain error should return union-of-tuples and entangle
analyze[[
    local ok, err = pcall(function()
        if math.random() > 0.5 then error("!") end
        return 1337
    end)
    attest.equal(ok, _ as false | true)
    attest.equal(err, _ as 1337 | string)
    if ok then
        attest.equal(ok, _ as true)
        attest.equal(err, _ as 1337)
    else
        attest.equal(ok, _ as false)
        attest.equal(err, _ as string)
    end
]]
