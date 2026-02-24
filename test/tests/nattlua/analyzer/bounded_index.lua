-- Test that for i = 1, #arr; arr[i] does NOT include nil
-- when the index is bounded by the same array's length
test("bounded index should not include nil", function()
	analyze[[
		local arr: {[number] = string} = {"a", "b", "c"}
		for i = 1, #arr do
			local val = arr[i]
			attest.equal(val, _ as string)
		end
	]]
end)

test("unbounded index should still include nil", function()
	analyze[[
		local arr: {[number] = string} = {"a", "b", "c"}
		local other: {[number] = string} = {"x"}
		for i = 1, #other do
			local val = arr[i]
			attest.equal(val, _ as nil | string)
		end
	]]
end)

test("bounded src[i] push to dst should work", function()
	analyze[[
		local type T = {x = number}
		local dst: {[number] = T} = {{x = 0} as T}
		local src: {[number] = T} = {{x = 1} as T}
		for i = 1, #src do
			dst[#dst + 1] = src[i]
			attest.equal(src[i], _ as T)
		end
	]]
end)
