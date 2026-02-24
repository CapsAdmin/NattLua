analyze[[
    local function foo()
        coroutine.yield(10)
        coroutine.yield(20)
        return 30
    end

    local co = coroutine.create(foo)
    local ok, res = coroutine.resume(co)
    attest.equal(res, 10)
    local ok, res = coroutine.resume(co)
    attest.equal(res, 20)
    local ok, res = coroutine.resume(co)
    attest.equal(res, 30)
    
    local it = coroutine.wrap(foo)
    attest.equal(it(), 10)
    attest.equal(it(), 20)
    attest.equal(it(), 30)
]]
