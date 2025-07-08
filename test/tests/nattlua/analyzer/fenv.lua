analyze[[
    local func = function() 
        attest.equal(foo, 1337)
    end
    
    debug.setfenv(func, {
        foo = 1337
    })

    func()

    attest.equal(debug.getfenv(func).foo, 1337)
]]
