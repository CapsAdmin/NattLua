local helpers = require("nattlua.other.helpers")

return function(META)    
    table.insert(META.OnInitialize, function(self) 
        self.diagnostics = {}
    end)

    function META:Assert(node, ok, err)
        if ok == false then
            err = err or "unknown error"
            self:Error(node, err)
            return self:NewType(node, "any")
        end
        return ok
    end

    function META:Report(node, msg --[[#: string ]], severity --[[#: "warning" | "error" ]])
        local start, stop = helpers.LazyFindStartStop(node)

        if severity == "error" then
            if self.OnError then
                self:OnError(node.code, node.name, msg, start, stop)
            end
        end

        if self.OnReport then
            self:OnReport(node.code, node.name, msg, severity, start, stop)
        end

        table.insert(self.diagnostics, {
            node = node, 
            start = start, 
            stop = stop,
            msg = msg,
            severity = severity,
            traceback = debug.traceback(),
        })
    end

    function META:Error(node, msg)
        return self:Report(node, msg, "error")
    end
    
    function META:FatalError(msg)
        error(msg, 2)
    end

    function META:GetDiagnostics()
        return self.diagnostics
    end
end