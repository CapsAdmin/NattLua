return function(filter, logging, profiling)
	require("test.environment")

	_G.begin_tests(logging, profiling)

	for i = 1, tonumber(count or 1) do
		for _, test in ipairs(_G.find_tests(filter)) do
			_G.run_test(test)
		end
	end

	_G.end_tests()
end
