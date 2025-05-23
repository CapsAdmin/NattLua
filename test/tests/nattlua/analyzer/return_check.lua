analyze(
	[[
    local function func(): number, number
        if math.random() > 0.5 then
            return 1, "" -- HERE
        end
    
        return 1,2
    end
]],
	"return 1, \"\" %-%- HERE"
)
analyze(
	[[
    local function func(): number, number
        if math.random() > 0.5 then
            return 1, 2
        end
    
        return 3 -- HERE
    end
]],
	"return 3 %-%- HERE"
)
analyze(
	[[
    local function func(): number, number
        return 1
    end
]],
	"index 2 does not exist"
)
analyze(
	[[
    local function func(): number, number
        if Any() then
            return 1, 2
        end

        return 3
    end
]],
	"index 2 does not exist"
)
analyze[[
    local maybe: boolean

    local function ReadLiteralString(multiline_comment : boolean): (true,) | (false, string)
        if maybe then
            if multiline_comment then return false, "multiline comment not allowed" end
            return false, "a string"
        end
    
        if maybe then
            return true
        end
    
        return false, "another string"
    end
]]
