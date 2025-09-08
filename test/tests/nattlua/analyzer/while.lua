analyze[[
    local i = 1

    while true do
        i = i + 1
        if i >= 10 then break end
    end

    attest.equal(i, 10)
]]
analyze[[
    local i = 1 as number
    local o = 1

    while true do
        o = o + 1
        i = i + 1
        if i >= 10 then break end
    end

    attest.equal(o, 2) -- this should probably be number too as it's incremented in an uncertain loop
]]
analyze[[
    local a = 1
    repeat
        attest.equal(a, 1)
    until true
]]
analyze[[
    local a = 0
    while false do
        a = 1
    end
    attest.equal(a, 0)
]]
analyze[[
    local a = 1
    while true do
        a = a + 1
        break
    end
    local b = a

    repeat
        b = b + 1
    until true

    local c = b
]]
analyze[[

    local a = 0
    while _ as boolean do
        a = a + 1
    end
    attest.equal(a, _ as number | 0)

]]
analyze[[
    local x: nil | 1

    while x ~= nil do
        attest.equal(x, 1)
        x = x + 1
        attest.equal(x, _ as number)
        attest.equal(x>10, _ as true | false)
        if x > 10 then break end
    end
]]
analyze[[
	attest.expect_diagnostic<|"warning", "always false"|>

	while false do

	end
]]
analyze[[

	attest.expect_diagnostic<|"warning", "while loop only executed once"|>

	while true do
		break
	end
]]
analyze[[
	attest.expect_diagnostic<|"warning", "while loop only executed once"|>
	attest.expect_diagnostic<|"warning", "if condition is always true"|>
	local i = 0

	while true do
		if i == 0 then break end
	end
]]
analyze[[

    attest.expect_diagnostic<|"warning", "while loop only executed once"|>

    local x = 1

    while x > 0 do
        x = 0
    end
]]
pending[[
	attest.expect_diagnostic<|"warning", "while loop only executed once"|>

	while true do
		return
	end
]]
analyze[[
local arr = {1, 2, 3}

while #arr > 0 do
	arr = {} 
end

]]
