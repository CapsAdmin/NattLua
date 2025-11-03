local preprocess = require("nattlua.definitions.lua.ffi.preprocessor.preprocessor")
local build_lua = require("nattlua.definitions.lua.ffi.binding_gen")
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
		working_directory = "/Users/caps/github/ffibuild/vulkan/repo/include",
		system_include_paths = {"/Users/caps/github/ffibuild/vulkan/repo/include"},
		defines = {__LP64__ = true},
	}
)
-- Get all expanded definitions
local res = build_lua(
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

	do
		local cache = {}
		function mod.EnumToString(enum_type, index)
			if not index then
				index = tonumber(enum_type)
			end
			local enum_id = tonumber(ffi.typeof(enum_type))

			if cache[enum_id] ~= nil then return cache[enum_id] end
			
			local enum_ctype = ffi.typeinfo(enum_id)
			local current_index = 0
			local sib = enum_ctype.sib

			while sib do
				local sib_ctype = ffi.typeinfo(sib)
				local CT_code = bit.rshift(sib_ctype.info, 28)

				if CT_code == 11 then -- constant
					if current_index == index then 
						cache[enum_id] = sib_ctype.name 
						return cache[enum_id] 
					end

					current_index = current_index + 1
				end

				sib = sib_ctype.sib
			end

			cache[enum_id] = false

			return nil
		end
	end

	function mod.GetExtension(lib, instance, name)
		local ptr = lib.vkGetInstanceProcAddr(instance, name)

		if ptr == nil then error("extension function not found", 2) end

		local func = ffi.cast(mod["PFN_" .. name], ptr)
		return func
	end

	do
		local t_cache = {}

		local function array_type(t, len)
			if len then
				t_cache[t] = t_cache[t] or ffi.typeof("$[" .. len .. "]", t)
				return t_cache[t]
			end

			t_cache[t] = t_cache[t] or ffi.typeof("$[?]", t)
			return t_cache[t]
		end

		function mod.Array(t, len, ctor)
			if ctor then return array_type(t, len)(ctor) end

			return array_type(t, len)
		end

		function mod.Box(t, ctor)
			if ctor then return array_type(t, 1)({ctor}) end

			return array_type(t, 1)
		end
	end

	function mod.find_library()
		local function try_load(tbl)
			local errors = {}

			for _, name in ipairs(tbl) do
				local status, lib = pcall(ffi.load, name)

				if status then return lib else table.insert(errors, lib) end
			end

			return nil, table.concat(errors, "\n")
		end

		if ffi.os == "Windows" then
			return assert(try_load({"vulkan-1.dll"}))
		elseif ffi.os == "OSX" then
			-- Try user's home directory first (expand ~ manually)
			local home = os.getenv("HOME")
			local vulkan_sdk = os.getenv("VULKAN_SDK")
			local paths = {}

			-- Try MoltenVK directly first (more reliable on macOS)
			if home then
				table.insert(paths, home .. "/VulkanSDK/1.4.328.1/macOS/lib/libMoltenVK.dylib")
			end

			-- Try VULKAN_SDK environment variable
			if vulkan_sdk then
				table.insert(paths, vulkan_sdk .. "/lib/libMoltenVK.dylib")
				table.insert(paths, vulkan_sdk .. "/lib/libvulkan.dylib")
			end

			-- Try standard locations
			table.insert(paths, "libMoltenVK.dylib")
			table.insert(paths, "libvulkan.dylib")
			table.insert(paths, "libvulkan.1.dylib")
			table.insert(paths, "/usr/local/lib/libvulkan.dylib")
			return assert(try_load(paths))
		end

		return assert(try_load({"libvulkan.so", "libvulkan.so.1"}))
	end
]]
)
local f = io.open("vulkan.lua", "w")
f:write(res)
f:close()
local ffi = require("ffi")

do
	local vk = require("vulkan")
	local lib = vk.find_library()
	local appInfo = vk.Box(
		vk.VkApplicationInfo,
		{
			sType = "VK_STRUCTURE_TYPE_APPLICATION_INFO",
			pApplicationName = "NattLua Vulkan Test",
			applicationVersion = 1,
			pEngineName = "No Engine",
			engineVersion = 1,
			apiVersion = vk.VK_API_VERSION_1_0,
		}
	)
	local createInfo = vk.Box(
		vk.VkInstanceCreateInfo,
		{
			sType = "VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO",
			pNext = nil,
			flags = 0,
			pApplicationInfo = appInfo,
			enabledLayerCount = 0,
			ppEnabledLayerNames = nil,
			enabledExtensionCount = 0,
			ppEnabledExtensionNames = nil,
		}
	)
	local instance = vk.Box(vk.VkInstance)()
	local result = lib.vkCreateInstance(createInfo, nil, instance)

	if result ~= 0 then
		error("failed to create vulkan instance: " .. vk.EnumToString(result))
	end

	print("vulkan instance created successfully: " .. vk.EnumToString(result))
	local deviceCount = ffi.new("uint32_t[1]", 0)
	result = lib.vkEnumeratePhysicalDevices(instance[0], deviceCount, nil)

	if result ~= 0 or deviceCount[0] == 0 then error("devices found") end

	print(string.format("found %d physical device(s)", deviceCount[0]))
	local devices = vk.Array(vk.VkPhysicalDevice)(deviceCount[0])
	result = lib.vkEnumeratePhysicalDevices(instance[0], deviceCount, devices)

	for i = 0, deviceCount[0] - 1 do
		local properties = vk.Box(vk.VkPhysicalDeviceProperties)()
		lib.vkGetPhysicalDeviceProperties(devices[i], properties)
		local props = properties[0]
		-- Decode API version (major.minor.patch)
		print(string.format("device %d:", i))
		print(string.format("  name: %s", ffi.string(props.deviceName)))
		local apiVersion = props.apiVersion
		print(
			string.format(
				"  api version: %d.%d.%d",
				bit.rshift(apiVersion, 22),
				bit.band(bit.rshift(apiVersion, 12), 0x3FF),
				bit.band(apiVersion, 0xFFF)
			)
		)
		print(string.format("  driver version: 0x%08X", props.driverVersion))
		print(string.format("  vendor id: 0x%04X", props.vendorID))
		print(string.format("  device id: 0x%04X", props.deviceID))
		print(string.format("  device type: %s", vk.EnumToString(props.deviceType)))
		-- Print some limits
		local limits = props.limits
		print(string.format("  max image dimension 2D: %d", tonumber(limits.maxImageDimension2D)))
		print(
			string.format(
				"  max compute shared memory size: %d bytes",
				tonumber(limits.maxComputeSharedMemorySize)
			)
		)
		print(
			string.format(
				"  max compute work group count: [%d, %d, %d]",
				tonumber(limits.maxComputeWorkGroupCount[0]),
				tonumber(limits.maxComputeWorkGroupCount[1]),
				tonumber(limits.maxComputeWorkGroupCount[2])
			)
		)
	end
end
