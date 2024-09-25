local path_util = require("nattlua.other.path")
local path = "file:///home/foo/bar/lsp.lua"
local fs_path = path_util.UrlSchemeToPath(path)
equal(fs_path, "/home/foo/bar/lsp.lua")
local lsp_path = path_util.PathToUrlScheme(fs_path)
equal(lsp_path, path)
local path = "file:///home/foo/./bar/lsp.lua"
local fs_path = path_util.UrlSchemeToPath(path)
equal(fs_path, "/home/foo/bar/lsp.lua")
local path = "file:///home/foo/../bar/lsp.lua"
local fs_path = path_util.UrlSchemeToPath(path)
equal(fs_path, "/home/bar/lsp.lua")
local path = "file:///home/foo/bar/../../lsp.lua"
local fs_path = path_util.UrlSchemeToPath(path)
equal(fs_path, "/home/lsp.lua")
