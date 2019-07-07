local oh = require("oh")

local function check(tbl)
    for i,v in ipairs(tbl) do
        local ok, err = oh.loadstring(v[1])
        if ok then
            print(ok, v[1])
            error("expected error, but code compiled", 2)
        end
        if not err:find(v[2]) then
            print(err)
            print("~=")
            print(v[2])
            error("error does not match")
        end
    end
end

check({
    {"local foo[123] = true", ".- unexpected symbol"},
    {"/clcret retprio inq tv5 howaw tv4aw exoaw", "unexpected symbol"},
    {"print( “Hello World” )", "expected.-%).-got.-World”"},
    {"foo = {bar = until}, faz = true}", "expected beginning of expression, got.-until"},
    {"foo = {1, 2 3}", "expected.-,.-;.-}.-got.-3"},
    {"if foo = 5 then end", "expected.-then"},
    {"if foo == 5 end", "expected.-then.-got.-end"},
    {"if 0xWRONG then end", "malformed number.-hex notation"},
    {"if true then", "expected.-elseif.-got.-end_of_file"},
    {"a = [[wa", "unterminated multiline string.-expected.-%]%].-reached end of code"},
    {"a = [=[wa", "unterminated multiline string.-expected.-%]=%].-reached end of code"},
    {"a = [=wa", "unterminated multiline string.-expected.-%[=%[.-got.-%[=w"},
    {"a = [=[wa]=", "unterminated multiline string.-expected.-%]=%].-reached end of code"},
    {"0xBEEFp+L", "malformed pow expected number, got L"},
    {"foo(())", "empty parenth"},
    {"a = {", "expected beginning of expression.-end_of_file"},
    {"a = 0b1LOL01", "malformed number L in binary notation"},
    {"a = 'aaaa", "unterminated single quote.-reached end of file"},
    {"a = 'aaaa \ndawd=1", "unterminated single quote"},
    {"foo = !", "unexpected unknown"},
    {"foo = then", "expected beginning of expression.-got.-then"},
    {"--[[aaaa", "unterminated multiline comment.-reached end of code"},
    {"--[[aaaa\na=1", "unterminated multiline comment.-reached end of code"},
    {"::1::", "expected.-letter.-got.-number"},
    {"::", "expected.-letter.-got.-end_of_file"},
})