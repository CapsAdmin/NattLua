local test = ...

io.write("running checks...")

local transpile_check = test.transpile_check
local transpile_ok = test.transpile_ok

transpile_ok("print(<lol> </lol>)")
transpile_ok("print(<lol><a></a></lol>)")
transpile_ok("print(<lol lol=1></lol>)")

--transpile_check("a=(foo.bar)")
--transpile_check("a=(foo.bar)()")
transpile_ok"##T:FOOBARRRR=true"if FOOBARRRR == true then else error("compile test failed") end FOOBARRRR=nil
transpile_ok"##P:FOOBARRRR=true"if FOOBARRRR == true then else error("compile test failed") end FOOBARRRR=nil
transpile_ok"##E:FOOBARRRR=true"if FOOBARRRR == true then else error("compile test failed") end FOOBARRRR=nil
transpile_ok"for i = 1, 10 do continue end"
transpile_ok"for i = 1, 10 do if lol then continue end end"
transpile_ok"repeat if lol then continue end until uhoh"
transpile_ok"while true do if false then continue end end"
transpile_ok"local a: foo|bar = 1 as foo"
transpile_ok"local a: foo|bar = 1"
transpile_ok"local test: __add(a: number, b: number): number = function() end"
transpile_ok"local a: FOO|baz = (1 + 1 + adawdad) as fool"
transpile_ok"function test(a: FOO|baz) return 1 + 2 as lol + adawdad as fool end"
transpile_ok"interface foo { foo: bar, lol, lol:foo = 1 }"
transpile_ok("tbl = {a = foo:asdf(), bar:LOL(), foo: a}")

transpile_check"local a = 1;"
transpile_check"local a,b,c"
transpile_check"local a,b,c = 1,2,3"
transpile_check"local a,c = 1,2,3"
transpile_check"local a = 1,2,3"
transpile_check"local a"
transpile_check"local a = -c+1"
transpile_check"local a = c"
transpile_check"(a)[b] = c"
transpile_check"local a = {[1+2+3] = 2}"
transpile_check"foo = bar"
transpile_check"foo--[[]].--[[]]bar--[[]]:--[[]]test--[[]](--[[]]1--[[]]--[[]],2--[[]])--------[[]]--[[]]--[[]]"
transpile_check"function foo.testadw() end"
transpile_check"asdf.a.b.c[5](1)[2](3)"
transpile_check"while true do end"
transpile_check"for i = 1, 10, 2 do end"
transpile_check"local a,b,c = 1,2,3"
transpile_check"local a = 1\nlocal b = 2\nlocal c = 3"
transpile_check"function test.foo() end"
transpile_check"local function test() end"
transpile_check"local a = {foo = true, c = {'bar'}}"
transpile_check"for k,v,b in pairs() do end"
transpile_check"for k in pairs do end"
transpile_check"foo()"
transpile_check"if true then print(1) elseif false then print(2) else print(3) end"
transpile_check"a.b = 1"
transpile_check"local a,b,c = 1,2,3"
transpile_check"repeat until false"
transpile_check"return true"
transpile_check"while true do break end"
transpile_check"do end"
transpile_check"local function test() end"
transpile_check"function test() end"
transpile_check"goto test ::test::"
transpile_check"#!shebang wadawd\nfoo = bar"
transpile_check"local a,b,c = 1 + (2 + 3) + v()()"
transpile_check"(function() end)(1,2,3)"
transpile_check"(function() end)(1,2,3){4}'5'"
transpile_check"(function() end)(1,2,3);(function() end)(1,2,3)"
transpile_check"local tbl = {a; b; c,d,e,f}"
transpile_check"aslk()"
transpile_check"a = #a();;"
transpile_check"a();;"
transpile_check"a();;"
transpile_check("🐵=😍+🙅")
transpile_check("print(･✿ヾ╲｡◕‿◕｡╱✿･ﾟ)")
transpile_check("print(･✿ヾ╲｡◕‿◕｡╱✿･ﾟ)")
transpile_check("print(ด้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็ด้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็ด้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็)")


transpile_check("function global(...) end")
transpile_check("local function printf(fmt, ...) end")
transpile_check("local function printf(fmt, ...) end")
transpile_check("self.IconWidth, self.IconHeight = spritesheet.GetIconSize( icon )")
transpile_check("st, tok = LexLua(src)")
transpile_check("if not self.Emitter then return end")
transpile_check("if !self.Emitter && Aadw || then return end")
transpile_check("tbl = {a = foo:asdf(), bar:LOL()}")
transpile_check("foo = 1 // bar")
transpile_check("foo = 1 /* bar */")
transpile_check("foo = 1 /* bar */")
--transpile_check("if (player:IsValid()) then end")
--transpile_check("if ( IsValid( tr.Entity ) ) then end")
--transpile_check("local foo = (1+(2+(foo:bar())))")
--transpile_check("RunConsoleCommand ('hostname', (table.Random (hostname)))")
assert(test.tokenize([[0xfFFF]])[1].value == "0xfFFF")
test.check_tokens_separated_by_space([[while true do end]])
test.check_tokens_separated_by_space([[if a == b and b + 4 and true or ( true and function ( ) end ) then :: foo :: end]])

io.write(" - OK\n")