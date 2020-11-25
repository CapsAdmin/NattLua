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
                write("local ")
                write(self:Hash(key))
                if val then
                    write(" = ")
                    write(tostring(val))
                end
                if argument_position then
                    write(" -- argument #", argument_position)
                end
                write("\n")
            elseif what == "set_global" then
                local key, val = ...
                tab()
                write("_ENV.", self:Hash(key), " = ", tostring(val))
            elseif what == "enter_scope" then
                local scope = ...

                tab()

                if scope.event_data.type == "function" then
                    write("do -- ", scope.event_data.function_node)
                else
                    write(scope.event_data.type, " ")
                end

                local data = scope.event_data
                if data and data.condition then
                    write(tostring(data.condition), " then")
                end

                t = t + 1
                write("\n")
            elseif what == "leave_scope" then
                local _, extra_node, scope = ...
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
                write(what, " - ")
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
            elseif what == "analyze_unreachable_code_start" then
                tab()
                write("=== BEGIN ANALYZE UNREACHABLE CODE ===")                
                write("\n")
            elseif what == "analyze_unreachable_code_stop" then
                tab()
                write("=== ===")
                write("\n")
            else
                tab()
                write(what .. " - ", ...)
                write("\n")
            end
        end
    end
end