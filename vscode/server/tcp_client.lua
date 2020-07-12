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
    return "[" .. tostring(self.socket) .. "]"
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
    local ok, err = self.socket:connect(host, service)

    if ok then
        self.connecting = true
        return
    end

    return self:Error("Unable to connect to " .. host .. ":" .. service .. ": " .. err)
end

function META:Send(data)
    local ok, err
    if self.socket:is_connected() and not self.connecting then
        local pos = 0
        local t = os.clock() + 1
        for i = 1, math.huge do
            ok, err = self.socket:send(data:sub(pos + 1))

            if t < os.clock() then
                return false, "timeout"
            end

            if not ok and err ~= "timeout" then
                return self:Error(err)
            end

            if err ~= "timeout" then
                pos = pos + tonumber(ok)

                if pos >= #data then
                    break
                end
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
    return false, message
end

function META:OnError(str, tr) print(tr, str) self:Remove(str) end
function META:OnReceiveChunk(str) end
function META:OnClose() self:Close() end
function META:OnConnect() end

return function(socket)
    local self = setmetatable({}, META)
    self:Initialize(socket)
    return self
end
