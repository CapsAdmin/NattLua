local parse_define = require("nattlua.definitions.lua.ffi.define_parser")
local defines = {
	"VK_KHR_vulkan_memory_model = 1",
	"VK_KHR_workgroup_memory_explicit_layout = 1",
	"VK_LOD_CLAMP_NONE = 1000.0F",
	"VK_LUID_SIZE = 8U",
	"VK_LUNARG_DIRECT_DRIVER_LOADING_EXTENSION_NAME = \"VK_LUNARG_direct_driver_loading\"",
	"VK_MAKE_API_VERSION(variant, major, minor, patch) = ((((uint32_t)(variant)) << 29U) | (((uint32_t)(major)) << 22U) | (((uint32_t)(minor)) << 12U) | ((uint32_t)(patch)))",
	"VK_MAKE_VERSION(major, minor, patch) = ((((uint32_t)(major)) << 22U) | (((uint32_t)(minor)) << 12U) | ((uint32_t)(patch)))",
	"VK_MAX_DESCRIPTION_SIZE = 256U",
	"VK_MAX_DESCRIPTION_SIZE = ~2",
	"VK_HEX_TEST = 0xFFU",
	"VK_HEX_LOWER = 0xabcdefU",
}
local results = {}

for _, define in ipairs(defines) do
	local result = parse_define(define)

	if result then
		table.insert(results, result)
		local chunk, err = loadstring("local ffi = require('ffi'); local bit = require('bit'); test = " .. result.val)

		if not chunk then
			error(
				"Failed to parse generated code for " .. result.key .. ": " .. (
						err or
						"unknown error"
					) .. "\nGenerated: " .. result.val
			)
		end
	end
end
