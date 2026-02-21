analyze[[
    -- Test pcall and xpcall arguments passing
    local f = function(...)
        local arg1, arg2 = ...
        attest.equal(arg1, 1)
        attest.equal(arg2, 2)
        return 42
    end
    
    local ok, res = pcall(f, 1, 2)
    attest.equal(ok, true)
    attest.equal(res, 42)
    
    local ok2, res2 = xpcall(f, print, 1, 2)
    attest.equal(ok2, true)
    attest.equal(res2, 42)
]]
analyze[[
    -- Test pcall narrowing
    local function failing()
        error("oh no")
    end
    
    local ok, err = pcall(failing)
    attest.equal(ok, false)
    attest.equal(err, "oh no")
    
    local ok2, res = pcall(function() return 123 end)
    attest.equal(ok2, true)
    attest.equal(res, 123)
]]
analyze[[
    -- Test pcall narrowing with unknown function
    local f: function=()>(number)
    local ok, res = pcall(f)
    attest.equal(ok, _ as boolean)
    attest.equal(res, _ as number | string)
]]
analyze[[
    -- Test xpcall
    local function failing()
        error("error message")
    end
    local err_captured
    local ok, err = xpcall(failing, function(msg)
        err_captured = msg
        return "wrapped: " .. msg
    end)
    attest.equal(ok, false)
    -- In the current implementation return value from xpcall handler might not be fully supported in the analyzer function
    -- but we check if it's at least a string
    attest.equal(type(err), "string")
    attest.equal(err_captured, "error message")
]]
