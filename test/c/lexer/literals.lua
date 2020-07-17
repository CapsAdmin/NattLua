local oh = require("oh")

local function check(code)
	local o = oh.Code(code)
	o.Lexer = require("oh.c.lexer")
	o.Parser = require("oh.c.parser")
	o.Emitter = require("oh.c.emitter")
	assert(o:Parse()):Emit()
	return o.Tokens
 end

it("should handle unicode", function()
	local tokens = check([[

		#define HE HI
		#define LLO _THERE
		#define HELLO "HI THERE"
		#define CAT(a,b) a##b
		#define XCAT(a,b) CAT(a,b)
		#define CALL(fn) fn(HE,LLO)

		CAT(HE,LLO) // "HI THERE", because concatenation occurs before normal expansion
		XCAT(HE,LLO) // HI_THERE, because the tokens originating from parameters ("HE" and "LLO") are expanded first
		CALL(CAT) // "HI THERE", because parameters are expanded first

		#if lol >= 2
			print(1)
		#endif

		unsigned int main(unsigned char lol) {
			return 0;
		}
	]])

	for _, token in ipairs(tokens) do
		print(token)
   	end
end)