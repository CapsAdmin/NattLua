local oh = require("oh.oh")

local code = [[1
    2fooøøøøøøøøøøøøøøøøøøøøøøøøøøøøøøøøøøøøøø
    3bar
    4faz    awd
    5adw
    6adw
    7hello
    8world    awd
    9adw
    10adw
    11hello
    12world
    13adw
    14adwøøøøøøøøøøøøøøøøøøøøøøøøøøøøøøøøøøøø
    15øøøøøøøøøøøøøøøøøøøøøøawd
    16OVER HERE
    18awd
    19adw
    20adw
    21hello
    22world    awd
    23adw
    adw
    hello
    world    awd
    adw
    adw
    hello
    world
]]

local util = require("oh.util")

local start, stop

for i, char in ipairs(util.UTF8ToTable(code)) do
    if char == "O" then
        start = i
        stop = i + 9
        break
    end
end

print(oh.FormatError(code, "?", "test", start, stop))