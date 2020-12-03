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
                buffer = buffer:gsub("\n%s+",  "\n" .. ("    "):rep(t-1))
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
                write(tostring(obj), "[", (tostring(key)), "] = ", tostring(val))
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

                local reason = val:GetReasonForExistance()
                if reason ~= "" then
                    write(" -- ", reason)
                end
                write("\n")
            elseif what == "set_environment_value" then
                local key, val = ...
                tab()
                write("_ENV.", self:Hash(key), " = ", tostring(val), "\n")
            elseif what == "enter_scope" then
                local scope, data = ...

                tab()

                if data then
                    if data.type == "function" then
                        local em = require("nattlua.transpiler.emitter")({preserve_whitespace = false})
                        local node = data.function_node
                        
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
                    elseif data.type == "numeric_for_iteration" then
                        write("do -- ", data.i)
                    elseif data.type == "numeric_for" then
                        write("for i = ", data.init, ", ", data.max, ", ", data.step, " do")
                    elseif data.condition then
                        write("if ", tostring(data.condition), " then")
                    else
                        write(data.type, " ")
                    end
                end

                t = t + 1
                write("\n")
            elseif what == "leave_scope" then
                local new_scope, old_scope, data = ...

                t = t - 1
                tab()

                if data then
                    if data.type == "function" then
                        write("end")
                    else
                        write("end")
                    end
                end
                write("\n")

                
            
            elseif what == "enter_conditional_scope" then
                local scope, data = ...

                tab()

                if data then
                    if data.type == "function" then
                        local em = require("nattlua.transpiler.emitter")({preserve_whitespace = false})
                        local node = data.function_node
                        
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
                    elseif data.type == "numeric_for_iteration" then
                        write("do -- ", data.i)
                    elseif data.type == "numeric_for" then
                        write("for i = ", data.init, ", ", data.max, ", ", data.step, " do")
                    elseif data.condition then
                        write("if ", tostring(data.condition), " then")
                    else
                        write(data.type, " ")
                    end
                end

                t = t + 1
                write("\n")
            elseif what == "leave_conditional_scope" then
                local new_scope, old_scope, data = ...

                t = t - 1
                tab()

                if data then
                    if data.type == "function" then
                        write("end")
                    else
                        write("end")
                    end
                end
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
            elseif what == "analyze_unreachable_code_start" then
                tab()
                write("-- BEGIN ANALYZING UNREACHABLE CODE")                
                write("\n")
            elseif what == "analyze_unreachable_code_stop" then
                tab()
                write("-- STOP ANALYZING UNREACHABLE CODE")
                write("\n")
            else
                tab()
                write(what .. " - ", ...)
                write("\n")
            end
        end
    end
end