local oh = require("oh")
local C = oh.Code

local function go(tbl, annotate)
    for _, val in ipairs(tbl) do
        local data = not val.expect and {code = val, expect = val} or val

        if annotate then
            data.code.config = data.code.config or {}
            data.code.config.annotate = true
        end

        local ok, err = pcall(function()
            assert(data.code:Lex())
            assert(data.code:Parse())
            if data.analyze then
                assert(data.code:Analyze())
            end
        end)

        if not ok then
            print("===================================")
            print("error transpiling code:")
            print(data.code)
            print(err)
            print("===================================")
            error("")
            return
        end

        local result, emitter = data.code:BuildLua()

        local ok = true

        if data.compare_tokens or data.analyze then
            local tokens = assert(oh.Code(result, "compare_tokens"):Lex()).Tokens
            data.expect:Lex()

            for i = 1, #data.expect.Tokens do
                if tokens[i].value ~= data.expect.Tokens[i].value then
                    ok = false
                    break
                end
            end
        else
            ok = result == data.expect.code
        end

        if not ok and data.code.code == data.expect.code and emitter and emitter.operator_transformed then
            ok = true
        end

        if not ok then
            print("===================================")
            print("error transpiling code:")
            print(data.code)
            print("expected:")
            print(data.expect)
            print("got:")
            print(result)
            print("===================================")
            error("")
        end
    end
end

go {
    C"if 1 then elseif 2 then elseif 3 then else end",
    C"if 1 then elseif 2 then else end",
    C"if 1 then else end",
    C"if 1 then end",

    C"while 1 do end",
    C"repeat until 1",

    C"for i = 1, 2 do end",
    C"for a,b,c,d,e in 1,2,3,4,5 do end",

    C"function test() end",
    C"function test.asdf() end",
    --"function test[asdf]() end",
    --"function test[asdf].sadas:FOO() end",
    C"local function test() end",

    C"local test = function() end",

    C"a = 1",
    C"a,b = 1,2",
    C"a,b = 1",
    C"a,b,c = 1,2,3",
    C"a.b.c, d.e.f = 1, 2",

    C"a()",
    C"a.b:c()",
    C"a.b.c()",
    C"(function(b) return 1 end)(2)",

    C"local a = 1;",
    C"local a,b,c",
    C"local a,b,c = 1,2,3",
    C"local a,c = 1,2,3",
    C"local a = 1,2,3",
    C"local a",
    C"local a = -c+1",
    C"local a = c",
    C"(a)[b] = c",
    C"local a = {[1+2+3] = 2}",
    C"foo = bar",
    C"foo--[[]].--[[]]bar--[[]]:--[[]]test--[[]](--[[]]1--[[]]--[[]],2--[[]])--------[[]]--[[]]--[[]]",
    C"function foo.testadw() end",
    C"asdf.a.b.c[5](1)[2](3)",
    C"while true do end",
    C"for i = 1, 10, 2 do end",
    C"local a,b,c = 1,2,3",
    C"local a = 1\nlocal b = 2\nlocal c = 3",
    C"function test.foo() end",
    C"local function test() end",
    C"local a = {foo = true, c = {'bar'}}",
    C"for k,v,b in pairs() do end",
    C"for k in pairs do end",
    C"foo()",
    C"if true then print(1) elseif false then print(2) else print(3) end",
    C"a.b = 1",
    C"local a,b,c = 1,2,3",
    C"repeat until false",
    C"return true",
    C"while true do break end",
    C"do end",
    C"local function test() end",
    C"function test() end",
    C"function test:foo() end",
    C"goto test ::test::",
    C"#!shebang wadawd\nfoo = bar",
    C"local a,b,c = 1 + (2 + 3) + v()()",
    C"(function() end)(1,2,3)",
    C"(function() end)(1,2,3){4}'5'",
    C"(function() end)(1,2,3);(function() end)(1,2,3)",
    C"local tbl = {a; b; c,d,e,f}",
    C"aslk()",
    C"a = #a()",
    C"a()",
    C"🐵=😍+🙅",
    C"print(･✿ヾ╲｡◕‿◕｡╱✿･ﾟ)",
    C"print(･✿ヾ╲｡◕‿◕｡╱✿･ﾟ)",
    C"print(ด้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็ด้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็ด้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็)",
    C"local a = 1;;;",
    C"local a = (1)+(1)",
    C"local a = (1)+(((((1)))))",
    C"local a = 1 --[[a]];",
    C"local a = 1 --[=[a]=] + (1);",
    C"local a = (--[[1]](--[[2]](--[[3]](--[[4]]4))))",
    C"local a = 1 --[=[a]=] + (((1)));",
    C"a=(foo.bar)()",
    C"a=(foo.bar)",
    C"lol({...})",
    C"if import then end",
    C"if (player:IsValid()) then end",
    C"if not true then end",
    C"local function F (m) end",
    C"msgs[#msgs+1] = string.sub(m, 3, -3)",
    C"a = (--[[a]]((-a)))",

    C"a = 1; b = 2; local a = 3; function a() end while true do end b = c; a,b,c=1,2,3",
    C"if not a then return end",
    C"foo = 'foo'\r\nbar = 'bar'\r\n",

    C";;print 'testing syntax';;",
    C"#testse tseokt osektokseotk\nprint('ok')",
    C"do ;;; end\n; do ; a = 3; assert(a == 3) end;\n;",
    C"--[=TESTSUITE\n-- utilities\nlocal ops = {}\n--]=]",
    C"assert(string.gsub('�lo �lo', '�', 'x') == 'xlo xlo')",

    C'foo = "\200\220\2\3\r"\r\nfoo = "\200\220\2\3"\r\n',
    C"goto:foo()",
    C("a = " .. string.char(34,187,243,193,161,34)),
    C"local a = {foo,bar,faz,}",
    C"local a = {{--[[1]]foo--[[2]],--[[3]]bar--[[4]],--[[5]]faz--[[6]],--[[7]]},}",
    C"local a = {--[[1]]foo--[[2]],--[[3]]bar--[[4]],--[[5]]faz--[[6]]}",

    C"local a = foo.bar\n{\nkey = key,\nhost = asdsad.wawaw,\nport = aa.bb\n}",
    C"_IOW(string.byte'f', 126, 'uint32_t')",
    C"return",
    C"return 1",
    C"function foo(a, ...) end",
    C"function foo(...) end",
    C"a = ( (1) )",
    C"a = (--[[1]](--[[2]]true--[[3]])--[[4]])",

    C"a = foo(0x89abcdef, 1)",
    C"a = foo(0x20EA2, 1)",
    C"a = foo(0Xabcdef.0, 1)",
    C"a = foo(3.1416, 1)",
    C"a = foo(314.16e-2, 1)",
    C"a = foo(0.31416E1, 1)",
    C"a = foo(34e1, 1)",
    C"a = foo(0x0.1E, 1)",
    C"a = foo(0xA23p-4, 1)",
    C"a = foo(0X1.921FB54442D18P+1, 1)",
    C"a = foo(2.E-1, 1)",
    C"a = foo(.2e2, 1)",
    C"a = foo(0., 1)",
    C"a = foo(.0, 1)",
    C"a = foo(0x.P1, 1)",
    C"a = foo(0x.P+1, 1)",
    C"a = foo(0b101001011, 1)",
    C"a = foo(0b101001011ull, 1)",
    C"a = foo(0b101001011i, 1)",
    C"a = foo(0b01_101_101, 1)",
    C"a = foo(0xDEAD_BEEF_CAFE_BABE, 1)",
    C"a = foo(1_1_1_0e2, 1)",
    C"a = foo(1_, 1)",
    C'a = "a\\z\na"',
    C"lol = 1 ÆØÅ",
    C"lol = 1 ÆØÅÆ",
    C"local foo = 0.15",
    --{code = "local --[[#foo = true]]"},

    {
        code = C"return math.maxinteger // 80",
        expect = C"return math.floor(math.maxinteger / 80)",
        compare_tokens = true
    },
    {
        code = C"\xEF\xBB\xBF foo = true",
        expect = C" foo = true"
    },
    {
        code = C"foo(1,2,3,)",
        expect = C"foo(1,2,3)"
    },
    {
        code = C"return math.maxinteger // 80",
        expect = C"return math.floor(math.maxinteger / 80)",
        compare_tokens = true
    },
    {
        code = C"local a = ~1",
        expect = C"local a = bit.bnot(1)",
        compare_tokens = true
    },
    {
        code = C"local a = 1 >> 2",
        expect = C"local a = bit.rshift(1, 2)",
        compare_tokens = true
    },
    {
        code = C"local a = 1 >> 2 << 23",
        expect = C"local a = bit.lshift(bit.rshift(1, 2), 23)",
        compare_tokens = true
    },
    {
        code = C"local a = a++",
        expect = C"local a = (a + 1)",
        compare_tokens = true
    },
    {
        code = C"_ENV = {}",
        expect = C"_ENV={};setfenv(1, _ENV);",
        compare_tokens = true
    },
    {
        code = C"a,_ENV,c = 1,{},2",
        expect = C"a,_ENV,c = 1,{},2;setfenv(1, _ENV);",
        compare_tokens = true
    },

    -- destructuring assignment
    {
        code = C"local {a, b} = {a = true, b = false}",
        expect = C'local a, b = table.destructure({a = true, b = false}, {"a", "b"})',
        compare_tokens = true
    },
    {
        code = C"{a, b} = {a = true, b = false}",
        expect = C'a, b = table.destructure({a = true, b = false}, {"a", "b"})',
        compare_tokens = true
    },
    {
        code = C"local tbl, {a, b} = {a = true, b = false}",
        expect = C'local tbl, a, b = table.destructure({a = true, b = false}, {"a", "b"}, true)',
        compare_tokens = true
    },
    {
        code = C"tbl, {a, b} = {a = true, b = false}",
        expect = C'tbl, a, b = table.destructure({a = true, b = false}, {"a", "b"}, true)',
        compare_tokens = true
    },

    -- spread
    {
        code = C"local a = {...{foo=true}, ...{bar=false}, foo = false}",
        expect = C'local a = table.mergetables{{foo=true}, {bar=false}, {foo=false}}',
        compare_tokens = true
    },
    {
        code = C"local a = {...{foo=true},rofl = 1, lol = 2, ...{bar=false}}",
        expect = C'local a = table.mergetables{{foo=true}, {rofl=1, lol=2,}, {bar=false}}',
        compare_tokens = true
    },
    {
        code = C"local a = {rofl = 1, ...{foo=true}, lol = 2, ...{bar=false}}",
        expect = C'local a = table.mergetables{{rofl=1,},{foo=true}, {lol=2,}, {bar=false}}',
        compare_tokens = true
    },

}

go({
    C"local a:   sometype = foo",
    C"local a:   boolean = foo",
    C"local a:   boolean | true = foo",
    C"local a:   boolean & true = foo",
    C"local a:   boolean & true | false | {} = foo",
    C"local a:   boolean or true = foo",
    C"local a:   true or false = foo",
    C"local a:   list[] = foo",
    C"local a:   list[string, number] = foo",
    C"local a:   list[string, number, foo[]] = foo",
    C"local a:   list[string, number, foo[], {}] = foo",
    C"local a:   list[string, number, foo[], {}] = foo",
    C"local a:   list[string, number, foo[], {a = boolean, b = {}}] = foo",
    C"local a:   list[string, number, foo[], {a = boolean, b = function(string, number): boolean}] = foo",
    C"local a:   {[string] = string} = foo",
    C"local a:   {[string | boolean] = string} = foo",
    C"local a:   function(string, boolean): string[] = foo",
    C"local a:   function(foo: string, bar: boolean): (string | boolean)[] = foo",
    C"local a:   function[(function(): boolean, any, true, false), (function(): boolean, any, true, false)] = foo",
    C"local a:   function[function(): boolean, any, true, false; function(): boolean, any, true, false] = foo",
    C"local a:   function(): boolean, any = foo",
    C"local a:   function(a,b,c) local a = 1 local b = 2 while true do end end = foo",
    C"local a:   foo.bar.faz = foo",
    C"local type = function(a,b,c,...) end",
    C"local type function aaa(a) return a end",
    C"foao(a):bar'a'",
    {
        code = C"local a = 1",
        expect = C"local a: number(1) = 1",
        analyze = true,
    },
    {
        code = C"local a: 1 = 1",
        expect = C"local a: 1 = 1",
        analyze = true,
    },
    {
        code = C"local a: number = 1",
        expect = C"local a: number = 1",
        analyze = true,
    },
    {
        code = C"local a: number | string = 1",
        expect = C"local a: number | string = 1",
        analyze = true,
    },
    {
        code = C"function foo(a: number) end",
        expect = C"function foo(a: number) end",
        analyze = true,
    },
    {
        code = C"function foo(a: number):string return '' end",
        expect = C"function foo(a: number):string return '' end",
        analyze = true,
    },
    {
        code = C"function foo(a: number):string, number return '',1 end",
        expect = C"function foo(a: number):string, number return '',1 end",
        analyze = true,
    },
    {
        code = C"type a = number; local num: a = 1",
        expect = C"local num: a = 1",
        analyze = true,
    },
}, true)