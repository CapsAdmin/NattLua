if _G.loadstring then return _G.loadstring end

if _G.CompileString then
	return function(str--[[#: string]], name--[[#: nil | string]])
		local var = CompileString(str, name or "loadstring", false)

		if type(var) == "string" then return nil, var, 2 end

		return setfenv(var, getfenv(1))
	end
end
