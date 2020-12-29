return function(META) 
    function META:FireEvent(what, ...)
        if self.suppress_events then return end

        if self.OnEvent then
            self:OnEvent(what, ...)
        end
    end

    do
        local t = 0

        local function tab()
            io.write(("    "):rep(t))
        end

        local function write(...)
            local buffer = ""
            for i = 1, select("#", ...) do
                buffer = buffer .. tostring(select(i, ...))
            end

            if buffer:find("\n.") then
                --buffer = buffer:gsub("\n%s+",  "\n" .. ("    "):rep(t-1))
                buffer = buffer:gsub("\n", "\n" .. ("    "):rep(t))
            end

            io.write(buffer)
        end

        function META:DumpEvent(what, ...)
            if what == "create_global" then
                local key, val = ...
                write(what, " - ")
                tab()
                write(key:Render())
                if val then
                    write(" = ")
                    write(tostring(val))
                end
                write("\n")
            elseif what == "newindex" then
                local obj, key, val = ...
                tab()
                if obj.upvalue then
                    write(obj.upvalue.key)
                else
                    write(obj)
                end
                write("[", tostring(key), "] = ", tostring(val))
                write("\n")
            elseif what == "mutate_upvalue" then
                local key, val = ...
                tab()
                write(self:Hash(key), " = ", tostring(val))
                write("\n")
            elseif what == "upvalue" then
                local key, val, env, argument_position = ...
                tab()

                if not argument_position then
                    write("local ")
                end
                write(self:Hash(key))
                if val then
                    write(" = ")
                    write(tostring(val))
                end

                write("\n")
            elseif what == "set_environment_value" then
                local key, val = ...
                tab()
                write("_ENV.", self:Hash(key), " = ", tostring(val), "\n")
            elseif what == "enter_scope_do" then
                local scope, data = ...
                tab()
                write("do")
                t = t + 1
                write("\n")
            elseif what == "enter_scope_numeric_for" then
                local init, max, step = ...
                tab()
                write("for i = ", init, ", ", max, ", ", step, " do")
                t = t + 1
                write("\n")
            elseif what == "enter_scope_generic_for" then
                local keys, values = ...
                tab()

                local keys_str = {}
                for i,v in ipairs(keys) do keys_str[i] = v:Render() end

                write("for ", table.concat(keys_str, ", "))
                write(" in ")

                local values_str = {}
                for i,v in ipairs(values:GetData()) do values_str[i] = tostring(v) end
                write(table.concat(values_str, ", "))
                write(" do")
                    
                t = t + 1
                write("\n")
            elseif what == "enter_scope_if" then
                local exp, condition, kind = ...
                tab()

                if kind == "if" or kind == "elseif" then
                    write(kind, " ", exp:Render(), " then -- = ", tostring(condition))
                elseif kind == "else" then
                    write("else")
                end

                t = t + 1
                write("\n")
            elseif what == "enter_scope_function" then
                local function_node = ...
                tab()
                local em = require("nattlua.transpiler.emitter")({preserve_whitespace = false})
                local node = function_node
                
                if node.tokens["identifier"] then
                    em:EmitToken(node.tokens["identifier"])
                elseif node.expression then
                    em:EmitExpression(node.expression)
                else
                    em:Emit("function")
                end

                em:EmitToken(node.tokens["arguments("])
                em:EmitIdentifierList(node.identifiers)
                em:EmitToken(node.tokens["arguments)"])

                write(em:Concat(), " do")
                t = t + 1
                write("\n")
            elseif what == "leave_scope" then
                t = t - 1
                tab()
                write("end")
                write("\n")            
            elseif what == "external_call" then
                local node, type = ...
                tab()
                write(node:Render(), " - (", tostring(type), ")")
                write("\n")
            elseif what == "call" then
                --write(what, " - ")
                local exp, return_values = ...
                tab()
                if return_values then
                    local str = {}
                    for i,v in ipairs(return_values) do
                        str[i] = tostring(v)
                    end
                    write(table.concat(str, ", "))
                end
                write(" = ", exp:Render())
                write("\n")
            elseif what == "function_spec" then
                local func = ...
                tab()
                write("-- ", what, " - ")
                write(tostring(func))
                write("\n")
            elseif what == "return" then
                local values = ...
                tab()
                write(what)
                if values then
                    write(" ")
                    for i, v in ipairs(values) do
                        write(tostring(v))
                        if i ~= #values then
                            write(", ")
                        end
                    end
                end
                write("\n")
            elseif what == "merge_iteration_scopes" then
                tab()
                write("-- merged scope result: \n")
            elseif what == "analyze_unreachable_function_start" then
                local func, count, total = ...
                write("-- START analyzing unreachable function ", tostring(func:GetNode()), " ", count, "/", total)                
                write("\n")
            elseif what == "analyze_unreachable_function_stop" then
                local func, count, total, seconds = ...
                write("-- STOP analyzing unreachable function ", tostring(func:GetNode()), " ", count, "/", total , " took ", seconds , " seconds")                
                write("\n")
            elseif what == "analyze_unreachable_code_start" then
                local total = ...
                tab()
                write("-- BEGIN ANALYZING UNREACHABLE CODE")                
                write("\n")
                write("-- going to analyze ", total, " functions")
                write("\n")
            elseif what == "analyze_unreachable_code_stop" then
                local count, total = ...
                tab()
                write("-- STOP ANALYZING UNREACHABLE CODE")
                write("-- analyzed ", count, "/", total, " functions")
                write("\n")
            else
                tab()
                write(what .. " - ", ...)
                write("\n")
            end
        end
    end
end