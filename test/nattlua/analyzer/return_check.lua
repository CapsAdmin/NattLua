local T = require("test.helpers")
local run = T.RunCode

run([[
    local function func(): number, number
        if math.random() > 0.5 then
            return 1, "" -- HERE
        end
    
        return 1,2
    end
]], "return 1, \"\" %-%- HERE")


run([[
    local function func(): number, number
        if math.random() > 0.5 then
            return 1, 2
        end
    
        return 3 -- HERE
    end
]], "return 3 %-%- HERE")


run([[
    local function func(): number, number
        return 1
    end
]], "index 2 does not exist")

run([[
    local function func(): number, number
        if MAYBE then
            return 1, 2
        end

        return 3
    end
]], "index 2 does not exist")

run[[
    local MAYBE: boolean

    local function ReadLiteralString(multiline_comment : boolean): (true,) | (false, string)
        if MAYBE then
            if multiline_comment then return false, "multiline comment not allowed" end
            return false, "a string"
        end
    
        if MAYBE then
            return true
        end
    
        return false, "another string"
    end
]]