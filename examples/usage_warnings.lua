local util = require("oh.util")
local oh = require("oh.oh")
local path = "oh/lua_emitter.lua"
local code = assert(io.open(path)):read("*all")

local tk = oh.Tokenizer(code)
local ps = oh.Parser({record_nodes = true})

local tokens = tk:GetTokens()
local ast = ps:BuildAST(tokens)

ps:WalkAllEvents(function(event, level)
    if event.type == "local" then
        if event.kind == "create" then
            if #event.upvalue.events == 0 and event.key ~= "_" then
                local start, stop = event.node:GetStartStop()
                print(oh.FormatError(code, path, "unused local " .. event.key, start, stop))
            end
            if event.upvalue.shadow then
                local start, stop = event.node:GetStartStop()
                print(oh.FormatError(code, path, "local " .. event.key .. " shadows the next local", start, stop))

                local start, stop = event.upvalue.shadow.node:GetStartStop()
                print(oh.FormatError(code, path, "shadowed local", start, stop))
            end
        end
    end

    if event.type == "global" and not _G[event.key] then
        local start, stop = event.node:GetStartStop()
        print(oh.FormatError(code, path, event.type .. " " .. event.kind .. " " .. event.node:Render(), start, stop))
    end
end)

--print(ps:DumpScope())