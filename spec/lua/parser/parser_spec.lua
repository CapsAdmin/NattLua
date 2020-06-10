local oh = require("oh")

local function check(code)
    assert.same(assert(assert(oh.Code(code)):Parse()):BuildLua(), code)
end

describe("parser", function()
    it("should handle empty code", function()
        check""
    end)

    it("should handle an empty return statement", function()
        check"return true"
    end)

    it("should handle do statement", function()
        check"do end"
        check"do do end end"
    end)

    it("should parse while statement", function()
        check"while 1 do end"
    end)

    it("should parse repeat until statement", function()
        check"repeat until 1"
    end)

    it("should parse numeric for loop", function()
        check"for i = 1, 1 do end"
        check"for i = 1, 1, 1 do end"
    end)

    it("should parse generic for loop", function()
        check"for k,v in a do end"
        check"for a,b,c,d,e,f,g in a do end"
        check"for a,b,c,d,e,f,g in a,b,c,d,e,f,g do end"
    end)

    it("should parse function statements", function()
        check"function test() end"
        check"local function test() end"
        check"function foo.bar() end"
        check"function foo.bar.baz() end"
        check"function foo:bar() end"
        check"local test = function() end"
    end)

    it("should parse call expressions", function()
        check"a()"
        check"a.b()"
        check"a.b.c()"
        check"a.b:c()"
        check"(function(b) return 1 end)(2)"
        check"foo.a.b.c[5](1)[2](3)"
        check"foo(1)'1'{1}[[1]]\"1\"*1"
        check"a=(foo.bar)()"
        check"lol({...})"
    end)

    it("should parse if statements", function()
        check"if 1 then end"
        check"if 1 then else end"
        check"if 1 then elseif 2 then else end"
        check"if 1 then elseif 2 then elseif 3 then else end"
    end)

    it("should parse local declarations", function()
        check"local a"
        check"local a = 1"
        check"local a = 1,2,3"
        check"local a,b,c = 1,2,3"
        check"local a,c = 1,2,3"
    end)

    it("should parse global declarations", function()
        check"a = 1"
        check"a = 1,2,3"
        check"a,b,c = 1,2,3"
        check"a,c = 1,2,3"
    end)

    it("should parse object assignments", function()
        check"a[b] = a"
        check"(a)[b] = a"
        check"foo.bar.baz[b] = a"
        check"foo.bar.baz = a"
        check"foo.bar.baz = a"
    end)

    it("should handle optional semicolons", function()
        check"local a = 1;"
        check"local a = 1;local a = 1"
        check"local a = 1;;;"
        check";;print 'testing syntax';;"
        check"#testse tseokt osektokseotk\nprint('ok')"
        check"do ;;; end\n; do ; a = 3; assert(a == 3) end;\n;"
    end)

    it("should parse parenthesis", function()
        check"local a = (1)+(1)"
        check"local a = (1)+(((((1)))))"
        check"local a = 1 --[[a]];"
        check"local a = 1 --[=[a]=] + (1);"
        check"local a = (--[[1]](--[[2]](--[[3]](--[[4]]4))))"
        check"local a = 1 --[=[a]=] + (((1)));"
        check"a = (--[[a]]((-a)))"
    end)
end)