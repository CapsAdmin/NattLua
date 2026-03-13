local a = {}
import.loaded["test/fixtures/emitter_import_cache/cycle_a.lua"] = a
a.other = import("test/fixtures/emitter_import_cache/cycle_b.lua")
return a
