
local oh = require("oh")
local Crawler = require("oh.crawler")
local LuaEmitter = require("oh.lua_emitter")
local types = require("oh.types")

local code = io.open("oh/parser.lua"):read("*all")
local base_lib = io.open("oh/base_lib.oh"):read("*all")

code = [[
function string:split(self: string, sSeparator: string, nMax: number, bRegexp: boolean)
    assert(sSeparator ~= '')
    assert(nMax == nil or nMax >= 1)
    
    local aRecord = {}
    
    if self:len() > 0 then
        local bPlain = not bRegexp
        nMax = nMax or -1
    
        local nField, nStart = 1, 1
        local nFirst,nLast = self:find(sSeparator, nStart, bPlain)
        while nFirst and nMax ~= 0 do
            aRecord[nField] = self:sub(nStart, nFirst-1)
            nField = nField+1
            nStart = nLast+1
            nFirst,nLast = self:find(sSeparator, nStart, bPlain)
            nMax = nMax-1
        end
        aRecord[nField] = self:sub(nStart)
    end
    
    return aRecord
end
]]

code = [==[
    function get_all_factors(number)
        --[[--
        Gets all of the factors of a given number
        
        @Parameter: number
            The number to find the factors of
    
        @Returns: A table of factors of the number
        --]]--
        local factors = {}
        for possible_factor=1, math.sqrt(number), 1 do
            local remainder = number%possible_factor
            
            if remainder == 0 then
                local factor, factor_pair = possible_factor, number/possible_factor
                table.insert(factors, factor)
                
                if factor ~= factor_pair then
                    table.insert(factors, factor_pair)
                end
            end
        end
        
        table.sort(factors)
        return factors
    end
    
    --The Meaning of the Universe is 42. Let's find all of the factors driving the Universe.
    
    the_universe = 42
    factors_of_the_universe = get_all_factors(the_universe)
    
    --Print out each factor
    
    print("Count",	"The Factors of Life, the Universe, and Everything")
    table.foreach(factors_of_the_universe, print)     
]==]

code = [[

    type insert = function(tbl, a, b)
        local pos
        local val
        if b then
            pos = a
            val = b
        else
            val = a
            pos = #tbl.value
            if pos == 0 then
                pos = 1
            end
        end

        local l = types.Type("list")

        for k,v in pairs(tbl) do
            if k ~= "value" then
                tbl[k] = nil
            end
        end

        for k,v in pairs(l) do
            tbl[k] = v
        end

        tbl.value[pos] = val
        tbl.list_type = val
        tbl.length = pos
    end

    local a = {}
    insert(a, 1)
    local c = a
]]

code = base_lib .. "\n" .. code

local em = LuaEmitter()
local ast = assert(oh.TokensToAST(assert(oh.CodeToTokens(code, "test")), "test", code))
local crawler = Crawler()

--crawler.OnEvent = crawler.DumpEvent

crawler.code = code
crawler.name = "test"
crawler:CrawlStatement(ast)

print(em:BuildCode(ast))