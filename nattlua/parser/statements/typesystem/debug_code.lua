return
	{
		ReadDebugCode = function(parser)
			if parser:IsType("type_code") then
				local node = parser:Node("statement", "type_code")

				local code = parser:Node("expression", "value")
				code.value = parser:ExpectType("type_code")
				code:End()

				node.lua_code = code
				return node:End()
			elseif parser:IsType("parser_code") then
				
				local token = parser:ExpectType("parser_code")
				assert(loadstring("local parser = ...;" .. token.value:sub(3)))(parser)

				local node = parser:Node("statement", "parser_code")
				
				local code = parser:Node("expression", "value")
				code.value = token
				node.lua_code = code:End()

				return node:End()
			end
		end,
	}
