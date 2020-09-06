local oh = require("oh")
local syntax = require("oh.lua.syntax")
local tprint = require("libraries.tprint")

local function tokenize(code)
    return assert(oh.Code(code):Lex()).Tokens
 end

local function parse(code)
    return assert(oh.Code(code):Parse()).Tokens
end

local function one_token(tokens)
    assert(#tokens, 2)
    equal(tokens[2] and tokens[2].type, "end_of_file", 2)
    return tokens[1]
end

test("smoke", function()
    equal(tokenize("")[1].type, "end_of_file")
    equal(one_token(tokenize("a")).type, "letter")
    equal(one_token(tokenize("1")).type, "number")
    equal(one_token(tokenize("(")).type, "symbol")
end)

test("shebang", function()
    equal(tokenize("#foo\nlocal lol = 1")[1].type, "shebang")
end)

test("single quote string", function()
    equal(one_token(tokenize("'1'")).type, "string")
end)

test("double quote string", function()
    equal(one_token(tokenize('"1"')).type, "string")
end)

test("z escaped string", function()
    equal(one_token(tokenize('"a\\z\na"')).type, "string")
end)

test("comment escape", function()
    local tokens = tokenize("a--[[#1]]a")
    equal(tokens[1].type, "letter")
    equal(tokens[2].type, "number")
    equal(tokens[3].type, "letter")
    equal(tokens[4].type, "end_of_file")
end)

test("multiline comments", function()
   equal(#parse"--[[foo]]", 1)
   equal(#parse"--[=[foo]=]", 1)
   equal(#parse"--[==[foo]==]", 1)
   equal(#parse"--[=======[foo]=======]", 1)
   equal(#parse"--[=TESTSUITE\n-- utilities\nlocal ops = {}\n--]=]", 6)
   equal(#parse"foo--[[]].--[[]]bar--[[]]:--[==[]==]test--[[]](--[=[]=]1--[[]]--[[]],2--[[]])--------[[]]--[[]]--[===[]]", 11)
end)

test("unicode", function()
   equal(6, #tokenize"🐵=😍+🙅")
   equal(5, #tokenize"foo(･✿ヾ╲｡◕‿◕｡╱✿･ﾟ)")
   equal(5, #tokenize"foo(ด้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็ด้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็ด้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็)")
end)

test("glua", function()
    equal(one_token(tokenize("/**/foo")).type, "letter")
    equal(one_token(tokenize("/*B*/foo")).type, "letter")
    equal(one_token(tokenize("/*-----*/foo")).type, "letter")
    equal(one_token(tokenize("--asdafsadw\nfoo--awsad asd")).type, "letter")

    equal(syntax.IsPrefixOperator(tokenize("!a")[1]), true)

    equal(syntax.GetBinaryOperatorInfo(tokenize("a != 1")[2]) ~= nil, true)
    equal(syntax.GetBinaryOperatorInfo(tokenize("a && b")[2]) ~= nil, true)
    equal(syntax.GetBinaryOperatorInfo(tokenize("a || b")[2]) ~= nil, true)
end)

do
    math.randomseed(os.time())

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

    test("valid literals", function()
        local code = {}
        for i, p in ipairs(passes) do
            table.insert(code, "local x" .. i .. " = " .. p)
        end
        local input = table.concat(code, "\n")

        -- make sure the amount of tokens
        local code_data = assert(oh.Code(input):Lex())
        equal(#code_data.Tokens, #code*4 + 1)

        -- make sure all the tokens are numbers
        for i = 1, #code_data.Tokens - 1, 4 do
            equal("number", code_data.Tokens[i+3].type)
        end
    end)
end
