local ipairs = ipairs
local error_messages = require("nattlua.error_messages")
local table_unpack = _G.table.unpack or _G.unpack
return function(analyzer, obj, input)
	do
		local new_tup, errors = input:SubsetOrFallbackWithTuple(obj:GetInputSignature())

		if errors then
			for _, error in ipairs(errors) do
				local reason, a, b, i = error[1], error[2], error[3], error[4]
				analyzer:Error(error_messages.argument(i, error_messages.because(error_messages.subset(a, b), reason)))
			end
		end

		input = new_tup
	end

	for i, arg in ipairs(input:GetData()) do
		if arg.Type == "table" and arg:GetAnalyzerEnvironment() == "runtime" then
			if analyzer.config.external_mutation then
				analyzer:Warning(error_messages.argument_mutation(i, arg))
			end
		end
	end

	local ret = obj:GetOutputSignature():Copy()

	-- clear any reference id from the returned arguments
	for _, v in ipairs(ret:GetData()) do
		if v.Type == "table" then v:SetReferenceId(false) end
	end

	return ret
end
