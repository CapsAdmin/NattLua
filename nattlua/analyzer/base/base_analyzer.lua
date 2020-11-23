local types = require("nattlua.types.types")
local helpers = require("nattlua.other.helpers")
local list = require("nattlua.other.list")
local LexicalScope = require("nattlua.other.lexical_scope")

return function(META)
    local table_insert = table.insert

    function META:StringToNumber(node, str)
        if str:sub(1,2) == "0b" then
            return tonumber(str:sub(3))
        end

        local num = tonumber(str)
        if not num then
            self:Error(node, "unable to convert " .. str .. " to number")
        end
        return num
    end

    require("nattlua.analyzer.base.scopes")(META)
    require("nattlua.analyzer.base.events")(META)
    require("nattlua.analyzer.base.return_statements")(META)
    require("nattlua.analyzer.base.error_handling")(META)

    function META:AnalyzeExpressions(expressions, env)
        if not expressions then return end
        local out = list.new()
        for _, expression in ipairs(expressions) do
            local ret = {self:AnalyzeExpression(expression, env)}
            for _,v in ipairs(ret) do
                table.insert(out, v)
            end
        end
        return out
    end

    do
        local function call(self, obj, arguments, node)
            -- diregard arguments and use function's arguments in case they have been maniupulated (ie string.gsub)
            arguments = obj:GetArguments()
            self:Assert(node, self:Call(obj, arguments, node))
        end

        function META:CallMeLater(...)
            self.deferred_calls = self.deferred_calls or {}
            table.insert(self.deferred_calls, 1, {...})
        end

        function META:AnalyzeUnreachableCode()
            if not self.deferred_calls then
                return
            end

            self.processing_deferred_calls = true 

            self:ResetReturnState()

            for _,v in ipairs(self.deferred_calls) do
                if not v[1].called and v[1].explicit_arguments then
                    call(self, table.unpack(v))
                end
            end

            for _,v in ipairs(self.deferred_calls) do
                if not v[1].called and not v[1].explicit_arguments then
                    call(self, table.unpack(v))
                end
            end

            self.processing_deferred_calls = false
            self.deferred_calls = nil
        end
    end

    do
        local helpers = require("nattlua.other.helpers")

        function META:CompileLuaTypeCode(code, node)
            
            -- append newlines so that potential line errors are correct
            if node.code then
                local start, stop = helpers.LazyFindStartStop(node)
                local line = helpers.SubPositionToLinePosition(node.code, start, stop).line_start
                code = ("\n"):rep(line - 1) .. code
            end

            local func, err = load(code, node.name)

            if not func then
                self:FatalError(err)
            end

            return func
        end

        function META:CallLuaTypeFunction(node, func, ...)
            setfenv(func, setmetatable({
                nl = require("nattlua"),
                types = types,
                analyzer = self,
            }, {
                __index = _G
            }))

            local res = {pcall(func, ...)}

            local ok = table.remove(res, 1)

            if not ok then 
                local msg = tostring(res[1])

                local name = debug.getinfo(func).source
                if name:sub(1, 1) == "@" then -- is this a name that is a location?
                    local line, rest = msg:sub(#name):match("^:(%d+):(.+)") -- remove the file name and grab the line number
                    if line then
                        local f, err = io.open(name:sub(2), "r")
                        if f then
                            local code = f:read("*all")
                            f:close()
                            
                            local start = helpers.LinePositionToSubPosition(code, tonumber(line), 0)
                            local stop = start + #(code:sub(start):match("(.-)\n") or "") - 1

                            msg = helpers.FormatError(code, name, rest, start, stop)
                        end
                    end
                end
                
                local trace = self:TypeTraceBack()
                if trace then
                    msg = msg .. "\ntraceback:\n" .. trace
                end

                self:Error(node, msg)
            end

            return table.unpack(res)
        end

        function META:TypeTraceBack()
            if not self.call_stack then return "" end

            local str = ""

            for i,v in ipairs(self.call_stack) do 
                local callexp = v.call_expression
                local func_str

                if not v.func then
                    func_str = tostring(v.obj)
                else
                    local lol =  v.func.statements
                    v.func.statements = {}
                    func_str = v.func:Render()
                    v.func.statements = lol
                end
        
                local start, stop = helpers.LazyFindStartStop(callexp)
                local part = helpers.FormatError(self.code_data.code, self.code_data.name, "", start, stop, 1)
                if str:find(part, nil, true) then
                    str = str .. "*"
                else
                    str = str .. part .. "#" .. tostring(i) .. ": " .. self.code_data.name
                end
            end

            return str
        end
    end

end