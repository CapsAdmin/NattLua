return function(filter, logging, profiling, profiling_mode)
	require("test.environment")
	_G.begin_tests(logging, profiling, profiling_mode)
	local tests = _G.find_tests(filter)
	_G.set_test_paths(tests)

	for _, test in ipairs(tests) do
		_G.run_single_test(test)
	end

	_G.end_tests()
end
