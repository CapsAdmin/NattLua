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
        if not node then
            io.write("reporting diagnostic without node, defaulting to current expression or statement\n")
            io.write(debug.traceback(), "\n")
            node = self.current_expression or self.current_statement
        end

        assert(node)
        assert(msg)
        assert(severity)

        local key = msg .. "-" .. ("%p"):format(node) .. "-" .. "severity"

        self.diagnostics_map = self.diagnostics_map or {}

        if self.diagnostics_map[key] then
            return
        end

        self.diagnostics_map[key] = true

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

    function META:Warning(node, msg)
        return self:ReportDiagnostic(node, msg, "warning")
    end
    
    function META:FatalError(msg)
        if self.current_expression or self.current_statement then
            return self:ReportDiagnostic(self.current_expression or self.current_statement, msg, "fatal")
        end

        error(msg, 2)
    end

    function META:GetDiagnostics()
        return self.diagnostics
    end
end