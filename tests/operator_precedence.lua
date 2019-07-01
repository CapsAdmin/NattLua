local oh = require("oh.oh")

local function check(tbl)
    for i, val in ipairs(tbl) do
        local code = "a = " .. val[1]
        local ast = assert(oh.TokensToAST(assert(oh.CodeToTokens(code)), "test " .. i, code))

        local expr = ast:FindStatementsByType("assignment")[1].expressions_right[1]
        local res = expr:DumpPresedence()
        if val[2] ~= res then
            print("EXPECT: " .. val[2])
            print("GOT   : " .. res)
        end
    end
end

check {
    {"a.b.c.d.e.f()", "call(.(.(.(.(.(a, b), c), d), e), f))"},
    {"(foo.bar())", "call(.(foo, bar))"},
    {[[-1^21+2+a(1,2,3)()[1]""++ ÆØÅ]], [[+(+(^(-(1), 21), 2), ÆØÅ(++(call(expression_index(call(call(a, 1, 2, 3)), 1), ""))))]]},
}