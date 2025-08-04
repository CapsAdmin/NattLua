local ipairs = ipairs
local type_errors = require("nattlua.types.error_messages")
return function(analyzer, obj, input)
	do
		local new_tup, errors = input:SubsetOrFallbackWithTuple(obj:GetInputSignature())

		if err then
			for _, error in ipairs(errors) do
				local reason, a, b, i = table.unpack(error)
				analyzer:Error(
					type_errors.context("argument #" .. i .. ":", type_errors.because(type_errors.subset(a, b), reason))
				)
			end
		end

		input = new_tup
	end

	for i, arg in ipairs(input:GetData()) do
		if arg.Type == "table" and arg:GetAnalyzerEnvironment() == "runtime" then
			if analyzer.config.external_mutation then
				analyzer:Warning(type_errors.argument_mutation(i, arg))
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
