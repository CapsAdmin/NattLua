test("recursive import crash repro", function()
    analyze([[
        import("test/tests/nattlua/analyzer/file_importing/recursive/a.nlua")
    ]])
end)
