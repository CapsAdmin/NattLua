local Lexer = require("nattlua.lexer.lexer")
local terminal = require("nattlua.other.terminal")
local syntax = require("nattlua.syntax.syntax")
terminal.Initialize()

local function table_concatrange(tbl, start, stop)
    local length = stop-start
    local str = {}
    local str_i = 1
    for i = start, stop do
        str[str_i] = tbl[i] or ""
        str_i = str_i + 1
    end
    return table_concat(str)
end

local colors = {
    comment = "#8e8e8e",
    number = "#4453da",
    letter = "#d6d6d6",
    symbol = "#da4453",
    error = "#da4453",
    keyword = "#2980b9",
    string = "#27ae60",
    unknown = "#da4453",
}

for key, hex in pairs(colors) do
    local r,g,b = hex:match("#?(..)(..)(..)")
    r = tonumber("0x" .. r)
    g = tonumber("0x" .. g)
    b = tonumber("0x" .. b)
    colors[key] = {r,g,b}
end
local last_color
set_color = function(what)
    if not colors[what] then
        what = "letter"
    end

    if what ~= last_color then
        local c = colors[what]

        terminal.ForegroundColorFast(c[1], c[2], c[3])
        last_color = what
    end
end

local function styled_write(str)
    last_color = nil

    local tokenizer = Lexer(str)

    while true do
        local type, whitespace, start, stop = tokenizer:ReadSimple()

        if whitespace then
            if type == "line_comment" or type == "multiline_comment" then
                set_color("comment")
            end

            terminal.Write(str:sub(start, stop))
        else

            local chunk = str:sub(start, stop)

            if type == "letter" and (syntax.IsKeywordValue({value = chunk}) or syntax.IsKeyword({value = chunk})) then
                set_color("keyword")
            else
                set_color(type)
            end

            terminal.Write(chunk)
        end

        if type == "end_of_file" then break end
    end

    --set_color("letter")
end

function _G.print(...)
    local len = select("#", ...)

    for i = 1, len do
        local val = select(i, ...)
        styled_write(tostring(val))
        if i ~= len then
            styled_write("\t")
        end
    end

    styled_write("\n")
end

function io.write(...)
    local len = select("#", ...)

    for i = 1, len do
        local val = select(i, ...)
        styled_write(tostring(val))
    end
end