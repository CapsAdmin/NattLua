local nl = require("nattlua")
local helpers = IMPORTS["nattlua.other.helpers"]()

local ls = {}

local function get_range(code, start, stop)
    local data = helpers.SubPositionToLinePosition(code:GetString(), start, stop)

    if data.line_start == 0 or data.line_stop == 0 then
        print("invalid position")
        return
    end

    return {
        start = {
            line = data.line_start - 1,
            character = data.character_start
        },
        ["end"] = {
            line = data.line_stop - 1,
            character = data.character_stop
        }
    }
end

local diagnostics = {}

function ls.ReadDiagnostic()
    local t = table.remove(diagnostics)
    if t then
        return t
    end
end

do
    -- reuse environment for performance
    local BuildBaseEnvironment = IMPORTS["nattlua.runtime.base_environment"]().BuildBaseEnvironment
    local runtime_env, typesystem_env = BuildBaseEnvironment()

    function ls.Compile(str)
        ls.compiler = nl.Compiler(str)

        function ls.compiler:OnDiagnostic(code, msg, severity, start, stop, ...)
            local range = get_range(code, start, stop)

            if not range then
                return
            end

            table.insert(diagnostics, {
                severity = severity,
                msg = helpers.FormatMessage(msg, ...),
                range = range
            })
        end

        ls.compiler:SetEnvironments(runtime_env, typesystem_env)
        ls.compiler:Analyze()
    end
end

function ls.OnHover(pos)
    local token, data = helpers.GetDataFromLineCharPosition(ls.compiler.Tokens, ls.compiler.Code:GetString(),
        pos.lineNumber, pos.column)

    if not token or not data then
        error("cannot find anything")
    end

    local found_parents = {}

    do
        local node = token

        while node.parent do
            table.insert(found_parents, node.parent)
            node = node.parent
        end
    end

    local markdown = ""

    local function add_line(str)
        markdown = markdown .. str .. "\n\n"
    end

    local function add_code(str)
        add_line("```lua\n" .. tostring(str) .. "\n```")
    end

    local function get_type(obj)
        local upvalue = obj:GetUpvalue()

        if upvalue then
            return upvalue:GetValue()
        end

        return obj
    end

    if token:GetLastType() then
        add_code(get_type(token:GetLastType()))
    else
        for _, node in ipairs(found_parents) do
            if node:GetLastType() then
                add_code(get_type(node:GetLastType()))

                break
            end
        end
    end

    -- add_line("nodes:\n\n")
    -- add_code("\t[token - " .. token.type .. " (" .. token.value .. ")]")

    for _, node in ipairs(found_parents) do
        -- add_code("\t" .. tostring(node))
    end

    if token and token.parent then
        local min, max = token.parent:GetStartStop()

        if min then
            local temp = helpers.SubPositionToLinePosition(ls.compiler.Code:GetString(), min, max)

            if temp then
                data = temp
            end
        end
    end

    return {
        contents = markdown,
        range = {
            start = {
                line = data.line_start - 1,
                character = data.character_start
            },
            ["end"] = {
                line = data.line_stop - 1,
                character = data.character_stop + 1
            }
        }
    }
end

return ls
