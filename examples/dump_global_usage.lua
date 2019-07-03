local util = require("oh.util")
local oh = require("oh.oh")
local path = "oh/tokenizer.lua"
local code = io.open(path):read("*all")

local tk = oh.Tokenizer(code)
local ps = oh.Parser()

local tokens = tk:GetTokens()
local ast = ps:BuildAST(tokens)

ps:WalkAllEvents(function(event, level)
    if event.type == "global" then
        local start, stop = (event.key_node or event.val):GetStartStop()
        print(oh.FormatError(code, path, event.type .. " " .. event.kind .. " " .. event.val:Render(), start, stop))
    end
end)