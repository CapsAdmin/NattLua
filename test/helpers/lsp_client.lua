local json = require("language_server.json")
local rpc_util = require("language_server.jsonrpc")
local class = require("nattlua.other.class")
local path_util = require("nattlua.other.path")
local META = class.CreateTemplate("lsp_client")

function META.New()
	return META.NewObject(
		{
			last_id = 0,
			pending_requests = {},
			notifications = {},
			responses = {},
			working_directory = "/",
		}
	)
end

function META:SetWorkingDirectory(dir)
	self.working_directory = path_util.Normalize(dir)
end

function META:ToLSPPath(path)
	return path_util.PathToUrlScheme(path_util.Normalize(path))
end

function META:ToFSPath(url)
	return path_util.UrlSchemeToPath(url, self.working_directory)
end

function META:Call(lsp, method, params)
	self.last_id = self.last_id + 1
	local id = self.last_id
	local request = {
		jsonrpc = "2.0",
		id = id,
		method = method,
		params = params,
	}
	self.pending_requests[id] = request
	-- Mock lsp.Call to capture output
	local old_call = lsp.Call
	lsp.Call = function(response)
		if response.id then
			self.responses[response.id] = response
		else
			table.insert(self.notifications, response)
		end
	end
	-- Simple direct call to the method handler
	local res = lsp.methods[method](params)
	-- Restore old call
	lsp.Call = old_call

	if res then return res end

	return self.responses[id] and self.responses[id].result
end

function META:Notify(lsp, method, params)
	local notification = {
		jsonrpc = "2.0",
		method = method,
		params = params,
	}
	-- Mock lsp.Call to capture side-effects (like publishDiagnostics)
	local old_call = lsp.Call
	lsp.Call = function(response)
		if not response.id then table.insert(self.notifications, response) end
	end

	if lsp.methods[method] then lsp.methods[method](params) end

	lsp.Call = old_call
end

function META:GetNotifications(method)
	local found = {}

	for _, n in ipairs(self.notifications) do
		if n.method == method then table.insert(found, n) end
	end

	return found
end

function META:ClearNotifications()
	self.notifications = {}
end

function META:Initialize(lsp, root_uri)
	return self:Call(
		lsp,
		"initialize",
		{
			workspaceFolders = {{uri = root_uri, name = "test-workspace"}},
			capabilities = {},
		}
	)
end

return META
