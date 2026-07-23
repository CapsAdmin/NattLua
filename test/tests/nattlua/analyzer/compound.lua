analyze[[
local x = 2
x *= 2
attest.equal(x, 4)
]]
analyze[[
local t = {field = 10}
t.field += 5
attest.equal(t.field, 15)
]]
analyze[[
local t = {inner = {value = 100}}
t.inner.value -= 25
attest.equal(t.inner.value, 75)
]]
