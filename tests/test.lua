local Lexer = require("oh.lexer")
local Parser = require("oh.parser")
local LuaEmitter = require("oh.lua_emitter")
local Crawler = require("oh.crawler")

local print_util = require("oh.print_util")

local test = {}

function test.transpile(ast, what, config)
    what = what or "lua"
    local self = LuaEmitter(config)
    local res = self:BuildCode(ast)
    local ok, err = loadstring(res)
    if not ok then
        return res, err
    end
    return res, self
end

function test.lex(code, capture_whitespace, name)
    local self = Lexer(code, capture_whitespace)
    self.OnError = function(_, msg, start, stop, ...)
        io.write(print_util.FormatError(code, name or "test", msg, start, stop, ...))
    end

    return self:GetTokens()
end

function test.parse(tokens, code, name)
    local self = Parser()
    self.OnError = function(_, msg, start, stop, ...)
        error(print_util.FormatError(code, name or "test", msg, start, stop, ...))
    end
    return self:BuildAST(tokens)
end

function test.transpile_check(tbl)
    local tokens, ast, new_code, emitter

    tbl.expect = tbl.expect or tbl.code

    local function strip(code)
        local line = code:match("(.-)\n")
        if line then line = line .. "..." end

        return line or code
    end

    local ok = xpcall(function()
        tokens = assert(test.lex(tbl.code, nil, tbl.name))
        ast = assert(test.parse(tokens, tbl.code, tbl.name))
        if tbl.crawl then
            local crawler = Crawler()
            crawler:CrawlStatement(ast)
        end
        new_code, emitter = assert(test.transpile(ast, tbl.name, tbl.config))
    end, function(err)
        print("===================================")
        print(debug.traceback(err))
        print(strip(tbl.code))
        print("===================================")
    end)

    if ok then
        if tbl.compare_tokens then
            local a = assert(test.lex(new_code))
            local b = assert(test.lex(tbl.expect))
            for i = 1, #a do
                if a[i].value ~= b[i].value then
                    ok = false
                    break
                end
            end
        else
            ok = new_code == tbl.expect
        end

        -- lua code with bitwise operators cannot be compared to itself
        if not ok and tbl.code == tbl.expect and emitter and emitter.operator_transformed then
            ok = true
        end

        -- assuming lua 5.3 5.4
        if not ok and type(emitter) == "string" then
            if emitter:find("unexpected symbol near ';'") then
                ok = true
            end
        end

        if not ok then
            print("===================================")
            print("error transpiling code:")
            print(strip(tbl.code))
            print("expected:")
            print(strip(tbl.expect))
            print("got:")
            print(strip(new_code))
            print("===================================")
            error("")
        end
    end

    return ok, new_code
end

function test.dofile(path)
    local f = assert(io.open(path))
    local code = f:read("*all")
    f:close()
    return test.transpile_check({
        code = code,
        expect = code,
        name = path,
    })
end

function test.check_strings(strings)
    for _, v in ipairs(strings) do
        if v == false then
            break
        end
        if type(v) == "table" then
            test.transpile_check(v)
        else
            test.transpile_check({code = v, expect = v})
        end
    end
end

return test