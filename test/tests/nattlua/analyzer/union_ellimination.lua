analyze[[
    local function test() 
        if Any() then
            return nil
        end
        return 2
    end
    
    local x = { lol = _ as false | 1 }
    if not x.lol then
        x.lol = test()
        attest.equal(x.lol, _ as 2 | nil)
    end

    attest.equal(x.lol, _ as 1 | 2 | nil)
]]
analyze[[
    local x = _ as nil | 1 | false
    if x then x = false end
    attest.equal<|x, nil | false|>

    local x = _ as nil | 1
    if not x then x = 1 end
    attest.equal<|x, 1|>

    local x = _ as nil | 1
    if x then x = nil end
    attest.equal<|x, nil|>
]]
analyze[[
    local type config_get_time = (nil | function=()>(number))
    local self = {_get_time = config_get_time}

    if not self._get_time then self._get_time = _ as function=()>(number) end

    local get_time = self._get_time
    attest.equal(get_time, _ as function=()>(number))
    local _time_start = get_time()
    attest.equal(type(_time_start), "number")
]]