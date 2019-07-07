local oh = require("oh")

for i = 1, 100 do
    math.randomseed(os.clock())

    local code = {}

    for i = 1, 100 do
        code[i] = string.char(math.random(255))
    end

    code = table.concat(code)

    print(oh.loadstring(code))
end