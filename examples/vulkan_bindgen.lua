local preprocess = require("nattlua.definitions.lua.ffi.preprocessor.preprocessor")
local build_lua = require("nattlua.definitions.lua.ffi.binding_gen")
local c_header, parser = preprocess(
	[[
	typedef int VkSamplerYcbcrConversion;
	typedef int VkDescriptorUpdateTemplate;
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

do
	local ffi = require("ffi")
	local vk = require("vulkan")
	local lib = vk.find_library()
	-- Simple Vulkan example: Query physical device properties
	print("\n=== Vulkan Physical Device Query ===\n")
	-- Create a Vulkan instance
	local VkApplicationInfoBox = ffi.typeof("$[1]", vk.VkApplicationInfo)
	local appInfo = VkApplicationInfoBox()
	appInfo[0].sType = 0 -- VK_STRUCTURE_TYPE_APPLICATION_INFO
	appInfo[0].pApplicationName = "NattLua Vulkan Test"
	appInfo[0].applicationVersion = 1
	appInfo[0].pEngineName = "No Engine"
	appInfo[0].engineVersion = 1
	appInfo[0].apiVersion = vk.VK_API_VERSION_1_0
	-- Create info struct - initialize with table to avoid const issues
	local VkInstanceCreateInfoBox = ffi.typeof("$[1]", vk.VkInstanceCreateInfo)
	local createInfo = VkInstanceCreateInfoBox(
		{
			{
				sType = "VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO",
				pNext = nil,
				flags = 0,
				pApplicationInfo = appInfo,
				enabledLayerCount = 0,
				ppEnabledLayerNames = nil,
				enabledExtensionCount = 0,
				ppEnabledExtensionNames = nil,
			},
		}
	)
	local VkInstanceBox = ffi.typeof("$[1]", vk.VkInstance)
	local instance = VkInstanceBox()
	local result = lib.vkCreateInstance(createInfo, nil, instance)

	if result ~= 0 then
		print("Failed to create Vulkan instance. Error code: " .. tostring(result))
		os.exit(1)
	end

	print("✓ Created Vulkan instance successfully")
	-- Enumerate physical devices
	local deviceCount = ffi.new("uint32_t[1]", 0)
	result = lib.vkEnumeratePhysicalDevices(instance[0], deviceCount, nil)

	if result ~= 0 or deviceCount[0] == 0 then
		print("No Vulkan devices found!")
		os.exit(1)
	end

	print(string.format("✓ Found %d physical device(s)", deviceCount[0]))
	local VkPhysicalDeviceArray = ffi.typeof("$[?]", vk.VkPhysicalDevice)
	local devices = VkPhysicalDeviceArray(deviceCount[0])
	result = lib.vkEnumeratePhysicalDevices(instance[0], deviceCount, devices)
	local VkPhysicalDevicePropertiesBox = ffi.typeof("$[1]", vk.VkPhysicalDeviceProperties)

	-- Query properties for each device
	for i = 0, deviceCount[0] - 1 do
		local properties = VkPhysicalDevicePropertiesBox()
		lib.vkGetPhysicalDeviceProperties(devices[i], properties)
		local deviceName = ffi.string(properties[0].deviceName)
		local apiVersion = properties[0].apiVersion
		local driverVersion = properties[0].driverVersion
		local vendorID = properties[0].vendorID
		local deviceID = properties[0].deviceID
		-- Decode API version (major.minor.patch)
		local apiMajor = bit.rshift(apiVersion, 22)
		local apiMinor = bit.band(bit.rshift(apiVersion, 12), 0x3FF)
		local apiPatch = bit.band(apiVersion, 0xFFF)
		print(string.format("\nDevice %d:", i))
		print(string.format("  Name: %s", deviceName))
		print(string.format("  API Version: %d.%d.%d", apiMajor, apiMinor, apiPatch))
		print(string.format("  Driver Version: 0x%08X", driverVersion))
		print(string.format("  Vendor ID: 0x%04X", vendorID))
		print(string.format("  Device ID: 0x%04X", deviceID))
		print(string.format("  Device Type: %d", tonumber(properties[0].deviceType)))
		-- Print some limits
		local limits = properties[0].limits
		print(string.format("  Max Image Dimension 2D: %d", tonumber(limits.maxImageDimension2D)))
		print(
			string.format(
				"  Max Compute Shared Memory Size: %d bytes",
				tonumber(limits.maxComputeSharedMemorySize)
			)
		)
		print(
			string.format(
				"  Max Compute Work Group Count: [%d, %d, %d]",
				tonumber(limits.maxComputeWorkGroupCount[0]),
				tonumber(limits.maxComputeWorkGroupCount[1]),
				tonumber(limits.maxComputeWorkGroupCount[2])
			)
		)
	end

	print("\n=== Query Complete ===\n")
end
