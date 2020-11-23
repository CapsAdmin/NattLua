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

        function META:DumpEvent(what, ...)

            if what == "create_global" then
                tab()
                io.write(what, " - ")
                local key, val = ...
                io.write(key:Render())
                if val then
                    io.write(" = ")
                    io.write(tostring(val))
                end
                io.write("\n")
            elseif what == "newindex" then
                tab()
                local obj, key, val = ...
                io.write(tostring(obj), "[", (tostring(key)), "] = ", tostring(val))
                io.write("\n")
            elseif what == "mutate_upvalue" then
                tab()
                local key, val = ...
                io.write(self:Hash(key), " = ", tostring(val))
                io.write("\n")
            elseif what == "upvalue" then
                tab()

                io.write("local ")
                local key, val = ...
                io.write(self:Hash(key))
                if val then
                    io.write(" = ")
                    io.write(tostring(val))
                end
                io.write("\n")
            elseif what == "set_global" then
                tab()
                local key, val = ...
                io.write("_ENV.", self:Hash(key), " = ", tostring(val))
                io.write("\n")
            elseif what == "enter_scope" then
                local scope = ...
                tab()
                t = t + 1

                io.write(scope.event_data.type, " ")
                
                local data = scope.event_data
                if data and data.condition then
                    io.write(tostring(data.condition), " then")
                end

                io.write("\n")
            elseif what == "leave_scope" then
                local _, extra_node, scope = ...
                t = t - 1
                tab()
                io.write("end")
                io.write("\n")
            elseif what == "external_call" then
                tab()
                local node, type = ...
                io.write(node:Render(), " - (", tostring(type), ")")
                io.write("\n")
            elseif what == "call" then
                tab()
                --io.write(what, " - ")
                local exp, return_values = ...
                if return_values then
                    local str = {}
                    for i,v in ipairs(return_values) do
                        str[i] = tostring(v)
                    end
                    io.write(table.concat(str, ", "))
                end
                io.write(" = ", exp:Render())
                io.write("\n")
            elseif what == "deferred_call" then
                tab()
                --io.write(what, " - ")
                local exp, return_values = ...
                if return_values then
                    local str = {}
                    for i,v in ipairs(return_values) do
                        str[i] = tostring(v)
                    end
                    io.write(table.concat(str, ", "))
                end
                io.write(" = ", exp:Render())
                io.write("\n")
            elseif what == "function_spec" then
                local func = ...
                tab()
                io.write(what, " - ")
                io.write(tostring(func))
                io.write("\n")
            elseif what == "return" then
                tab()
                io.write(what)
                local values = ...
                if values then
                    io.write(" ")
                    for i, v in ipairs(values) do
                        io.write(tostring(v))
                        if i ~= #values then
                            io.write(", ")
                        end
                    end
                end
                io.write("\n")
            else
                tab()
                io.write(what .. " - ", ...)
                io.write("\n")
            end
        end
    end
end