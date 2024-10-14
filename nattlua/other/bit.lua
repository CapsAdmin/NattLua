if _G.jit and _G.bit then return _G.bit end

if _G.bit32 then return _G.bit32 end

return require("nattlua.other.bit32")
