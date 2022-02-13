local T = require("test.helpers")
local run = T.RunCode

run[[
    £parser.TealCompat = true
    local record tl
        enum LoadMode
            "b"
            "t"
            "bt"
        end
        lol: LoadMode
    end
    £parser.TealCompat = false

    attest.equal(tl.LoadMode, _ as "b" | "bt" | "t")
    attest.equal(tl.lol, _ as "b" | "bt" | "t")
]]

run[[
    £parser.TealCompat = true

    local record VisitorCallbacks<N, T>
        foo: N
        bar: T
    end

    local x: VisitorCallbacks<string, number> = {foo = "hello", bar = 42}
    £parser.TealCompat = false

    attest.equal(x, _ as {foo = string, bar = number})
]]

run[[
    £parser.TealCompat = true

    local x: {string}
    
    £parser.TealCompat = false

    attest.equal(x, _ as {[number] = string})
]]

run[[
    £parser.TealCompat = true

    local x: {string, number, boolean}
    
    £parser.TealCompat = false

    attest.equal(x, _ as {string, number, boolean})
]]

run[[
    £parser.TealCompat = true

    local x: {string, number, boolean}
    
    £parser.TealCompat = false

    attest.equal(x, _ as {string, number, boolean})
]]