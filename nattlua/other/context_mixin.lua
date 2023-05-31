return function(META)
    --[[#
    type META.@Self.context_values2 = any
    type META.@Self.context_values = any
    type META.@Self.context_ref = any
    ]]

    table.insert(META.OnInitialize, function(self--[[#: META.@Self]]) 
        self.context_values2 = {}
        self.context_values = {}
        self.context_ref = {}
    end)

    do
        function META:PushContextValue(key, value)
            self.context_values[key] = self.context_values[key] or {}
            table.insert(self.context_values[key], 1, value)
        end

        function META:GetContextValue(key, level)
            return self.context_values[key] and self.context_values[key][level or 1]
        end

        function META:PopContextValue(key)
            return table.remove(self.context_values[key], 1)
        end
    end

    do
        function META:PushContextValue2(key, val)
            self.context_values2[key] = self.context_values2[key] or {}
            table.insert(self.context_values2[key], val)
        end

        function META:GetContextValue2(key)
            return self.context_values2[key] and self.context_values2[key][#self.context_values2]
        end
    
        function META:PopContextValue2(key)
            table.remove(self.context_values2[key])
        end
    end

    do
        function META:PushContextRef(key)
            self.context_ref[key] = (self.context_ref[key] or 0) + 1
        end

        function META:GetContextRef(key)
            return self.context_ref[key] and self.context_ref[key] > 0
        end

        function META:PopContextRef(key)
            self.context_ref[key] = (self.context_ref[key] or 0) - 1
        end
    end


end