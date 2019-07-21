local oh = require("oh")

local files = {}

for full_path in io.popen("locate .lua"):read("*all"):gmatch("(.-)\n") do
    if
        full_path:sub(-4) == ".lua" and
        not full_path:find("GarrysMod") and
        not full_path:find("pac3") and
        not full_path:find("notagain") and
        not full_path:find("gmod") and
        not full_path:find("gm%-")
    then
        table.insert(files, full_path)
    end
end

local function loadfile(full_path)
    local f = assert(io.open(full_path, "r"))
    local code = f:read("*all")
    f:close()
    assert(code ~= "", "file is empty")
    local tbl = require("oh.util").UTF8ToTable(code)
    assert(#tbl ~= 0, "unicode length is 0")

    local tokens = assert(oh.CodeToTokens(tbl, full_path))
    local ast = assert(oh.TokensToAST(tokens, full_path, tbl))
    local code = assert(oh.ASTToCode(ast))
    return assert(loadstring(code))
end

for _, full_path in ipairs(files) do
    local ok, err = pcall(loadfile, full_path)
    if not ok then
        io.write(full_path, " error:\n", err)
    end
end