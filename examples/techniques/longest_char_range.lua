local chars = "\32\t\n\r"

local noise = {}

local patterns = {"...", "..", "=", "==", "~=", ">>>", "<<", ">", ">>"}

local function random_whitespace()
    local w = {}
    for i = 1, math.random(1, 10) do
        w[i] = string.char(chars:byte(math.random(1, #chars)))
    end
    return table.concat(w)
end

for i = 1, 5000000 do
    noise[i] = math.random() > 0.8 and random_whitespace() or string.char(math.random(32, 127))
end

noise = table.concat(noise)

local ffi = require("ffi")

local noiseptr = ffi.cast("uint8_t *", noise)

local i = 1

local function char(offset)
    if offset then
        return noise:sub(i + offset, i + offset)
    end
    return noise:sub(i, i)
end

local function byte(offset)
    if offset then
        return noiseptr[i + offset - 1]
    end
    return noise[i - 1]
end

local function is_byte(b, offset)
    return byte(offset) == b
end

local function advance(len)
    i = i + len
end

if true then
    local ipairs = ipairs

    local function is_space()
        return byte() == 9 or byte() == 10 or byte() == 13 or byte() == 32
    end

    i = 1
    local found = {}
    local foundi = 1

    print("================")
    print("loop over each char until no space")
    local time = os.clock()
    for _ = 1, #noise do
        if is_space() then
            local start = i
            local stop = i + 1
            advance(1)
            while not not is_space() do
                advance(1)
            end
            found[foundi] = noise:sub(start, i-1)
            foundi = foundi + 1
        else
            advance(1)
        end
    end

    --for i,v in ipairs(found) do print(i,#v) end
    print("found " .. foundi .. " spaces")
    print(os.clock() - time)
    print("================")
end

if true then
    local ffi = require("ffi")
    ffi.cdef("size_t strspn ( const char * str1, const char * str2 );")
    local C = ffi.C
    local strptr = ffi.cast("uint8_t *", noise)

    local function is_space()
        return byte() == 9 or byte() == 10 or byte() == 13 or byte() == 32
    end

    i = 1
    local found = {}
    local foundi = 1

    print("================")
    print("advance(strspn())")

    local time = os.clock()
    for _ = 1, #noise do
        if is_space() then
            local start = i
            advance(tonumber(C.strspn(strptr + i - 1, chars)))
            found[foundi] = noise:sub(start, i-1)
            foundi = foundi + 1
        else
            advance(1)
        end
    end
    --for i,v in ipairs(found) do print(i,#v) end
    print("found " .. foundi .. " spaces")
    print(os.clock() - time)
    print("================")
end

if true then
    local ffi = require("ffi")
    ffi.cdef("size_t strspn ( const char * str1, const char * str2 );")
    local C = ffi.C
    local strptr = ffi.cast("uint8_t *", noise)

    local function is_space()
        return byte() == 9 or byte() == 10 or byte() == 13 or byte() == 32
    end

    i = 1
    local found = {}
    local foundi = 1

    print("================")
    print("advance(strspn())")

    local time = os.clock()
    for _ = 1, #noise do
        if is_space() then
            local start = i
            advance(C.strspn(strptr + i - 1, chars))
            found[foundi] = noise:sub(start, i-1)
            foundi = foundi + 1
        else
            advance(1)
        end
    end
    --for i,v in ipairs(found) do print(i,#v) end
    print("found " .. foundi .. " spaces")
    print(os.clock() - time)
    print("================")
end