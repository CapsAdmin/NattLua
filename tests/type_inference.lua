-- R"type_assert((nil as boolean) or 1, (nil as boolean) | 1)"


local oh = require("oh")
local C = oh.Code

local function R(code, expect_error)
    local code_data = oh.Code(code, nil, nil, 3)
    local ok, err = code_data:Analyze()

    if expect_error then
        if not err then
            error("expected error, got\n\n\n[" .. tostring(ok) .. ", " .. tostring(err) .. "]")
        elseif type(expect_error) == "string" and not err:find(expect_error) then
            error("expected error " .. expect_error .. " got\n\n\n" .. err)
        end
    else
        if not ok then
            local ok, err2 = C(code_data.code):Analyze(true)
            print(code_data.code)
            error(err)
        end
    end
end
