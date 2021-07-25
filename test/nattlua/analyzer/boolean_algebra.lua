local T = require("test.helpers")
local run = T.RunCode

run[[ -- A
    local A = _ as true | false

    if A then 
        types.assert(A, true)
    end
]]

run[[ -- A or B

    local A = _ as true | false
    local B = _ as true | false

    if A then 
        types.assert(A, true)
        types.assert(B, _ as true | false)
    elseif B then 
        types.assert(B, true)
        types.assert(A, false)
    end
]]

run[[ -- A and B
    local A = _ as true | false
    local B = _ as true | false
    if A then
        if B then
            types.assert(A, true)
            types.assert(B, true)
        end
    end
]]

run[[ -- A or B or C

    local A = _ as true | false
    local B = _ as true | false
    local C = _ as true | false

    if A then 
        types.assert(A, true)
        types.assert(B, _ as true | false)
        types.assert(C, _ as true | false)
    elseif B then 
        types.assert(A, false)
        types.assert(B, true)
        types.assert(C, _ as true | false)
    elseif C then 
        types.assert(A, false)
        types.assert(B, false)
        types.assert(C, true)
    end
]]

run[[ -- A or not B

    local A = _ as true | false
    local B = _ as true | false

    if A then 
        types.assert(A, true)
        types.assert(B, _ as true | false)
    elseif not B then 
        types.assert(A, false)
        types.assert(B, false)
    end
]]

run[[ -- A or not B or C
    local A = _ as true | false
    local B = _ as true | false
    local C = _ as true | false

    if A then 
        types.assert(A, true)
        types.assert(B, _ as true | false)
        types.assert(C, _ as true | false)
    elseif not B then 
        types.assert(A, false)
        types.assert(B, false)
        types.assert(C, _ as true | false)
    elseif C then 
        types.assert(A, false)
        types.assert(B, true)
        types.assert(C, true)
    end
]]

run[[ -- A or not B or not C
    local A = _ as true | false
    local B = _ as true | false
    local C = _ as true | false

    if A then 
        types.assert(A, true)
        types.assert(B, _ as true | false)
        types.assert(C, _ as true | false)
    elseif not B then 
        types.assert(A, false)
        types.assert(B, false)
        types.assert(C, _ as true | false)
    elseif not C then 
        types.assert(A, false)
        types.assert(B, true)
        types.assert(C, false)
    end
]]

run[[ -- A and not B
    local A = _ as true | false
    local B = _ as true | false
    if A then
        if not B then
            types.assert(A, true)
            types.assert(B, false)
        end
    end
]]

run[[ -- not A and not B
    local A = _ as true | false
    local B = _ as true | false
    if not A then
        if not B then
            types.assert(A, false)
            types.assert(B, false)
        end
    end
]]
run[[ -- not A and B
    local A = _ as true | false
    local B = _ as true | false
    if not A then
        if B then
            types.assert(A, false)
            types.assert(B, true)
        end
    end
]]

run[[ -- (A and B) or (C and D)

    local A = _ as true | false
    local B = _ as true | false
    local C = _ as true | false
    local D = _ as true | false

    if A then
        if B then
            
            return
        end 
    end

    if C then
        if D then

            return
        end
    end
]]

--[[
    https://www.youtube.com/watch?v=XMCW6NFLMsg

    z = A or (not A and B)
    z = (A or not A) and (A or B)
    z = true and (A or B)
    z = (A or B)

    z = A and ((A or not A) or not B)
    z = A and (true or not B)
    z = A and true
    z = A

    z = A and B or B and C and (B or C)
    z = (A and B) or ((B and C) and (B or C))
    z = (A and B) or (((B and C) and B) or ((B and C) and C))
    z = (A and B) or (B and C and B) or (B and C and C)
    z = (A and B) or (B and C) or (B and C)
    z = (A and B) or (B and C)
    z = B and (A or C)

    z = A or A and B
    z = A or (A and B)
    z = (A and true) or (A and B)


    A and B or A and (B or C) or B and (B or C)
    (A and B) or (A and (B or C)) or B

]]