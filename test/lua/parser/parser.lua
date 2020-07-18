local oh = require("oh")

local function check(code)
    local c = assert(assert(oh.Code(code)):Parse())
    --c.SyntaxTree:Dump()
    local new_code = assert(c:Emit())
    equal(new_code, code)
    return new_code
end

it("empty code", function()
    check""
end)

it("empty return statement", function()
    check"return true"
end)

it("do statement", function()
    check"do end"
    check"do do end end"
end)

it("while statement", function()
    check"while 1 do end"
end)

it("repeat until statement", function()
    check"repeat until 1"
end)

it("numeric for loop", function()
    check"for i = 1, 1 do end"
    check"for i = 1, 1, 1 do end"
end)

it("generic for loop", function()
    check"for k,v in a do end"
    check"for a,b,c,d,e,f,g in a do end"
    check"for a,b,c,d,e,f,g in a,b,c,d,e,f,g do end"
end)

it("function statements", function()
    check"function test() end"
    check"local function test() end"
    check"function foo.bar() end"
    check"function foo.bar.baz() end"
    check"function foo:bar() end"
    check"local test = function() end"
end)

it("call expressions", function()
    check"a()"
    check"a.b()"
    check"a.b.c()"
    check"a.b:c()"
    check"(function(b) return 1 end)(2)"
    check"foo.a.b.c[5](1)[2](3)"
    check"foo(1)'1'{1}[[1]][1]\"1\""
    check"a=(foo.bar)()"
    check"lol({...})"
end)

it("if statements", function()
    check"if 1 then end"
    check"if 1 then else end"
    check"if 1 then elseif 2 then else end"
    check"if 1 then elseif 2 then elseif 3 then else end"
end)

it("local declarations", function()
    check"local a"
    check"local a = 1"
    check"local a = 1,2,3"
    check"local a,b,c = 1,2,3"
    check"local a,c = 1,2,3"
end)

it("global declarations", function()
    check"a = 1"
    check"a = 1,2,3"
    check"a,b,c = 1,2,3"
    check"a,c = 1,2,3"
end)

it("object assignments", function()
    check"a[b] = a"
    check"(a)[b] = a"
    check"foo.bar.baz[b] = a"
    check"foo.bar.baz = a"
    check"foo.bar.baz = a"
end)

it("optional semicolons", function()
    check"local a = 1;"
    check"local a = 1;local a = 1"
    check"local a = 1;;;"
    check";;foo 'testing syntax';;"
    check"#testse tseokt osektokseotk\nprint('ok')"
    check"do ;;; end\n; do ; a = 3; assert(a == 3) end;\n;"
end)

it("parenthesis", function()
    check"local a = (1)+(1)"
    check"local a = (1)+(((((1)))))"
    check"local a = 1 --[[a]];"
    check"local a = 1 --[=[a]=] + (1);"
    check"local a = (--[[1]](--[[2]](--[[3]](--[[4]]4))))"
    check"local a = 1 --[=[a]=] + (((1)));"
    check"a = (--[[a]]((-a)))"
end)

it("parser errors", function()
    local function check(tbl)
        for i,v in ipairs(tbl) do
            local ok, err = oh.load(v[1])
            if ok then
                io.write(ok, v[1], "\n")
                error("expected error, but code compiled", 2)
            end
            if not err:find(v[2]) then
                io.write(err, "\n")
                io.write("~=", "\n")
                io.write(v[2], "\n")
                error("error does not match")
            end
        end
    end

    check({
        {"a,b", "expected assignment or call expression"},
        {"local foo[123] = true", ".- expected assignment or call expression"},
        {"/clcret retprio inq tv5 howaw tv4aw exoaw", "expected assignment or call expression"},
        {"foo( “Hello World” )", "expected.-%).-got.-World”"},
        {"foo = {bar = until}, faz = true}", "expected beginning of expression, got.-until"},
        {"foo = {1, 2 3}", "expected.-,.-;.-}.-got.-3"},
        {"if foo = 5 then end", "expected.-then"},
        {"if foo == 5 end", "expected.-then.-got.-end"},
        {"if 0xWRONG then end", "malformed number.-hex notation"},
        {"if true then", "expected.-elseif.-got.-end_of_file"},
        {"a = [[wa", "expected multiline string.-expected.-%]%].-reached end of code"},
        {"a = [=[wa", "expected multiline string.-expected.-%]=%].-reached end of code"},
        {"a = [=wa", "expected multiline string.-expected.-%[=%[.-got.-%[=w"},
        {"a = [=[wa]=", "expected multiline string.-expected.-%]=%].-reached end of code"},
        {"0xBEEFp+L", "malformed pow expected number, got L"},
        {"foo(())", "empty parenth"},
        {"a = {", "expected beginning of expression.-end_of_file"},
        {"a = 0b1LOL01", "malformed number L in binary notation"},
        {"a = 'aaaa", "expected single quote.-reached end of file"},
        {"a = 'aaaa \ndawd=1", "expected single quote"},
        {"foo = !", "expected assignment or call expression got.-unknown"},
        {"foo = then", "expected beginning of expression.-got.-then"},
        {"--[[aaaa", "expected multiline comment.-reached end of code"},
        {"--[[aaaa\na=1", "expected multiline comment.-reached end of code"},
        {"::1::", "expected.-letter.-got.-number"},
        {"::", "expected.-letter.-got.-end_of_file"},
        {"!!!!!!!!!!!", "expected.-got.-unknown"},
        {"do do end", "expected.-end.-got.-"},
        {"\n\n\nif !test then end", "expected.-then.-got.-!"},
    })
end)
