local ipairs = ipairs
local type_errors = require("nattlua.types.error_messages")
return function(self, obj, input)
	do
		local ok, reason, a, b, i = input:IsSubsetOfTuple(obj:GetInputSignature())

		if not ok then
			return false,
			type_errors.context(
				"argument #" .. i .. ":",
				type_errors.because(type_errors.subset(a, b), reason)
			)
		end
	end

	for i, arg in ipairs(input:GetData()) do
		if arg.Type == "table" and arg:GetAnalyzerEnvironment() == "runtime" then
			if self.config.external_mutation then
				self:Warning(type_errors.argument_mutation(i, arg))
			end
		end
	end

	local ret = obj:GetOutputSignature():Copy()

	-- clear any reference id from the returned arguments
	for _, v in ipairs(ret:GetData()) do
		if v.Type == "table" then v:SetReferenceId(nil) end
	end

	return ret
end
