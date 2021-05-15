local T = require("test.helpers")
local run = T.RunCode

run[[ -- A
    local A = _ as true | false

    if A then 
        type_assert(A, true)
    end
]]

run[[ -- A or B

    local A = _ as true | false
    local B = _ as true | false

    if A then 
        type_assert(A, true)
        type_assert(B, _ as true | false)
    elseif B then 
        type_assert(B, true)
        type_assert(A, false)
    end
]]

pending[[ -- A or B or C

    local A = _ as true | false
    local B = _ as true | false
    local C = _ as true | false

    if A then 
        type_assert(A, true)
        type_assert(B, _ as true | false)
        type_assert(C, _ as true | false)
    elseif B then 
        type_assert(A, false)
        type_assert(B, true)
        type_assert(C, _ as true | false)
    elseif C then 
        type_assert(A, false)
        type_assert(B, false)
        type_assert(C, true)
    end
]]

pending[[ -- A or not B

    local A = _ as true | false
    local B = _ as true | false

    if A then 
        type_assert(A, true)
        type_assert(B, _ as true | false)
    elseif not B then 
        type_assert(A, false)
        type_assert(B, false)
    end
]]

pending[[ -- A or not B or C
    local A = _ as true | false
    local B = _ as true | false
    local C = _ as true | false

    if A then 
        type_assert(A, true)
        type_assert(B, _ as true | false)
        type_assert(C, _ as true | false)
    elseif not B then 
        type_assert(A, false)
        type_assert(B, false)
        type_assert(C, _ as true | false)
    elseif C then 
        type_assert(A, false)
        type_assert(B, true)
        type_assert(C, true)
    end
]]

pending[[ -- A or not B or not C
    local A = _ as true | false
    local B = _ as true | false
    local C = _ as true | false

    if A then 
        type_assert(A, true)
        type_assert(B, _ as true | false)
        type_assert(C, _ as true | false)
    elseif not B then 
        type_assert(A, false)
        type_assert(B, false)
        type_assert(C, _ as true | false)
    elseif not C then 
        type_assert(A, false)
        type_assert(B, true)
        type_assert(C, false)
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