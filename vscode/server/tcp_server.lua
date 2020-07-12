local ljsocket = require("vscode.server.ljsocket")
local tcp_client = require("vscode.server.tcp_client")

local META = {}
META.__index = META

function META:assert(val, err)
    if not val then
        self:Error(err)
    end

    return val, err
end

function META:__tostring2()
    return "[" .. tostring(self.socket) .. "]"
end

function META:Initialize()
    self:SocketRestart()
end

function META:SocketRestart()
    self.socket = ljsocket.create("inet", "stream", "tcp")
    assert(self.socket:set_blocking(false))
    self.socket:set_option("nodelay", true, "tcp")
    self.socket:set_option("reuseaddr", true)
end

function META:OnRemove()
    self:assert(self.socket:close())
end

function META:Close(reason)
    if reason then print(reason) end
    self:Remove()
end

function META:Host(host, service)
    local ok, err = self.socket:bind(host, service)

    if ok then
        ok, err = self.socket:listen()
    end

    if ok then
        self.hosting = true
        return
    end

    return self:Error("Unable host " .. host .. ":" .. service .. " - " .. err)
end

function META:Update()
    if not self.hosting then return end

    for i = 1, 512 do
        local client, err = self.socket:accept()

        if not client and err == "Too many open files" then
            print("cannot accept more clients: %s", err)
            return
        end

        if client then
            local client = tcp_client(client)
            client.connected = true
            self:OnClientConnected(client)
        else
            if err and err ~= "timeout" then
                self:Error(err)
            end
            break
        end
    end
end

function META:Error(message, ...)
    self:OnError(message, ...)
    return false
end

function META:OnError(str, tr) print(tr, str) self:OnRemove() end
function META:OnReceiveChunk(str) end
function META:OnClose() self:Close() end
function META:OnConnect() end

return function()
    local self = setmetatable({}, META)
    self:Initialize()
    return self
end