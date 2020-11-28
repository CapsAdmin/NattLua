local helpers = require("nattlua.other.helpers")

return function(META)
    
    --[[# 
        type META.diagnostics = {
            [1 .. inf] = {
                node = any, 
                start = number, 
                stop = number,
                msg = string,
                severity = "warning" | "error",
                traceback = string,
            }
        }    
    ]]
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

    function META:ReportDiagnostic(node, msg --[[#: string ]], severity --[[#: "warning" | "error" ]])
        severity = severity or "warning"
        local start, stop = helpers.LazyFindStartStop(node)

        if self.OnDiagnostic then
            self:OnDiagnostic(node.code, node.name, msg, severity, start, stop)
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
        return self:ReportDiagnostic(node, msg, "error")
    end
    
    function META:FatalError(msg)
        assert(type(msg) == "string")
        error(msg, 2)
    end

    function META:GetDiagnostics()
        return self.diagnostics
    end
end