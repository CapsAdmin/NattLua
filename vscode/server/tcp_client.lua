local ljsocket = require("vscode.server.ljsocket")

local META = {}
META.__index = META

function META:assert(val, err)
    if not val then
        self:Error(err)
    end

    return val, err
end

function META:__tostring()
    return tostring(self.socket)
end

function META:Initialize(socket)
    self:SocketRestart(socket)
end

function META:SocketRestart(socket)
    self.socket = socket or ljsocket.create("inet", "stream", "tcp")
    if not self:assert(self.socket:set_blocking(false)) then return end
    self.socket:set_option("nodelay", true, "tcp")
    self.socket:set_option("cork", false, "tcp")

    self.connected = nil
    self.connecting = nil
end

function META:OnRemove()
    self.socket:close()
end

function META:Close(reason)
    self:Remove()
end

function META:Connect(host, service)
    if self:assert(self.socket:connect(host, service)) then
        self.connecting = true
    end
end

function META:Send(data)
    local ok, err

    if self.socket:is_connected() and not self.connecting then
        local pos = 0
        for i = 1, math.huge do
            ok, err = self.socket:send(data:sub(pos + 1))
            if ok then
                pos = pos + tonumber(ok)
            end

            if pos >= #data then
                break
            end
        end
    else
        ok, err = false, "timeout"
    end

    if not ok then
        if err == "timeout" then
            self.buffered_send = self.buffered_send or {}
            table.insert(self.buffered_send, data)
            return true
        end

        return self:Error(err)
    end

    return ok, err
end

function META:Update()
    if self.connecting then
        self.socket:poll_connect()
        if self.socket:is_connected() then
            if self.DoHandshake then
                local ok, err = self:DoHandshake()

                if not ok then
                    if err == "timeout" then
                        return
                    end

                    if err == "closed" then
                        self:OnClose("handshake")
                    else
                        self:Error(err)
                    end
                end

                self.DoHandshake = nil
            end

            self:OnConnect()
            self.connected = true
            self.connecting = false
        end
    elseif self.connected then

        if self.buffered_send then
            for _ = 1, #self.buffered_send * 4 do
                local data = self.buffered_send[1]

                if not data then break end

                local ok, err = self:Send(data)

                if ok then
                    table.remove(self.buffered_send)
                elseif err ~= "timeout" then
                    self:Error("error while processing buffered queue: " .. err)
                end
            end
        end

        local chunk, err = self.socket:receive()

        if chunk then
            self:OnReceiveChunk(chunk)
        else
            if err == "closed" then
                self:OnClose("receive")
            elseif err ~= "timeout" then
                self:Error(err)
            end
        end
    end
end

function META:Error(message, ...)
    local tr = debug.traceback()
    self:OnError(message, tr, ...)
    return false
end

function META:OnError(str, tr) print(tr) print(str) self:Remove(str) end
function META:OnReceiveChunk(str) end
function META:OnClose() self:Close() end
function META:OnConnect() end

return function(socket)
    local self = setmetatable({}, META)
    self:Initialize(socket)
    return self
end
