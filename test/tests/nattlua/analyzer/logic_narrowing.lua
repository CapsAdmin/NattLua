do
	return
end

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
        attest.equal(t.foo, 1 as number)
    end
]]
analyze[[
    local t = {x = 1 as number | nil}
    local check = t.x ~= nil
    if check then
        attest.equal(t.x, 1 as number)
    end
]]
