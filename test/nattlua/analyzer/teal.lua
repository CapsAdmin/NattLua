local T = require("test.helpers")
local run = T.RunCode

run[[
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