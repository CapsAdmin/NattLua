local errors = {
    subset = function(a, b, reason)
        local msg = {a, " is not a subset of ", b}

        if reason then
            table.insert(msg, " because ")
            if type(reason) == "table" then
                for i,v in ipairs(reason) do
                    table.insert(msg, v)
                end
            else
                table.insert(msg, reason)
            end
        end

        return false, msg
    end,
    missing = function(a, b, reason)
        local msg = {a, " has no field ", b, " because ", reason}
        return false, msg
    end,
    other = function(msg)
        return false, msg
    end,
    type_mismatch = function(a, b)
        return false, {a, " is not the same type as ", b}
    end,
    value_mismatch = function(a, b)
        return false, {a, " is not the same value as ", b}
    end,
    operation = function(op, obj, subject)
        return false, {"cannot ", op, " ", subject}
    end,
    numerically_indexed = function(obj)
        return false, {obj, " is not numerically indexed"}
    end,
    empty = function(obj)
        return false, {obj, " is empty"}
    end,
    binary = function(op, l,r)
        return false, {l, " ", op, " ", r, " is not a valid binary operation"}
    end,
    prefix = function(op, l)
        return false, {op, " ", l, " is not a valid prefix operation"}
    end,
    postfix = function(op, r)
        return false, {op, " ", r, " is not a valid postfix operation"}
    end,
    literal = function(obj, reason)
        local msg = {obj, " is not a literal"}
        if reason then
            table.insert(msg, " because ")
            table.insert(msg, reason)
        end

        return msg
    end,
    string_pattern = function(a, b)
        return false, {"cannot find ", a, " in pattern \"", b.pattern_contract, "\""}
    end
}

return errors