analyze[[
    local func = function() 
        attest.equal(foo, 1337)
    end

    setfenv(func, {
        foo = 1337
    })

    func()

    attest.equal(getfenv(func).foo, 1337)
]]
