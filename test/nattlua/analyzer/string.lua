local T = require("test.helpers")
local run = T.RunCode

test("meta library", function()
    run[[
        local a = "1234"
        type_assert(string.len(a), 4)
        type_assert(a:len(), 4)
    ]]
end)

test("patterns", function()
    run[[
        local a: $"FOO_.-" = "FOO_BAR"
    ]]

    run([[
        local a: $"FOO_.-" = "lol"
    ]], "cannot find .- in pattern")
end)

run[===[
    local foo = [[foo]]
    local bar = [=[foo]=]
    local faz = [==[foo]==]
    
    type_assert(foo, "foo")
    type_assert(bar, "foo")
    type_assert(faz, "foo")
]===]

run[[
    do
        local totable = string.ToTable
        local string_sub = string.sub
        local string_find = string.find
        local string_len = string.len
        function string.Explode(separator, str, withpattern)
            if ( withpattern == nil ) then withpattern = false end
        
            local ret = {}
            local current_pos = 1
        
            for i = 1, string_len( str ) do
                local start_pos, end_pos = string_find( str, separator, current_pos, !withpattern )
                if ( !start_pos ) then break end
                ret[ i ] = string_sub( str, current_pos, start_pos - 1 )
                current_pos = end_pos + 1
            end
        
            ret[ #ret + 1 ] = string_sub( str, current_pos )
        
            return ret
        end
        
        function string.Split( str, delimiter )
            return string.Explode( delimiter, str )
        end    
    end
    
    type_assert(string.Split("1|2|3", "|"), {"1","2","3"})
]]