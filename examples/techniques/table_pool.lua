function table.pool(alloc, size)
    local i = 1
    local pool = {}

    return function()
        local tbl = pool[i]

        if not tbl then
            print("alloc", #pool + 1, #pool + size)
            for i = #pool + 1, #pool + size do
                pool[i] = alloc()
            end
            tbl = pool[i]
        end

        i = i + 1

        return tbl
    end
end

local get = table.pool(function() return {
    type = "",
    start = 0,
    stop = 0
} end, 5)

for i = 1, 16 do
    local tbl = get()
    tbl.i = i
    print(tbl.i)
end
