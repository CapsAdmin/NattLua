--[[
    some lines before the code
]] local a = 2 + 1
-- ERROR3
assert(
	loadfile(
		"test/tests/nattlua/analyzer/file_importing/deep_error/deep_error/file_that_errors.nlua"
	)
)()