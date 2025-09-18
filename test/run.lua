return function(filter, logging, profiling)
	require("test.environment")
	_G.begin_tests(logging, profiling)

	local tests = _G.find_tests(filter)
	_G.set_test_paths(tests)
	for i = 1, tonumber(count or 1) do
		for _, test in ipairs(tests) do
			_G.run_single_test(test)
		end
	end

	_G.end_tests()
end
