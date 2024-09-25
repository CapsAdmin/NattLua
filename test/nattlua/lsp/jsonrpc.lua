local rpc_util = require("language_server.jsonrpc")
local json = require("language_server.json")
local receive_json = rpc_util.ReceiveJSON

do
	local function table_equal(o1, o2, ignore_mt, callList)
		if o1 == o2 then return true end

		callList = callList or {}
		local o1Type = type(o1)
		local o2Type = type(o2)

		if o1Type ~= o2Type then return false end

		if o1Type ~= "table" then return false end

		-- add only when objects are tables, cache results
		local oComparisons = callList[o1]

		if not oComparisons then
			oComparisons = {}
			callList[o1] = oComparisons
		end

		-- false means that comparison is in progress
		oComparisons[o2] = false

		if not ignore_mt then
			local mt1 = getmetatable(o1)

			if mt1 and mt1.__eq then
				--compare using built in method
				return o1 == o2
			end
		end

		local keySet = {}

		for key1, value1 in pairs(o1) do
			local value2 = o2[key1]

			if value2 == nil then return false end

			local vComparisons = callList[value1]

			if not vComparisons or vComparisons[value2] == nil then
				if not table_equal(value1, value2, ignore_mt, callList) then
					return false
				end
			end

			keySet[key1] = true
		end

		for key2, _ in pairs(o2) do
			if not keySet[key2] then return false end
		end

		-- comparison finished - objects are equal do not compare again
		oComparisons[o2] = true
		return true
	end

	local function equal_json(a, b)
		if type(a) == "table" then a = json.encode(a) end

		if type(b) == "table" then b = json.encode(b) end

		if not table_equal(json.decode(a), json.decode(b)) then
			error(a .. "\n~=\n" .. b, 2)
		end
	end

	local LSP = {}
	LSP["subtract"] = function(params)
		return params[1] - params[2]
	end
	LSP["subtract2"] = function(params)
		return params.a - params.b
	end
	LSP["notify"] = function(params) --print("got update", table.unpack(params))
	end

	local function receive(json)
		return receive_json(json, LSP)
	end

	do
		equal_json(
			receive([[{"jsonrpc": "2.0", "method": "subtract", "params": [42, 23], "id": 1}]]),
			[[{"jsonrpc":"2.0","result":19,"id":1}]]
		)
		equal_json(
			receive([[{"jsonrpc": "2.0", "method": "subtract", "params": [23, 42], "id": 2}]]),
			[[{"jsonrpc": "2.0", "result": -19, "id": 2}]]
		)
		equal_json(
			receive([[{"jsonrpc": "2.0", "method": "subtract2", "params": {"a": 23, "b": 42}, "id": 3}]]),
			[[{"jsonrpc":"2.0","result":-19,"id":3}]]
		)
		equal_json(
			receive([[{"jsonrpc": "2.0", "method": "subtract2", "params": {"a": 42, "b": 23}, "id": 4}]]),
			[[{"jsonrpc": "2.0", "result": 19, "id": 4}]]
		)
	end

	equal(receive([[{"jsonrpc": "2.0", "method": "notify", "params": [1,2,3,4,5]}]]), nil)
	equal_json(
		receive([[{"jsonrpc": "2.0", "method": "foobar", "id": "1"}]]),
		[[{"jsonrpc": "2.0", "error": {"code": -32601, "message": "Method foobar not found."}, "id": "1"}]]
	)
	equal_json(
		receive([[{"jsonrpc": "2.0", "method": "foobar, "params": "bar", "baz]   ]]),
		[[{"jsonrpc": "2.0", "error": {"code": -32700, "message": "expected '}' or ',' at line 1 col 41"}, "id": null}]]
	)
	equal_json(
		receive([[{"jsonrpc": "2.0", "method": 1, "params": "bar"}]]),
		[[{"jsonrpc": "2.0", "error": {"code": -32600, "message": "method must be a string"}, "id": null}]]
	)
	equal_json(
		receive([=[[
        {"jsonrpc": "2.0", "method": "subtract", "params": [42, 23], "id": 1},
        {"jsonrpc": "2.0", "method": "subtract", "params": [42, 23], "id": 2},
        {"jsonrpc": "2.0", "method": "subtract", "params": [42, 23], "id": 3},
    ]]=]),
		[=[[{"jsonrpc":"2.0","result":19,"id":1}, {"jsonrpc":"2.0","result":19,"id":2},{"jsonrpc":"2.0","result":19,"id":3}]]=]
	)
	equal_json(
		receive([=[[]]=]),
		[[{"jsonrpc": "2.0", "error": {"code": -32600, "message": "empty batch array request"}, "id": null}]]
	)
	equal(
		receive([=[[
            {"jsonrpc": "2.0", "method": "notify", "params": [1,2,4]},
            {"jsonrpc": "2.0", "method": "notify", "params": [7]}
        ]]=]),
		nil
	)
	equal_json(
		receive([=[[
            {"jsonrpc": "2.0", "method": "subtract", "params": [42, 23], "id": 1},
            {"jsonrpc": "2.0", "method": "notify", "params": [1,2,3,4,5]},
            {"jsonrpc": "2.0", "method": 1, "params": "bar"},
            {"jsonrpc": "2.0", "method": "foobar", "id": "1"},
            {"jsonrpc": "2.0", "method": "subtract", "params": [42, 23], "id": 1},
        ]]=]),
		[=[
            [
                {"result":19,"id":1,"jsonrpc":"2.0"},
                {"error":{"code":-32600,"message":"method must be a string"},"jsonrpc":"2.0"},
                {"id":"1","error":{"code":-32601,"message":"Method foobar not found."},"jsonrpc":"2.0"},
                {"result":19,"id":1,"jsonrpc":"2.0"}
            ]
        ]=]
	)
end

do
	local function write_http(data)
		return ("Content-Length: %s\r\n\r\n%s"):format(#data, data)
	end

	do
		local state = {}
		rpc_util.ReceiveHTTP(state, write_http([[{"jsonrpc": "2.0", "method": "foobar", "id": "1"}]]))
		assert(#state.buffer == 0)
	end

	do
		local state = {}
		local data = [[{"jsonrpc": "2.0", "method": "foobar", "id": "1"}]]
		assert(rpc_util.ReceiveHTTP(state, "Content-Length: " .. #data .. "\r\n\r\n") == nil)
		assert(rpc_util.ReceiveHTTP(state, data:sub(1, 19)) == nil)
		assert(rpc_util.ReceiveHTTP(state, data:sub(20)) == data)
	end

	do
		local state = {}
		local body = [[{"jsonrpc": "2.0", "method": "foobar", "id": "1"}]]
		local data = ""

		for i = 1, 3 do
			data = data .. "Content-Length: " .. #body .. "\r\n\r\n" .. body
		end

		assert(rpc_util.ReceiveHTTP(state, data) == body)
		assert(rpc_util.ReceiveHTTP(state, nil) == body)
		assert(rpc_util.ReceiveHTTP(state, nil) == body)
		assert(rpc_util.ReceiveHTTP(state, nil) == nil)
	end
end
