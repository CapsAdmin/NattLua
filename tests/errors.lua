local oh = require("oh.oh")

local function check(tbl)
    for i,v in ipairs(tbl) do
        local ok, err = oh.loadstring(v[1])
        if ok then error("expected error, but code compiled", 2) end
        if not err:find(v[2]) then
            print(err)
            print("~=")
            print(v[2])
            error("error does not match")
        end
    end
end

check({
    {"local foo[123] = true", "  |          .- unexpected symbol"},
    {"/clcret retprio inq tv5 howaw tv4aw exoaw", "unexpected symbol"},
    {"print( “Hello World” )", "expected.-%).-got.-World”"},
    {"foo = {bar = until}, faz = true}", "expected beginning of expression, got.-until"},
    {"foo = {1, 2 3}", "expected.-,.-;.-}.-got 3"},
    {"if foo = 5 then end", "expected.-then"},
    {"if foo == 5 end", "expected.-then.-got.-end"},
    {"if 0xWRONG then end", "malformed number.-hex notation"},
})