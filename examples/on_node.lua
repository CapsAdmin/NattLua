local nl = require("nattlua")
local nodes = {}
local lua = assert(
	nl.File(
		"build_output.lua",
		{
			parser = {
				on_parsed_node = function(parser, node)
					print(node:Render())
				end,
			},
		}
	):Parse()
)
