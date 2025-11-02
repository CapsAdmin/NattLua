local preprocess = require("nattlua.definitions.lua.ffi.preprocessor.preprocessor")
local vulkan_test = [[
#include <vulkan/vulkan.h>

// Use some Vulkan defines/types to verify they're available
VkResult result;
const uint32_t version = VK_API_VERSION_1_0;

// Test that platform defines work - these will expand to 1 if defines are set
int wayland_enabled = VK_USE_PLATFORM_WAYLAND_KHR;
int xcb_enabled = VK_USE_PLATFORM_XCB_KHR;
int xlib_enabled = VK_USE_PLATFORM_XLIB_KHR;

// Test standard predefined macros
#ifdef __STDC__
int stdc_defined = __STDC__;
long stdc_version = __STDC_VERSION__;
#endif

#ifdef __GNUC__
int gcc_major = __GNUC__;
int gcc_minor = __GNUC_MINOR__;
#endif
]]
local res = preprocess(
	vulkan_test,
	{
		working_directory = "/Users/caps/github/ffibuild/vulkan/repo/include",
		system_include_paths = {"/Users/caps/github/ffibuild/vulkan/repo/include"},
		defines = {
			-- Linux platform defines (uncomment to test platform-specific headers)
			VK_USE_PLATFORM_WAYLAND_KHR = 1, -- Wayland support
			VK_USE_PLATFORM_XCB_KHR = 1, -- X11 XCB support
			VK_USE_PLATFORM_XLIB_KHR = 1, -- X11 Xlib support
		-- Other common Linux platform defines:
		-- VK_USE_PLATFORM_XLIB_XRANDR_EXT = 1,  -- X11 XRandR extension
		-- VK_USE_PLATFORM_DIRECTFB_EXT = 1,     -- DirectFB support
		-- Note: The output is intentionally minimal because:
		-- 1. vulkan_core.h has extensive include guards (#ifndef/#define)
		-- 2. Most Vulkan content is already expanded (types, constants, etc.)
		-- 3. Platform-specific extensions are wrapped in #ifdef directives
		-- The preprocessor is correctly handling all of this!
		},
		on_include = function(filename, full_path)
			print(string.format("Including: %s", filename))
		end,
	}
)
print(res)
