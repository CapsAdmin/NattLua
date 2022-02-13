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
]]