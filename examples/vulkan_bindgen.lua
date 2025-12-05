local preprocess = require("nattlua.definitions.lua.ffi.preprocessor.preprocessor")
local build_lua = require("nattlua.definitions.lua.ffi.binding_gen")
local buffer = require("string.buffer")
-- Lua reserved keywords that cannot be used as identifiers
local LUA_KEYWORDS = {
	["and"] = true,
	["break"] = true,
	["do"] = true,
	["else"] = true,
	["elseif"] = true,
	["end"] = true,
	["false"] = true,
	["for"] = true,
	["function"] = true,
	["goto"] = true,
	["if"] = true,
	["in"] = true,
	["local"] = true,
	["nil"] = true,
	["not"] = true,
	["or"] = true,
	["repeat"] = true,
	["return"] = true,
	["then"] = true,
	["true"] = true,
	["until"] = true,
	["while"] = true,
}

-- Generate field access syntax (use bracket notation for keywords)
local function field_access(obj, field_name)
	if LUA_KEYWORDS[field_name] then
		return obj .. "['" .. field_name .. "']"
	else
		return obj .. "." .. field_name
	end
end

-- Generate field key syntax for table constructors (use bracket notation for keywords)
local function field_key(field_name)
	if LUA_KEYWORDS[field_name] then
		return "['" .. field_name .. "']"
	else
		return field_name
	end
end

local c_header, parser = preprocess(
	[[
	typedef int VkSamplerYcbcrConversion;
	typedef int VkDescriptorUpdateTemplate;
	typedef void* Display;
	typedef void* VisualID;
	typedef void* Window;

	typedef void* IDirectFB;
	typedef void* IDirectFBSurface;
	typedef void* GgpStreamDescriptor;
	typedef void* GgpFrameToken;
	typedef void* _screen_context;
	typedef void* SECURITY_ATTRIBUTES;


	#define VK_USE_PLATFORM_MIR_KHR
	#define VK_USE_PLATFORM_WAYLAND_KHR
	//#define VK_USE_PLATFORM_WIN32_KHR
	//#define VK_USE_PLATFORM_XCB_KHR
	#define VK_USE_PLATFORM_XLIB_KHR
	#define VK_USE_PLATFORM_DIRECTFB_EXT
	#define VK_USE_PLATFORM_ANDROID_KHR
	#define VK_USE_PLATFORM_MACOS_MVK
	#define VK_USE_PLATFORM_IOS_MVK
	#define VK_USE_PLATFORM_GGP
	#define VK_USE_PLATFORM_METAL_EXT
	#define VK_USE_PLATFORM_VI_NN
	#define VK_USE_PLATFORM_SCREEN_QNX
	//#define VK_USE_PLATFORM_FUCHSIA
	#include <vulkan/vulkan.h>
	]],
	{
		working_directory = "/nix/store/j0jc9819vx3gdky3jfxp9fwza54xk184-vulkan-headers-1.4.328.0/include",
		system_include_paths = {"/nix/store/j0jc9819vx3gdky3jfxp9fwza54xk184-vulkan-headers-1.4.328.0/include"},
		defines = {__LP64__ = true},
	}
)
-- Get all expanded definitions
local res, metadata = build_lua(
	c_header,
	parser:GetExpandedDefinitions(),
	[[

	ffi.cdef[=[
		struct ANativeWindow;
		struct AHardwareBuffer;
		struct wl_display;
		struct wl_surface;
	 	struct _screen_context;
	 	struct _screen_window;
	 	struct _screen_buffer;
		typedef void* zx_handle_t;
		typedef void* HINSTANCE;
		typedef void* HWND;
		typedef void* HANDLE;
		typedef void* LPCWSTR;
		typedef void* DWORD;
		typedef void* xcb_window_t;
	]=]

	function mod.GetExtension(lib, instance, name)
		local ptr = lib.vkGetInstanceProcAddr(instance, name)

		if ptr == nil then error("extension function not found", 2) end

		local func = ffi.cast(mod["PFN_" .. name], ptr)
		return func
	end

function mod.find_library()
	local function try_load(tbl)
		local errors = {}

		for _, name in ipairs(tbl) do
			local status, lib = pcall(ffi.load, name)

			if status then
				llog("Loaded Vulkan library:", name)
				return lib
			else
				table.insert(errors, lib)
			end
		end

		return nil, table.concat(errors, "\n")
	end

	if ffi.os == "Windows" then
		return assert(try_load({"vulkan-1.dll"}))
	elseif ffi.os == "OSX" then
		local home = os.getenv("HOME")
		local vulkan_sdk = os.getenv("VULKAN_SDK")
		local paths = {}
		-- Load the Vulkan LOADER (not the ICD directly)
		-- The loader will automatically find kosmickrisp via the ICD system
		table.insert(paths, "/opt/homebrew/lib/libvulkan.dylib")
		table.insert(paths, "/opt/homebrew/lib/libvulkan.1.dylib")
		table.insert(paths, "/usr/local/lib/libvulkan.dylib")
		table.insert(paths, "libvulkan.dylib")
		table.insert(paths, "libvulkan.1.dylib")

		-- Try VULKAN_SDK paths
		if vulkan_sdk then
			table.insert(paths, vulkan_sdk .. "/lib/libvulkan.dylib")
			table.insert(paths, vulkan_sdk .. "/lib/libvulkan.1.dylib")
		end

		-- Try VulkanSDK in home directory
		if home and vulkan_sdk then
			table.insert(paths, home .. "/VulkanSDK/1.4.328.1/macOS/lib/libvulkan.1.dylib")
		end

		return assert(try_load(paths))
	end

	return assert(try_load({"libvulkan.so", "libvulkan.so.1"}))
end

]],
	{collect_metadata = true}
)
-- Build set of handle types (types defined as void*)
local handle_types = {}

for line in res:gmatch("[^\n]+") do
	local type_name = line:match("^mod%.(%w+) = ffi%.typeof%(%[%[void%*%]%]%)")

	if type_name then handle_types[type_name] = true end
end

-- Generate enum lookup tables and info builders using the metadata
local extra_code = buffer.new()
-- Build a map of enum type -> { prefix, suffix_to_value }
local enum_lookups = {}

for enum_name, enum_data in pairs(metadata.enums) do
	-- Find common prefix among all enum values
	local values = enum_data.values

	if #values > 1 then
		local common = values[1].name

		for i = 2, #values do
			local other = values[i].name
			local j = 1

			while j <= #common and j <= #other and common:sub(j, j) == other:sub(j, j) do
				j = j + 1
			end

			common = common:sub(1, j - 1)
		end

		-- Extend to the last underscore
		local last_underscore = common:match(".*()_")

		if last_underscore then
			local prefix = common:sub(1, last_underscore)
			local lookup = {}

			for _, v in ipairs(values) do
				local suffix = v.name:sub(#prefix + 1)

				if not suffix:match("MAX_ENUM") then
					-- Strip _BIT suffix but preserve vendor extensions like _KHR, _EXT, etc.
					-- _BIT at end of string -> remove entirely
					-- _BIT_KHR, _BIT_EXT, etc. -> keep as _KHR, _EXT
					local short_suffix = suffix:gsub("_BIT$", ""):gsub("_BIT_", "_")
					-- Only store lowercase keys
					lookup[short_suffix:lower()] = v.name
				end
			end

			enum_lookups[enum_name] = {prefix = prefix, lookup = lookup}
		end
	end
end

-- Find info structs (structs with sType field) and their corresponding sType values
local info_structs = {}
local stype_lookup = {}

-- First, build sType value lookup from VkStructureType enum
if metadata.enums.VkStructureType then
	for _, v in ipairs(metadata.enums.VkStructureType.values) do
		stype_lookup[v.name] = v.name
	end
end

-- Find all info structs
for struct_name, struct_data in pairs(metadata.structs) do
	local has_stype = false

	for _, field in ipairs(struct_data.fields) do
		if field.name == "sType" then
			has_stype = true

			break
		end
	end

	if has_stype then
		-- Derive the sType value from struct name
		-- VkImageViewCreateInfo -> VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO
		-- Algorithm: insert underscore before each uppercase letter (except first), then uppercase all
		local name = struct_name:gsub("^Vk", "") -- Remove Vk prefix
		local stype_name = "VK_STRUCTURE_TYPE_"

		for i = 1, #name do
			local c = name:sub(i, i)

			if c:match("%u") and i > 1 then
				-- Check if previous char was lowercase or if next char is lowercase (for acronyms)
				local prev = name:sub(i - 1, i - 1)

				if prev:match("%l") then stype_name = stype_name .. "_" end
			end

			stype_name = stype_name .. c:upper()
		end

		if stype_lookup[stype_name] then
			info_structs[struct_name] = {stype = stype_name, fields = struct_data.fields}
		end
	end
end

-- Generate the enum lookup tables
extra_code:put("\n-- Enum lookup tables for string -> value translation\n")
extra_code:put("mod.e = {}\n")
extra_code:put("local type = _G.type\n")
extra_code:put("local ipairs = _G.ipairs\n")
extra_code:put("local bit_bor = bit.bor\n")
-- Helper function for combining flags (generated once)
extra_code:put("local function combine_flags(lookup, values, enum_name)\n")
extra_code:put("\tlocal result = 0\n")
extra_code:put("\tfor _, v in ipairs(values) do\n")
extra_code:put("\t\tif type(v) == 'number' then\n")
extra_code:put("\t\t\tresult = bit_bor(result, v)\n")
extra_code:put("\t\telse\n")
extra_code:put("\t\t\tlocal val = lookup[v]\n")
extra_code:put(
	"\t\t\tif not val then error('unknown ' .. enum_name .. ' value: ' .. tostring(v)) end\n"
)
extra_code:put("\t\t\tresult = bit_bor(result, val)\n")
extra_code:put("\t\tend\n")
extra_code:put("\tend\n")
extra_code:put("\treturn result\n")
extra_code:put("end\n")

for enum_name, data in pairs(enum_lookups) do
	extra_code:put("do\n")
	extra_code:put("\tlocal lookup = {\n")

	for suffix, full_name in pairs(data.lookup) do
		extra_code:put("\t\t['", suffix, "'] = mod.", enum_name, "('", full_name, "'),\n")
	end

	extra_code:put("\t}\n")
	extra_code:put("mod.e.", enum_name, " = function(s)\n")
	extra_code:put("\tif s == nil then return 0 end\n")
	extra_code:put("\tif type(s) == 'number' then return s end\n")
	-- Handle table of flags (e.g., {"color", "depth"} -> VK_IMAGE_ASPECT_COLOR_BIT | VK_IMAGE_ASPECT_DEPTH_BIT)
	extra_code:put(
		"\tif type(s) == 'table' then return combine_flags(lookup, s, '",
		enum_name,
		"') end\n"
	)
	extra_code:put(
		"\treturn lookup[s] or error('unknown ",
		enum_name,
		" value: ' .. tostring(s))\n"
	)
	extra_code:put("end\n")
	extra_code:put("end\n")
end

-- Generate helper to fill struct fields recursively
extra_code:put("\n-- Helper to fill struct fields with enum translation\n")
extra_code:put("local function fill_struct(ctype, field_info, t)\n")
extra_code:put("\tif t == nil then return nil end\n")
extra_code:put("\tlocal obj = N(ctype)\n")
extra_code:put("\tfor k, v in pairs(t) do\n")
extra_code:put("\t\tlocal info = field_info[k]\n")
extra_code:put("\t\tif info then\n")
extra_code:put("\t\t\tif info.enum_lookup then\n")
extra_code:put("\t\t\t\tobj[k] = info.enum_lookup(v)\n")
extra_code:put("\t\t\telseif info.struct_fill then\n")
extra_code:put("\t\t\t\tinfo.struct_fill(obj[k], v)\n")
extra_code:put("\t\t\telse\n")
extra_code:put("\t\t\t\tobj[k] = v\n")
extra_code:put("\t\t\tend\n")
extra_code:put("\t\telse\n")
extra_code:put("\t\t\tobj[k] = v\n")
extra_code:put("\t\tend\n")
extra_code:put("\tend\n")
extra_code:put("\treturn obj\n")
extra_code:put("end\n")

-- Helper to find the enum type for a field
-- Handles both direct enums (VkImageViewType) and flag types (VkImageAspectFlags -> VkImageAspectFlagBits)
local function get_enum_for_field(field_type_name)
	if not field_type_name then return nil end

	-- Direct enum match
	if enum_lookups[field_type_name] then return field_type_name end

	-- Flags -> FlagBits conversion (e.g., VkImageAspectFlags -> VkImageAspectFlagBits)
	if field_type_name:match("Flags$") or field_type_name:match("Flags%d*$") then
		local bits_name = field_type_name:gsub("Flags(%d*)$", "FlagBits%1")

		if enum_lookups[bits_name] then return bits_name end
	end

	return nil
end

-- Build a map of structs that have enum fields (for nested struct translation)
local structs_with_enums = {}

for struct_name, struct_data in pairs(metadata.structs) do
	local enum_fields = {}

	for _, field in ipairs(struct_data.fields) do
		local enum_type = get_enum_for_field(field.type_name)

		if enum_type then enum_fields[field.name] = enum_type end
	end

	if next(enum_fields) then structs_with_enums[struct_name] = enum_fields end
end

-- Generate struct builders for structs with enum fields or sType (for nested struct translation)
extra_code:put("\n-- Struct builders with enum translation (for nested structs)\n")
extra_code:put("mod.s = {}\n")
-- Collect all structs that need builders (have enum fields or sType)
local structs_needing_builders = {}

for struct_name, enum_fields in pairs(structs_with_enums) do
	structs_needing_builders[struct_name] = true
end

for struct_name, info in pairs(info_structs) do
	structs_needing_builders[struct_name] = true
end

for struct_name in pairs(structs_needing_builders) do
	local enum_fields = structs_with_enums[struct_name] or {}
	local info = info_structs[struct_name]
	local short_name = struct_name:gsub("^Vk", "")
	extra_code:put("mod.s.", short_name, " = function(t)\n")
	extra_code:put("\tif type(t) ~= 'table' then return t end\n")
	extra_code:put("\treturn mod.", struct_name, "({\n")
	local struct_data = metadata.structs[struct_name]

	for _, field in ipairs(struct_data.fields) do
		local enum_type = enum_fields[field.name]
		local key = field_key(field.name)
		local t_access = field_access("t", field.name)

		if field.name == "sType" and info then
			-- Handle sType with default value
			extra_code:put(
				"\t\t",
				key,
				" = ",
				t_access,
				" and mod.e.VkStructureType(",
				t_access,
				") or mod.VkStructureType('",
				info.stype,
				"'),\n"
			)
		elseif enum_type then
			extra_code:put(
				"\t\t",
				key,
				" = mod.e.",
				enum_type,
				"(",
				t_access,
				"),\n"
			)
		elseif field.type_name and structs_needing_builders[field.type_name] then
			-- Nested struct that has a builder
			local nested_short_name = field.type_name:gsub("^Vk", "")
			extra_code:put(
				"\t\t",
				key,
				" = mod.s.",
				nested_short_name,
				"(",
				t_access,
				"),\n"
			)
		else
			extra_code:put("\t\t", key, " = ", t_access, ",\n")
		end
	end

	extra_code:put("\t})\n")
	extra_code:put("end\n")
end

-- Insert the extra code before "return mod"
res = res:gsub("\nreturn mod\n", tostring(extra_code) .. "\nreturn mod\n")
local f = io.open("/home/caps/projects/goluwa3/goluwa/bindings/vk.lua", "w")
f:write(res)
f:close()
os.execute("luajit nattlua.lua fmt /home/caps/projects/goluwa3/goluwa/bindings/vk.lua")
