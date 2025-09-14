analyze[[
attest.expect_diagnostic<|"error", "subset"|>
attest.subset_of<|
	string | number | boolean | {[string] = CurrentType<|"union", 1|>},
	{
		foo = {1, 2, 3},
		bar = true,
		faz = {
			asdf = true,
			[2] = false,
			foo = {1, 2, 3},
			lol = {},
		},
	}
|>
attest.subset_of<|ffi.new<|"struct {int foo;}[1]"|>, ffi.new<|"struct {int foo;}*"|>|>
attest.expect_diagnostic<|"error", "subset"|>
attest.subset_of<|ffi.new<|"struct {int foo;}*"|>, ffi.new<|"struct {int foo;}[1]"|>|>
attest.expect_diagnostic<|"error", "subset"|>
attest.subset_of<|{foo = true, bar = false, faz = 1}, List<|any|>|>
attest.expect_diagnostic<|"error", "subset"|>
attest.subset_of<|"4" | 1 | 2 | 3, number | string|>
attest.subset_of<|{foo = number}, {foo = 1337}|>
attest.subset_of<|{type = "lol"}, {type = any, kind = any}|>
attest.subset_of<|{}, {}|>
attest.subset_of<|{}, {foo = nil}|>
attest.subset_of<|{}, {foo = any}|>
attest.subset_of<|{}, {foo = any | number}|>
attest.subset_of<|{}, {foo = nil | number}|>
attest.expect_diagnostic<|"error", "has no key string"|>
attest.subset_of<|{[777] = 777}, {[string] = any}|>
attest.subset_of<|{a = 2}, {["a" | "b" | "c"] = 1 | 2 | 3}|>
attest.subset_of<|{foo = 1337}, {foo = number}|>
attest.subset_of<|1 | 2 | 3, number|>
attest.subset_of<|1 | 2 | 3, 1 .. 5|>
attest.subset_of<|{foo = true}, {foo = true}|>
attest.subset_of<|{foo = true, bar = true}, {[any] = any}|>
attest.subset_of<|{[string] = any}, {[string] = number}|>
attest.subset_of<|{foo = true, bar = true}, {foo = true}|>
attest.expect_diagnostic<|"error", "not a subset of"|>
attest.subset_of<|{foo = true}, {foo = true, faz = true}|>
attest.expect_diagnostic<|"error", "not a subset of"|>
attest.subset_of<|{foo = true}, number | {foo = true, faz = true}|>
attest.expect_diagnostic<|"error", "not a subset of"|>
attest.subset_of<|({foo = true}, 1), (number | {foo = true, faz = true}, number)|>
]]
