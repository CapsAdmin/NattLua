
local oh = require("oh.oh")
local util = require("oh.util")

local test = {}

function test.transpile(ast, what, config)
    what = what or "lua"
    local self = oh.LuaEmitter(config)
    local res = self:BuildCode(ast)
    local ok, err = loadstring(res)
    if not ok then
        return res, err
    end
    return res, self
end

function test.tokenize(code, capture_whitespace, name)
    local self = oh.Tokenizer(code, capture_whitespace)
    self.OnError = function(_, msg, start, stop)
        io.write(oh.FormatError(code, name or "test", msg, start, stop))
    end

    self:ResetState()

    return self:GetTokens()
end

function test.parse(tokens, code)
    local self = oh.Parser()
    self.OnError = function(_, msg, start, stop)
        error(oh.FormatError(code, name or "test", msg, start, stop))
    end
    return self:BuildAST(tokens)
end

do
    local indent = 0

    local function type2string(val)
        if not val then
            return "any"
        end

        local str = ""

        for i,v in ipairs(val) do
            str = str .. v.value.value
            if i ~= #val then
                str = str  .. "|"
            end

            if v.function_arguments then
                str = str .. "("
                for i, arg in ipairs(v.function_arguments) do
                    str = str .. tostring(arg.value.value) .. ": " .. type2string(arg.data_type)
                    if i ~= #v.function_arguments then
                        str = str .. ", "
                    end
                end
                str = str .. "): " .. type2string(v.function_return_type)
            end
        end

        return str
    end

    function test.dump_ast(tbl, blacklist)
        if tbl.type == "value" and tbl.value.type and tbl.value.value then
            io.write(("\t"):rep(indent))
            io.write(tbl.value.type, ": ", tbl.value.value, " as ", type2string(tbl.value.data_type), "\n")
        else
            for k,v in pairs(tbl) do
                if type(v) ~= "table" then
                    io.write(("\t"):rep(indent))
                    io.write(k, " = ", tostring(v), "\n")
                end
            end

            for k,v in pairs(tbl) do
                if type(v) == "table" and k ~= "tokens" and k ~= "whitespace" then
                    if v.type == "value" and v.value.type and v.value.value then
                        io.write(("\t"):rep(indent))
                        io.write(k, ": [", v.value.type, ": ", tostring(v.value.value), " as ", type2string(v.data_type), "]\n")
                        if v.suffixes then
                            indent = indent + 1
                            io.write(("\t"):rep(indent))
                            io.write("suffixes", ":", "\n")
                            test.dump_ast(v.suffixes, blacklist)
                            indent = indent - 1
                        end
                    end
                end
            end

            for k,v in pairs(tbl) do
                if type(v) == "table" and k ~= "tokens" and k ~= "whitespace" then
                    if v.type == "value" and v.value.type and v.value.value then

                    else
                        io.write(("\t"):rep(indent))
                        io.write(k, ":", "\n")
                        indent = indent + 1
                        test.dump_ast(v, blacklist)
                        indent = indent - 1
                    end
                end
            end
        end
	end
end

function test.dump_tokens(tokens, code)
    for _, v in ipairs(tokens) do
        for _, v in ipairs(v.whitespace) do
            io.write(code:usub(v.start, v.stop))
        end

        io.write("⸢" .. code:usub(v.start, v.stop) .. "⸥")
    end
end

function test.transpile_fail_check(code)
    local ok = pcall(function() test.parse(test.tokenize(code), code) end) == false
    if not ok then
        print(code)
        print("shouldn't compile")
    end
end


function test.transpile_ok(code, path, config)
    local tokens, ast, new_code, lua_err

    local ok = xpcall(function()
        tokens = test.tokenize(code)
        ast = test.parse(tokens, code)
        new_code, lua_err = test.transpile(ast, config)
    end, function(err)
        print("===================================")
        print(debug.traceback(err))
        print(path or code)
        print("===================================")
    end)

    if ok then
        --print(new_code, " - OK!\n")
        return new_code, lua_err
    end
end

function test.transpile_check(tbl)
    local tokens, ast, new_code, emitter


    local function strip(code)
        local line = code:match("(.-)\n")
        if line then line = line .. "..." end

        return line or code
    end

    local ok = xpcall(function()
        tokens = assert(test.tokenize(tbl.code, nil, tbl.name))
        ast = assert(test.parse(tokens, tbl.code, tbl.name))
        new_code, emitter = assert(test.transpile(ast, tbl.name, tbl.config))
    end, function(err)
        print("===================================")
        print(debug.traceback(err))
        print(strip(tbl.code))
        print("===================================")
    end)

    if ok then
        if tbl.compare_tokens then
            local a = assert(test.tokenize(new_code))
            local b = assert(test.tokenize(tbl.expect))
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

            if jit.os == "Linux" or jit.os == "OSX" then
                local f = io.open("got.lua", "w") f:write(new_code) f:close()
                local f = io.open("expect.lua", "w") f:write(tbl.expect) f:close()

                os.execute("diff -d ./expect.lua ./got.lua")

                --os.remove("got.lua")
                os.remove("expect.lua")
            end
        end
    end

    return ok, new_code
end

function test.dofile(path)
    local f = assert(io.open(path))
    local code = f:read("*all")
    f:close()
    code = util.RemoveBOMHeader(code)
    return test.transpile_check({
        code = code,
        expect = code,
        name = path,
    })
end



function test.check_tokens_separated_by_space(code)
    local tokens = test.tokenize(code)
    local i = 1
    for expected in code:gmatch("(%S+)") do
        if tokens[i].type == "unknown" then
            error("token " .. tokens[i].value .. " is unknown")
        end

        if tokens[i].value ~= expected then
            error("token " .. tokens[i].value .. " does not match " .. expected)
        end

        i = i + 1
    end
end

function test.print_ast(code)
    local tokens = tokenize(code)
    test.dump_ast(test.parse(tokens, code, true))
end

io.write("TESTING") io.flush()
--assert(loadfile("tests/random_tokens.lua"))(test)
assert(loadfile("tests/transpile_equal.lua"))(test)
assert(loadfile("tests/errors.lua"))(test)
if jit.os == "Linux" or jit.os == "OSX" then
    for path in io.popen("find ."):lines() do
        if path:sub(-4) == ".lua" and not path:find("10mb") then
            test.dofile(path, {name = path})
        end
    end
end
io.write(" - OK\n")

do return end

for name in io.popen("ls tests/random_files"):read("*all"):gmatch("(.-)\n") do
    io.write(name)
    if test.dofile("tests/random_files/" .. name) then
        io.write(" - OK\n")
    else
        io.write(" - FAIL\n")
    end
end