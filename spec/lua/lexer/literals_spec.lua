local oh = require("oh")

local function check(code)
   local o = oh.Code(code)
   assert.same(o:Parse():BuildLua(), code)
   return o.Tokens
end

local function tokenize(code)
   return oh.Code(code):Lex().Tokens
end

math.randomseed(os.time())

describe("lexer", function()

   local function gen_all_passes(out, prefix, parts, psign, powers)
      local passes = {}
      for _, p in ipairs(parts) do
         table.insert(passes, p)
      end
      for _, p in ipairs(parts) do
         table.insert(passes, "." .. p)
      end
      for _, a in ipairs(parts) do
         for _, b in ipairs(parts) do
            table.insert(passes, a .. "." .. b)
         end
      end
      for _, a in ipairs(passes) do
         table.insert(out, prefix .. a)
         for _, b in ipairs(powers) do
            table.insert(out, prefix .. a .. psign .. b)
            table.insert(out, prefix .. a .. psign .. "-" .. b)
            table.insert(out, prefix .. a .. psign .. "+" .. b)
         end
      end
   end

   local dec = "0123456789"
   local hex = "0123456789abcdefABCDEF"

   local function r(l, min, max)
      local out = {}
      for _ = 1, math.random(max - min + 1) + min - 1 do
         local x = math.random(#l)
         table.insert(out, l:sub(x, x))
      end
      return table.concat(out)
   end

   local decs = { "0", "0" .. r(dec, 1, 3), "1", r(dec, 1, 3) }
   local hexs = { "0", "0" .. r(hex, 1, 3), "1", r(hex, 1, 3) }

   local passes = {}
   gen_all_passes(passes, "",   decs, "e", decs)
   gen_all_passes(passes, "",   decs, "E", decs)
   gen_all_passes(passes, "0x", hexs, "p", decs)
   gen_all_passes(passes, "0x", hexs, "P", decs)
   gen_all_passes(passes, "0X", hexs, "p", decs)
   gen_all_passes(passes, "0X", hexs, "P", decs)

   it("accepts valid literals", function()
      local code = {}
      for i, p in ipairs(passes) do
         table.insert(code, "local x" .. i .. " = " .. p)
      end
      local input = table.concat(code, "\n")

      -- make sure the amount of tokens
      local tokens = assert(oh.Code(input):Lex())
      assert.equal(#tokens.Tokens, #code*4 + 1)

      -- make sure all the tokens are numbers
      for i = 1, #tokens.Tokens - 1, 4 do
         assert.equal("number", tokens.Tokens[i+3].type)
      end
   end)

   it("should handle shebang", function()
      check"#foo\nlocal lol = 1"
   end)

   it("should handle multiline comments", function()
      assert.same(#check"--[[foo]]", 1)
      assert.same(#check"--[=[foo]=]", 1)
      assert.same(#check"--[==[foo]==]", 1)
      assert.same(#check"--[=======[foo]=======]", 1)
      assert.same(#check"--[=TESTSUITE\n-- utilities\nlocal ops = {}\n--]=]", 6)
      assert.same(#check"foo--[[]].--[[]]bar--[[]]:--[[]]test--[[]](--[[]]1--[[]]--[[]],2--[[]])--------[[]]--[[]]--[[]]", 11)
   end)

   it("should handle strings", function()
      check'a = "a"'
      check"a = 'a'"
      check'a = "a\\z\na"'
   end)

   it("should handle unicode", function()
      assert.same(6, #check"🐵=😍+🙅")
      assert.same(5, #check"print(･✿ヾ╲｡◕‿◕｡╱✿･ﾟ)")
      assert.same(5, #check"print(ด้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็ด้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็ด้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็)")
   end)
end)
