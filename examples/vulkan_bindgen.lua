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
		working_directory = "/nix/store/j0jc9819vx3gdky3jfxp9fwza54xk184-vulkan-headers-1.4.328.0/include",
		system_include_paths = {"/nix/store/j0jc9819vx3gdky3jfxp9fwza54xk184-vulkan-headers-1.4.328.0/include"},
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

]]
)
local f = io.open("/home/caps/projects/goluwa3/goluwa/bindings/vk.lua", "w")
f:write(res)
f:close()
os.execute("luajit nattlua.lua fmt /home/caps/projects/goluwa3/goluwa/bindings/vk.lua")
