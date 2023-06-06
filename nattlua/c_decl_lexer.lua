-- http://unixwiz.net/techtips/reading-cdecl.html
local test = [[

union test {
		uint32_t u;
		struct { int a:10,b:10,c:11,d:1; };
		struct { unsigned int e:10,f:10,g:11,h:1; };
		struct { int8_t i:4,j:5,k:5,l:3; };
		struct { _Bool b0:1,b1:1,b2:1,b3:1; };
		};
		
		typedef struct s_ii { int x, y; } s_ii;
		typedef struct s_jj { int64_t x, y; } s_jj;
		typedef struct s_ff { float x, y; } s_ff;
		typedef struct s_dd { double x, y; } s_dd;
		typedef struct s_8i { int a,b,c,d,e,f,g,h; } s_8i;
		
		int call_i(int a);
		int call_ii(int a, int b);
		int call_10i(int a, int b, int c, int d, int e, int f, int g, int h, int i, int j);
		
		typedef enum { XYZ } e_u;
		
		e_u call_ie(e_u a) asm("call_i");
		
		int64_t call_ji(int64_t a, int b);
		int64_t call_ij(int a, int64_t b);
		int64_t call_jj(int64_t a, int64_t b);
		
		double call_dd(double a, double b);
		double call_10d(double a, double b, double c, double d, double e, double f, double g, double h, double i, double j);
		
		float call_ff(float a, float b);
		float call_10f(float a, float b, float c, float d, float e, float f, float g, float h, float i, float j);
		
		double call_idifjd(int a, double b, int c, float d, int64_t e, double f);
		
		int call_p_i(int *a);
		int *call_p_p(int *a);
		int call_pp_i(int *a, int *b);
		
		double call_ividi(int a, ...);
		
		s_ii call_sii(s_ii a);
		s_jj call_sjj(s_jj a);
		s_ff call_sff(s_ff a);
		s_dd call_sdd(s_dd a);
		s_8i call_s8i(s_8i a);
		s_ii call_siisii(s_ii a, s_ii b);
		s_ff call_sffsff(s_ff a, s_ff b);
		s_dd call_sddsdd(s_dd a, s_dd b);
		s_8i call_s8is8i(s_8i a, s_8i b);
		s_8i call_is8ii(int a, s_8i b, int c);
		
		int __fastcall fastcall_void(void);
		int __fastcall fastcall_i(int a);
		int __fastcall fastcall_ii(int a, int b);
		int __fastcall fastcall_iii(int a, int b, int c);
		int64_t __fastcall fastcall_ji(int64_t a, int b);
		double __fastcall fastcall_dd(double a, double b);
		int __fastcall fastcall_pp_i(int *a, int *b);
		s_ii __fastcall fastcall_siisii(s_ii a, s_ii b);
		s_dd __fastcall fastcall_sddsdd(s_dd a, s_dd b);
		
		int __stdcall stdcall_i(int a);
		int __stdcall stdcall_ii(int a, int b);
		double __stdcall stdcall_dd(double a, double b);
		float __stdcall stdcall_ff(float a, float b);
		
		void qsort(void *base, size_t nmemb, size_t size,
					 int (*compar)(const uint8_t *, const uint8_t *));
		
		
				typedef struct s_t {
						int v, w;
					} s_t;
					
					typedef const s_t cs_t;
					
					typedef enum en_t { EE } en_t;
					
					typedef struct pcs_t {
						int v;
						const int w;
					} pcs_t;
					
					typedef struct foo_t {
						static const int cc = 17;
						enum { CC = -37 };
						int i;
						const int ci;
						int bi:8;
						const int cbi:8;
						en_t e;
						const en_t ce;
						int a[10];
						const int ca[10];
						const char cac[10];
						s_t s;
						cs_t cs;
						pcs_t pcs1, pcs2;
						const struct {
							int ni;
						};
						complex cx;
						const complex ccx;
						complex *cp;
						const complex *ccp;
					} foo_t;     
		
					typedef struct bar_t {
						int v, w;
					} bar_t;
					// Same structure, but treated as different struct.
					typedef struct barx_t {
						int v, w;
					} barx_t;
					
					typedef struct nest_t {
						int a,b;
						struct { int c,d; };
						struct { int e1,e2; } e;
						int f[2];
					} nest_t;
					
					typedef union uni_t {
						int8_t a;
						int16_t b;
						int32_t c;
					} uni_t;
					
					typedef struct arrinc_t {
						int a[];
					} arrinc_t;
					
					typedef enum uenum_t {
						UE0, UE71 = 71, UE72
					} uenum_t;
					
					typedef enum ienum_t {
						IE0, IEM12 = -12, IEM11
					} ienum_t;
					
					typedef struct foo_t {
						bool b;
						int8_t i8;
						uint8_t u8;
						int16_t i16;
						uint16_t u16;
						int32_t i32;
						uint32_t u32;
						int64_t i64;
						uint64_t u64;
						float f;
						double d;
						complex cf;
						complex cd;
						uint8_t __attribute__((mode(__V16QI__))) v16qi;
						int __attribute__((mode(__V4SI__))) v4si;
						double __attribute__((mode(__V2DF__))) v2df;
						int *pi;
						int *__ptr32 p32i;
						const int *pci;
						volatile int *pvi;
						int **ppi;
						const int **ppci;
						void **ppv;
						char *(*ppf)(char *, const char *);
						int ai[10];
						int ai_guard;
						int ai2[10];
						char ac[10];
						char ac_guard;
						bar_t s;
						bar_t s2;
						bar_t *ps;
						const bar_t *pcs;
						barx_t sx;
						struct { int a,b,c; } si;
						int si_guard;
						nest_t sn;
						uni_t ui;
						uenum_t ue;
						ienum_t ie;
					} foo_t;
					
					char *strcpy(char *dest, const char *src);
					typedef struct FILE FILE;
					int fileno(FILE *stream);
					int _fileno(FILE *stream);
		
					typedef enum enum_i { FOO_I = -1, II = 10 } enum_i;
		typedef enum enum_u { FOO_U = 1, UU = 10 } enum_u;
		
		enum_i call_ei_i(int a) asm("call_i");
		enum_u call_eu_i(int a) asm("call_i");
		int call_i_ei(enum_i a) asm("call_i");
		int call_i_eu(enum_u a) asm("call_i");
		
		
		int call_10i(int a, int b, int c, int d, int e, int f, int g, int h, int i, int j);
		double call_10d(double a, double b, double c, double d, double e, double f, double g, double h, double i, double j);
		float call_10f(float a, float b, float c, float d, float e, float f, float g, float h, float i, float j);
		int64_t call_ij(int a, int64_t b);
		bool call_b(int a) asm("call_i");
		
		int64_t call_max(double,double,double,double,double,double,double,double,double,double,double,double,double,double,double,double,double) asm("call_10d");
		
		int64_t call_10j_p(int a, int b, int c, int d, int e, int f, int g, int h, int i, const char *p) asm("call_10j");
		
		int8_t call_i_i8(int a) asm("call_i");
		uint8_t call_i_u8(int a) asm("call_i");
		int16_t call_i_i16(int a) asm("call_i");
		uint16_t call_i_u16(int a) asm("call_i");
		int call_i8_i(int8_t a) asm("call_i");
		int call_u8_i(uint8_t a) asm("call_i");
		int call_i16_i(int16_t a) asm("call_i");
		int call_u16_i(uint16_t a) asm("call_i");
		
		int __fastcall fastcall_void(void);
		int __fastcall fastcall_i(int a);
		int __fastcall fastcall_ii(int a, int b);
		int __fastcall fastcall_iii(int a, int b, int c);
		int64_t __fastcall fastcall_ji(int64_t a, int b);
		double __fastcall fastcall_dd(double a, double b);
		int __fastcall fastcall_pp_i(int *a, int *b);
		
		int __stdcall stdcall_i(int a);
		int __stdcall stdcall_ii(int a, int b);
		double __stdcall stdcall_dd(double a, double b);
		float __stdcall stdcall_ff(float a, float b);
		
]]
local basic_types = {
	["char"] = true,
	["signed char"] = true,
	["unsigned char"] = true,
	["short"] = true,
	["short int"] = true,
	["signed short"] = true,
	["signed short int"] = true,
	["unsigned short"] = true,
	["unsigned short int"] = true,
	["int"] = true,
	["signed"] = true,
	["signed int"] = true,
	["unsigned"] = true,
	["unsigned int"] = true,
	["long"] = true,
	["long int"] = true,
	["signed long"] = true,
	["signed long int"] = true,
	["unsigned long"] = true,
	["unsigned long int"] = true,
	["long long"] = true,
	["long long int"] = true,
	["signed long long"] = true,
	["signed long long int"] = true,
	["unsigned long long"] = true,
	["unsigned long long int"] = true,
	["float"] = true,
	["double"] = true,
	["long double"] = true,
	["size_t"] = true,
	["_Boolean"] = true,
}
local META

do
	META = loadfile("nattlua/lexer.lua")()
	local characters = require("nattlua.syntax.characters")
	local arr = {}

	for type in pairs(basic_types) do
		if type:find(" ", nil, true) then table.insert(arr, type) end
	end

	table.sort(arr, function(a, b)
		return #a > #b
	end)

	function META:ReadLetter()--[[#: TokenReturnType]]
		if not characters.IsLetter(self:PeekByte()) then return false end

		if self:ReadFirstFromArray(arr) then return "letter" end

		while not self:TheEnd() do
			self:Advance(1)

			if not characters.IsDuringLetter(self:PeekByte()) then break end
		end

		return "letter"
	end
end

LEXER_META = META
local META

do
	META = loadfile("nattlua/parser/base.lua")()

	function META:ParseRootNode()
		local node = self:StartNode("statement", "root")
		node.statements = self:ParseStatements()

		if self:IsTokenType("end_of_file") then
			local eof = self:StartNode("statement", "end_of_file")
			eof.tokens["end_of_file"] = self.tokens[#self.tokens]
			eof = self:EndNode(eof)
			table.insert(node.statements, eof)
			node.tokens["eof"] = eof.tokens["end_of_file"]
		end

		return self:EndNode(node)
	end

	function META:ParseStatement()
		local node = self:ParseTypeDef()

		if node then return node end

		self:Error("expected statement")
	end

	function META:ParseTypeDef()
		if not self:IsTokenValue("typedef") then return end

		local node = self:StartNode("statement", "typedef")
		node.tokens["typedef"] = self:ExpectTokenType("letter")

		if self:IsTokenValue("struct") then node.struct = self:ParseStruct() end

		if self:IsTokenType("letter") then
			node.tokens["identifier"] = self:ExpectTokenType("letter")
		end

		node.tokens[";"] = self:ExpectTokenValue(";")
		return self:EndNode(node)
	end

	function META:ParseStruct()
		local node = self:StartNode("statement", "struct")
		node.tokens["struct"] = self:ExpectTokenValue("struct")

		if self:IsTokenType("letter") then
			node.tokens["identifier"] = self:ExpectTokenType("letter")
		end

		node.tokens["{"] = self:ExpectTokenValue("{")
		node.fields = {}

		while true do
			if self:IsTokenValue("}") then break end

			local field = self:StartNode("statement", "field")
			field.type_declaration = self:ParseTypeDeclaration()
			field.tokens["identifier"] = self:ExpectTokenType("letter")
			field.tokens[";"] = self:ExpectTokenValue(";")
			table.insert(node.fields, self:EndNode(field))
		end

		node.tokens["}"] = self:ExpectTokenValue("}")
		return self:EndNode(node)
	end

	do
		function META:ParseTypeDeclaration()
			local node = self:StartNode("expression", "type_declaration")

			if self:IsTokenType("letter") then
				node.tokens["type"] = self:ExpectTokenType("letter")
			end

			return self:EndNode(node)
		end
	end
end

local PARSER_META = META
local META

do
	META = loadfile("nattlua/transpiler/emitter.lua")()

	function META:BuildCode(block)
		self:EmitStatements(block.statements)
		return self:Concat()
	end

	function META:EmitStatement(node)
		if node.kind == "typedef" then self:EmitTypeDef(node) end
	end

	function META:EmitTypeDef(node)
		self:EmitToken(node.tokens["typedef"])

		if node.struct then self:EmitStruct(node.struct) end

		if node.tokens["identifier"] then
			self:EmitToken(node.tokens["identifier"])
		end

		self:EmitToken(node.tokens[";"])
	end

	function META:EmitStruct(node)
		self:EmitToken(node.tokens["struct"])

		if node.tokens["identifier"] then
			self:EmitToken(node.tokens["identifier"])
		end

		self:EmitToken(node.tokens["{"])

		for _, field in ipairs(node.fields) do
			self:EmitField(field)
		end

		self:EmitToken(node.tokens["}"])
	end

	function META:EmitField(node)
		self:EmitTypeDeclaration(node.type_declaration)
		self:EmitToken(node.tokens["identifier"])
		self:EmitToken(node.tokens[";"])
	end

	function META:EmitTypeDeclaration(node)
		if node.tokens["type"] then self:EmitToken(node.tokens["type"]) end
	end
end

local EMITTER_META = META
local Code = require("nattlua.code").New
local Lexer = LEXER_META.New
local Parser = PARSER_META.New
local Emitter = EMITTER_META.New
local code = Code(
	[[
	typedef struct uni_t {
		int8_t a;
		int16_t b;
		int32_t c;
	} uni_t;
				
	long long test(int a);
	int test(int a, int b);

	#define foo 1
	#pragma once

	/* test */
	// test

	static __inline int test(int a) {
		return a;
	};

	int foo(void);

	struct foo {int a;} foo_t, *foo_p;

	extern int foo;

]],
	"test.c"
)
local lex = Lexer(code)
local tokens = lex:GetTokens()
local parser = Parser(tokens, code)
local compiler = require("nattlua.compiler")
parser.OnError = function(parser, code, msg, start, stop, ...)
	return compiler.OnDiagnostic({}, code, msg, "fatal", start, stop, nil, ...)
end
print(Emitter():BuildCode(parser:ParseRootNode()), "!")