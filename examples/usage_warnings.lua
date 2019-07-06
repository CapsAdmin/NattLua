local util = require("oh.util")
local oh = require("oh.oh")
local path = "examples/scimark.lua"
local code = assert(io.open(path)):read("*all")

local tk = oh.Tokenizer(code)
local ps = oh.Parser()
local an = oh.Analyzer()


local tokens = tk:GetTokens()
local ast = ps:BuildAST(tokens)

an:Walk(ast)

local config = {
    shadowed_upvalues = false,
    globals = true,
}


an:WalkAllEvents(function(event, level)
    if event.type == "local" then
        if event.kind == "create" then

            if #event.upvalue.events == 0 and an:Hash(event.key) ~= "_" then
                local start, stop = event.key:GetStartStop()
                print(oh.FormatError(code, path, "unused local " .. an:Hash(event.key), start, stop))
            end

            if config.shadowed_upvalues then
                if event.upvalue.shadow then
                    local start, stop = event.key:GetStartStop()
                    print(oh.FormatError(code, path, "local " .. an:Hash(event.key) .. " shadows the next local", start, stop))

                    local start, stop = event.upvalue.shadow.key:GetStartStop()
                    print(oh.FormatError(code, path, "shadowed local", start, stop))
                end
            end
        end
    end

    if config.globals then
        if event.type == "global" and not _G[event.key] then
            local start, stop = event.key:GetStartStop()
            print(oh.FormatError(code, path, event.type .. " " .. event.kind .. " " .. event.key:Render(), start, stop))
        end
    end
end)

--print(ps:DumpScope())