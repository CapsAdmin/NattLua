local oh = require("oh")

--io.write("generating random tokens ...")
local tokens = {
    ",", "=", ".", "(", ")", "end", ":", "function", "self", "then", "}", "{", "[", "]",
    "local", "if", "return", "ffi", "tbl", "1", "cast", "i", "0", "==",
    "META", "library", "CLIB", "or", "do", "v", "..", "+", "for", "type", "-", "x",
    "str", "s", "data", "y", "and", "in", "true", "info", "steamworks", "val", "not",
    "table", "2", "name", "path", "#", "...", "nil", "new", "key", "render", "ipairs",
    "else", "false", "e", "b", "elseif", "*", "id", "math", "a", "size", "lib", "pos",
    "gine", "vfs", "insert", "buffer", "~=", "t", "k", "out", "table_only",
    "flags", "gl", "render2d", "_", "/", "4", "env", "chunk", ";", "Color", "3",
    "pairs", "line", "format", "count", "0xFFFF", "0b10101", "10.52032", "0.123123"
}

local whitespace_tokens = {
    " ",
    "\t",
    "\n\t \n",
    "\n",
    "\n\t   ",
    "--[[aaaaaa]]",
    "--[[\n\n]]--what\n",
}

local code = {}
local total = 100000
local whitespace_count = 0

for i = 1, total do
    math.randomseed(i)

    if math.random() < 0.5 then
        if math.random() < 0.25 then
            code[i] = tostring(math.random()*100000000000000)
        else
            code[i] = "\"" .. tokens[math.random(1, #tokens)] .. "\""
        end
    else
        code[i] = " " .. tokens[math.random(1, #tokens)] .. " "
    end

    if math.random() > 0.75 then
        code[i] = code[i] .. whitespace_tokens[math.random(1, #whitespace_tokens)]:rep(math.random(1,4))
        whitespace_count = whitespace_count + 1
    end
end

local code = table.concat(code)
--io.write(" - OK! ", ("%0.3f"):format(#code/1024/1024), "Mb of lua code\n")

do
    --io.write("tokenizing random tokens with capture_whitespace ...")
    local t = os.clock()
    local res = assert(oh.Code(code, nil, {capture_whitespace = true}):Lex())
    local total = os.clock() - t
    --io.write(" - OK! ", total, " seconds / ", #res, " tokens\n")
end

do
    --io.write("tokenizing random tokens without capture_whitespace ...")
    local t = os.clock()
    local res = assert(oh.Code(code, nil, {capture_whitespace = false}):Lex())
    local total = os.clock() - t
    --io.write(" - OK! ", total, " seconds / ", #res, " tokens\n")
end