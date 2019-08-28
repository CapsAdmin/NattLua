
local oh = require("oh")
local Crawler = require("oh.crawler")
local LuaEmitter = require("oh.lua_emitter")

local code = io.open("oh/lexer.lua"):read("*all")

code = [[
    local type Vec2 = {x = number, y = number}
    local type Vec3 = {z = number} extends Vec2

    local type Base = {
        Test = function(self): number,
    }

    local type Foo = Base extends {
        SetPos = (function(self, pos: Vec3): nil),
        GetPos = (function(self): Vec3),
    }
        
    local x: Foo = {}
    x:SetPos({x = 1, y = 2, z = 3})
    local a = x:GetPos()
    local z = a.x + 1 
    
    local test = x:Test()
]]

local em = LuaEmitter()
local ast = assert(oh.TokensToAST(assert(oh.CodeToTokens(code, "test")), "test", code))

local crawler = Crawler()
crawler.OnEvent = crawler.DumpEvent
crawler.code = code
crawler.name = "test"
crawler:CrawlStatement(ast)

--print(em:BuildCode(ast))
