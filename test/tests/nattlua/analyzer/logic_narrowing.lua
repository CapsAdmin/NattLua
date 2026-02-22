analyze([[
    local x = 1 as number | nil
    local y = 2 as number | nil
    local check = (x ~= nil) and (y ~= nil)
    if check then
        attest.equal(x, 1 as number)
        attest.equal(y, 2 as number)
        local sum: number = x + y
    end
]])
analyze[[
    local t = {foo = 1 as number | nil}
    local val = t.foo
    if val then
        attest.equal(val, 1 as number)
    end
]]
-- narrowing table fields through stored checks
analyze[[
    local t = {x = 1 as number | nil}
    local check = t.x ~= nil
    if check then
        attest.equal(t.x, 1 as number)
    end
]]
analyze[[
    local a: nil | 1

    if a or true and a or false then
        attest.equal(a, _ as 1)
    end

    attest.equal(a, _ as 1 | nil)
]]
analyze[[
    local a: nil | 1

    if not not a then
        attest.equal(a, 1)
    end

    attest.equal(a, _ as 1 | nil)
]]
analyze[[
    local x: number
    
    if x >= 0 and x <= 10 then
        attest.equal<|x, 0 .. 10|>
    end
]]

pending[[
    local Any(): boolean
    local x = 0
    if Any() then x = x + 1 end -- 1
    if Any() then x = x - 1 end -- 0
    attest.equal(x, 0)
]]