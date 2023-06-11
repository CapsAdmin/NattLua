-- http://unixwiz.net/techtips/reading-cdecl.html
-- https://eli.thegreenplace.net/2007/11/24/the-context-sensitivity-of-cs-grammar/
local Lexer = require("nattlua.c_declarations.lexer").New
local Parser = require("nattlua.c_declarations.parser").New
local Emitter = require("nattlua.c_declarations.emitter").New
local Code = require("nattlua.code").New

local function test(c_code, parse_func, emit_func)
	parse_func = parse_func or "ParseRootNode"
	emit_func = emit_func or "BuildCode"
	local code = Code(c_code, "test.c")
	local lex = Lexer(code)
	local tokens = lex:GetTokens()
	local parser = Parser(tokens, code)
	local compiler = require("nattlua.compiler")
	parser.OnError = function(parser, code, msg, start, stop, ...)
		return compiler.OnDiagnostic({}, code, msg, "fatal", start, stop, nil, ...)
	end
	local emitter = Emitter({skip_translation = true})
	local res = emitter[emit_func](emitter, parser[parse_func](parser))
	res = res or emitter:Concat()

	if res ~= c_code then
		print("expected\n", c_code)
		print("got\n", res)
		diff(c_code, res)
		error("UH OH")
	end
end

test(
	"long static volatile int unsigned long *(*(**foo [2][8])(char *))[]",
	"ParseTypeDeclaration",
	"EmitTypeExpression"
)
test(
	"long static volatile int unsigned long long **foo[7]",
	"ParseTypeDeclaration",
	"EmitTypeExpression"
)
test("char* (*foo)(char*)", "ParseTypeDeclaration", "EmitTypeExpression")
test([[
typedef struct uni_t {
	int8_t a;
	int16_t b;
	int32_t c;
} uni_t;
]])
test([[
struct uni_t {
	int a : 1;
	int b : 1;
};
]])
test([[bool call_b(int * a);]])
test([[bool call_b(int * a) asm("test");]])
test([[typedef struct s_8i { int a,b,c,d,e,f,g,h; } s_8i;]])
test([[typedef union s_8i { int a,b,c,d,e,f,g,h; } s_8i;]])
test([[typedef enum s_8i { a,b,c,d,e,f,g,h } s_8i;]])
test([[enum s_8i { a,b };]])
test[[struct { _Bool b0:1,b1:1,b2:1,b3:1; };]]
test[[void foo(int a[1+2], int b);]]
test[[void foo(int a[1+2*2], int b);]]
test[[void foo(int a[1<<2], int b);]]
test[[void foo(int a[sizeof(int)], int b);]] --test[[void foo(int a[1?2:3], int b);]] WIP
test[[
	void qsort(int (*compar)(const uint8_t *, const uint8_t *));
]]
test[[
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
]]
test([[
union test {
        uint32_t u;
        struct { int a:10,b:10,c:11,d:1; };
        struct { unsigned int e:10,f:10,g:11,h:1; };
        struct { int8_t i:4,j:5,k:5,l:3; };
        struct { _Bool b0:1,b1:1,b2:1,b3:1; };
        };
        
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
			
	]])
test[[

        typedef enum bgfx_topology_sort{BGFX_TOPOLOGY_SORT_DIRECTION_FRONT_TO_BACK_MIN=0,BGFX_TOPOLOGY_SORT_DIRECTION_FRONT_TO_BACK_AVG=1,BGFX_TOPOLOGY_SORT_DIRECTION_FRONT_TO_BACK_MAX=2,BGFX_TOPOLOGY_SORT_DIRECTION_BACK_TO_FRONT_MIN=3,BGFX_TOPOLOGY_SORT_DIRECTION_BACK_TO_FRONT_AVG=4,BGFX_TOPOLOGY_SORT_DIRECTION_BACK_TO_FRONT_MAX=5,BGFX_TOPOLOGY_SORT_DISTANCE_FRONT_TO_BACK_MIN=6,BGFX_TOPOLOGY_SORT_DISTANCE_FRONT_TO_BACK_AVG=7,BGFX_TOPOLOGY_SORT_DISTANCE_FRONT_TO_BACK_MAX=8,BGFX_TOPOLOGY_SORT_DISTANCE_BACK_TO_FRONT_MIN=9,BGFX_TOPOLOGY_SORT_DISTANCE_BACK_TO_FRONT_AVG=10,BGFX_TOPOLOGY_SORT_DISTANCE_BACK_TO_FRONT_MAX=11,BGFX_TOPOLOGY_SORT_COUNT=12};
        typedef enum bgfx_attrib_type{BGFX_ATTRIB_TYPE_UINT8=0,BGFX_ATTRIB_TYPE_UINT10=1,BGFX_ATTRIB_TYPE_INT16=2,BGFX_ATTRIB_TYPE_HALF=3,BGFX_ATTRIB_TYPE_FLOAT=4,BGFX_ATTRIB_TYPE_COUNT=5};
        typedef enum bgfx_fatal{BGFX_FATAL_DEBUG_CHECK=0,BGFX_FATAL_INVALID_SHADER=1,BGFX_FATAL_UNABLE_TO_INITIALIZE=2,BGFX_FATAL_UNABLE_TO_CREATE_TEXTURE=3,BGFX_FATAL_DEVICE_LOST=4,BGFX_FATAL_COUNT=5};
        typedef enum bgfx_backbuffer_ratio{BGFX_BACKBUFFER_RATIO_EQUAL=0,BGFX_BACKBUFFER_RATIO_HALF=1,BGFX_BACKBUFFER_RATIO_QUARTER=2,BGFX_BACKBUFFER_RATIO_EIGHTH=3,BGFX_BACKBUFFER_RATIO_SIXTEENTH=4,BGFX_BACKBUFFER_RATIO_DOUBLE=5,BGFX_BACKBUFFER_RATIO_COUNT=6};
        typedef enum bgfx_topology_convert{BGFX_TOPOLOGY_CONVERT_TRI_LIST_FLIP_WINDING=0,BGFX_TOPOLOGY_CONVERT_TRI_LIST_TO_LINE_LIST=1,BGFX_TOPOLOGY_CONVERT_TRI_STRIP_TO_TRI_LIST=2,BGFX_TOPOLOGY_CONVERT_LINE_STRIP_TO_LINE_LIST=3,BGFX_TOPOLOGY_CONVERT_COUNT=4};
        typedef enum bgfx_access{BGFX_ACCESS_READ=0,BGFX_ACCESS_WRITE=1,BGFX_ACCESS_READWRITE=2,BGFX_ACCESS_COUNT=3};
        typedef enum bgfx_renderer_type{BGFX_RENDERER_TYPE_NOOP=0,BGFX_RENDERER_TYPE_DIRECT3D9=1,BGFX_RENDERER_TYPE_DIRECT3D11=2,BGFX_RENDERER_TYPE_DIRECT3D12=3,BGFX_RENDERER_TYPE_GNM=4,BGFX_RENDERER_TYPE_METAL=5,BGFX_RENDERER_TYPE_OPENGLES=6,BGFX_RENDERER_TYPE_OPENGL=7,BGFX_RENDERER_TYPE_VULKAN=8,BGFX_RENDERER_TYPE_COUNT=9};
        typedef enum bgfx_texture_format{BGFX_TEXTURE_FORMAT_BC1=0,BGFX_TEXTURE_FORMAT_BC2=1,BGFX_TEXTURE_FORMAT_BC3=2,BGFX_TEXTURE_FORMAT_BC4=3,BGFX_TEXTURE_FORMAT_BC5=4,BGFX_TEXTURE_FORMAT_BC6H=5,BGFX_TEXTURE_FORMAT_BC7=6,BGFX_TEXTURE_FORMAT_ETC1=7,BGFX_TEXTURE_FORMAT_ETC2=8,BGFX_TEXTURE_FORMAT_ETC2A=9,BGFX_TEXTURE_FORMAT_ETC2A1=10,BGFX_TEXTURE_FORMAT_PTC12=11,BGFX_TEXTURE_FORMAT_PTC14=12,BGFX_TEXTURE_FORMAT_PTC12A=13,BGFX_TEXTURE_FORMAT_PTC14A=14,BGFX_TEXTURE_FORMAT_PTC22=15,BGFX_TEXTURE_FORMAT_PTC24=16,BGFX_TEXTURE_FORMAT_UNKNOWN=17,BGFX_TEXTURE_FORMAT_R1=18,BGFX_TEXTURE_FORMAT_A8=19,BGFX_TEXTURE_FORMAT_R8=20,BGFX_TEXTURE_FORMAT_R8I=21,BGFX_TEXTURE_FORMAT_R8U=22,BGFX_TEXTURE_FORMAT_R8S=23,BGFX_TEXTURE_FORMAT_R16=24,BGFX_TEXTURE_FORMAT_R16I=25,BGFX_TEXTURE_FORMAT_R16U=26,BGFX_TEXTURE_FORMAT_R16F=27,BGFX_TEXTURE_FORMAT_R16S=28,BGFX_TEXTURE_FORMAT_R32I=29,BGFX_TEXTURE_FORMAT_R32U=30,BGFX_TEXTURE_FORMAT_R32F=31,BGFX_TEXTURE_FORMAT_RG8=32,BGFX_TEXTURE_FORMAT_RG8I=33,BGFX_TEXTURE_FORMAT_RG8U=34,BGFX_TEXTURE_FORMAT_RG8S=35,BGFX_TEXTURE_FORMAT_RG16=36,BGFX_TEXTURE_FORMAT_RG16I=37,BGFX_TEXTURE_FORMAT_RG16U=38,BGFX_TEXTURE_FORMAT_RG16F=39,BGFX_TEXTURE_FORMAT_RG16S=40,BGFX_TEXTURE_FORMAT_RG32I=41,BGFX_TEXTURE_FORMAT_RG32U=42,BGFX_TEXTURE_FORMAT_RG32F=43,BGFX_TEXTURE_FORMAT_RGB8=44,BGFX_TEXTURE_FORMAT_RGB8I=45,BGFX_TEXTURE_FORMAT_RGB8U=46,BGFX_TEXTURE_FORMAT_RGB8S=47,BGFX_TEXTURE_FORMAT_RGB9E5F=48,BGFX_TEXTURE_FORMAT_BGRA8=49,BGFX_TEXTURE_FORMAT_RGBA8=50,BGFX_TEXTURE_FORMAT_RGBA8I=51,BGFX_TEXTURE_FORMAT_RGBA8U=52,BGFX_TEXTURE_FORMAT_RGBA8S=53,BGFX_TEXTURE_FORMAT_RGBA16=54,BGFX_TEXTURE_FORMAT_RGBA16I=55,BGFX_TEXTURE_FORMAT_RGBA16U=56,BGFX_TEXTURE_FORMAT_RGBA16F=57,BGFX_TEXTURE_FORMAT_RGBA16S=58,BGFX_TEXTURE_FORMAT_RGBA32I=59,BGFX_TEXTURE_FORMAT_RGBA32U=60,BGFX_TEXTURE_FORMAT_RGBA32F=61,BGFX_TEXTURE_FORMAT_R5G6B5=62,BGFX_TEXTURE_FORMAT_RGBA4=63,BGFX_TEXTURE_FORMAT_RGB5A1=64,BGFX_TEXTURE_FORMAT_RGB10A2=65,BGFX_TEXTURE_FORMAT_RG11B10F=66,BGFX_TEXTURE_FORMAT_UNKNOWN_DEPTH=67,BGFX_TEXTURE_FORMAT_D16=68,BGFX_TEXTURE_FORMAT_D24=69,BGFX_TEXTURE_FORMAT_D24S8=70,BGFX_TEXTURE_FORMAT_D32=71,BGFX_TEXTURE_FORMAT_D16F=72,BGFX_TEXTURE_FORMAT_D24F=73,BGFX_TEXTURE_FORMAT_D32F=74,BGFX_TEXTURE_FORMAT_D0S8=75,BGFX_TEXTURE_FORMAT_COUNT=76};
        typedef enum bgfx_attrib{BGFX_ATTRIB_POSITION=0,BGFX_ATTRIB_NORMAL=1,BGFX_ATTRIB_TANGENT=2,BGFX_ATTRIB_BITANGENT=3,BGFX_ATTRIB_COLOR0=4,BGFX_ATTRIB_COLOR1=5,BGFX_ATTRIB_COLOR2=6,BGFX_ATTRIB_COLOR3=7,BGFX_ATTRIB_INDICES=8,BGFX_ATTRIB_WEIGHT=9,BGFX_ATTRIB_TEXCOORD0=10,BGFX_ATTRIB_TEXCOORD1=11,BGFX_ATTRIB_TEXCOORD2=12,BGFX_ATTRIB_TEXCOORD3=13,BGFX_ATTRIB_TEXCOORD4=14,BGFX_ATTRIB_TEXCOORD5=15,BGFX_ATTRIB_TEXCOORD6=16,BGFX_ATTRIB_TEXCOORD7=17,BGFX_ATTRIB_COUNT=18};
        typedef enum bgfx_view_mode{BGFX_VIEW_MODE_DEFAULT=0,BGFX_VIEW_MODE_SEQUENTIAL=1,BGFX_VIEW_MODE_DEPTH_ASCENDING=2,BGFX_VIEW_MODE_DEPTH_DESCENDING=3,BGFX_VIEW_MODE_CCOUNT=4};
        typedef enum bgfx_uniform_type{BGFX_UNIFORM_TYPE_INT1=0,BGFX_UNIFORM_TYPE_END=1,BGFX_UNIFORM_TYPE_VEC4=2,BGFX_UNIFORM_TYPE_MAT3=3,BGFX_UNIFORM_TYPE_MAT4=4,BGFX_UNIFORM_TYPE_COUNT=5};
        typedef enum bgfx_occlusion_query_result{BGFX_OCCLUSION_QUERY_RESULT_INVISIBLE=0,BGFX_OCCLUSION_QUERY_RESULT_VISIBLE=1,BGFX_OCCLUSION_QUERY_RESULT_NORESULT=2,BGFX_OCCLUSION_QUERY_RESULT_COUNT=3};
        struct bgfx_dynamic_index_buffer_handle {unsigned short idx;};
        struct bgfx_dynamic_vertex_buffer_handle {unsigned short idx;};
        struct bgfx_frame_buffer_handle {unsigned short idx;};
        struct bgfx_index_buffer_handle {unsigned short idx;};
        struct bgfx_indirect_buffer_handle {unsigned short idx;};
        struct bgfx_occlusion_query_handle {unsigned short idx;};
        struct bgfx_program_handle {unsigned short idx;};
        struct bgfx_shader_handle {unsigned short idx;};
        struct bgfx_texture_handle {unsigned short idx;};
        struct bgfx_uniform_handle {unsigned short idx;};
        struct bgfx_vertex_buffer_handle {unsigned short idx;};
        struct bgfx_vertex_decl_handle {unsigned short idx;};
        struct bgfx_memory {unsigned char*data;unsigned int size;};
        struct bgfx_transform {float*data;unsigned short num;};
        struct bgfx_hmd_eye {float rotation[4];float translation[3];float fov[4];float viewOffset[3];float projection[16];float pixelsPerTanAngle[2];};
        struct bgfx_hmd {struct bgfx_hmd_eye eye[2];unsigned short width;unsigned short height;unsigned int deviceWidth;unsigned int deviceHeight;unsigned char flags;};
        struct bgfx_view_stats {char name[256];unsigned short view;signed long cpuTimeElapsed;signed long gpuTimeElapsed;};
        struct bgfx_encoder_stats {signed long cpuTimeBegin;signed long cpuTimeEnd;};
        struct bgfx_stats {signed long cpuTimeFrame;signed long cpuTimeBegin;signed long cpuTimeEnd;signed long cpuTimerFreq;signed long gpuTimeBegin;signed long gpuTimeEnd;signed long gpuTimerFreq;signed long waitRender;signed long waitSubmit;unsigned int numDraw;unsigned int numCompute;unsigned int maxGpuLatency;unsigned short numDynamicIndexBuffers;unsigned short numDynamicVertexBuffers;unsigned short numFrameBuffers;unsigned short numIndexBuffers;unsigned short numOcclusionQueries;unsigned short numPrograms;unsigned short numShaders;unsigned short numTextures;unsigned short numUniforms;unsigned short numVertexBuffers;unsigned short numVertexDecls;signed long gpuMemoryMax;signed long gpuMemoryUsed;unsigned short width;unsigned short height;unsigned short textWidth;unsigned short textHeight;unsigned short numViews;struct bgfx_view_stats*viewStats;unsigned char numEncoders;struct bgfx_encoder_stats*encoderStats;};
        struct bgfx_encoder {};
        struct bgfx_vertex_decl {unsigned int hash;unsigned short stride;unsigned short offset[BGFX_ATTRIB_COUNT];unsigned short attributes[BGFX_ATTRIB_COUNT];};
        struct bgfx_transient_index_buffer {unsigned char*data;unsigned int size;struct bgfx_index_buffer_handle handle;unsigned int startIndex;};
        struct bgfx_transient_vertex_buffer {unsigned char*data;unsigned int size;unsigned int startVertex;unsigned short stride;struct bgfx_vertex_buffer_handle handle;struct bgfx_vertex_decl_handle decl;};
        struct bgfx_instance_data_buffer {unsigned char*data;unsigned int size;unsigned int offset;unsigned int num;unsigned short stride;struct bgfx_vertex_buffer_handle handle;};
        struct bgfx_texture_info {enum bgfx_texture_format format;unsigned int storageSize;unsigned short width;unsigned short height;unsigned short depth;unsigned short numLayers;unsigned char numMips;unsigned char bitsPerPixel;_Bool cubeMap;};
        struct bgfx_uniform_info {char name[256];enum bgfx_uniform_type type;unsigned short num;};
        struct bgfx_attachment {struct bgfx_texture_handle handle;unsigned short mip;unsigned short layer;};
        struct bgfx_caps_gpu {unsigned short vendorId;unsigned short deviceId;};
        struct bgfx_caps_limits {unsigned int maxDrawCalls;unsigned int maxBlits;unsigned int maxTextureSize;unsigned int maxViews;unsigned int maxFrameBuffers;unsigned int maxFBAttachments;unsigned int maxPrograms;unsigned int maxShaders;unsigned int maxTextures;unsigned int maxTextureSamplers;unsigned int maxVertexDecls;unsigned int maxVertexStreams;unsigned int maxIndexBuffers;unsigned int maxVertexBuffers;unsigned int maxDynamicIndexBuffers;unsigned int maxDynamicVertexBuffers;unsigned int maxUniforms;unsigned int maxOcclusionQueries;unsigned int maxEncoders;};
        struct bgfx_caps {enum bgfx_renderer_type rendererType;unsigned long supported;unsigned short vendorId;unsigned short deviceId;_Bool homogeneousDepth;_Bool originBottomLeft;unsigned char numGPUs;struct bgfx_caps_gpu gpu[4];struct bgfx_caps_limits limits;unsigned short formats[BGFX_TEXTURE_FORMAT_COUNT];};
        struct bgfx_callback_interface {const struct bgfx_callback_vtbl*vtbl;};
        struct bgfx_callback_vtbl {void(*fatal)(struct bgfx_callback_interface*,enum bgfx_fatal,const char*);void(*trace_vargs)(struct bgfx_callback_interface*,const char*,unsigned short,const char*,__builtin_va_list);void(*profiler_begin)(struct bgfx_callback_interface*,const char*,unsigned int,const char*,unsigned short);void(*profiler_begin_literal)(struct bgfx_callback_interface*,const char*,unsigned int,const char*,unsigned short);void(*profiler_end)(struct bgfx_callback_interface*);unsigned int(*cache_read_size)(struct bgfx_callback_interface*,unsigned long);_Bool(*cache_read)(struct bgfx_callback_interface*,unsigned long,void*,unsigned int);void(*cache_write)(struct bgfx_callback_interface*,unsigned long,const void*,unsigned int);void(*screen_shot)(struct bgfx_callback_interface*,const char*,unsigned int,unsigned int,unsigned int,const void*,unsigned int,_Bool);void(*capture_begin)(struct bgfx_callback_interface*,unsigned int,unsigned int,unsigned int,enum bgfx_texture_format,_Bool);void(*capture_end)(struct bgfx_callback_interface*);void(*capture_frame)(struct bgfx_callback_interface*,const void*,unsigned int);};
        struct bgfx_allocator_interface {const struct bgfx_allocator_vtbl*vtbl;};
        struct bgfx_allocator_vtbl {void*(*realloc)(struct bgfx_allocator_interface*,void*,unsigned long,unsigned long,const char*,unsigned int);};
        void(bgfx_update_dynamic_vertex_buffer)(struct bgfx_dynamic_vertex_buffer_handle,unsigned int,const struct bgfx_memory*);
        void(bgfx_set_instance_data_from_vertex_buffer)(struct bgfx_vertex_buffer_handle,unsigned int,unsigned int);
        struct bgfx_dynamic_vertex_buffer_handle(bgfx_create_dynamic_vertex_buffer)(unsigned int,const struct bgfx_vertex_decl*,unsigned short);
        struct bgfx_occlusion_query_handle(bgfx_create_occlusion_query)();
        _Bool(bgfx_is_texture_valid)(unsigned short,_Bool,unsigned short,enum bgfx_texture_format,unsigned int);
        void(bgfx_dbg_text_clear)(unsigned char,_Bool);
        void(bgfx_set_view_rect_auto)(unsigned short,unsigned short,unsigned short,enum bgfx_backbuffer_ratio);
        void(bgfx_set_palette_color)(unsigned char,const float);
        void(bgfx_alloc_instance_data_buffer)(struct bgfx_instance_data_buffer*,unsigned int,unsigned short);
        void(bgfx_blit)(unsigned short,struct bgfx_texture_handle,unsigned char,unsigned short,unsigned short,unsigned short,struct bgfx_texture_handle,unsigned char,unsigned short,unsigned short,unsigned short,unsigned short,unsigned short,unsigned short);
        struct bgfx_texture_handle(bgfx_create_texture_2d)(unsigned short,unsigned short,_Bool,unsigned short,enum bgfx_texture_format,unsigned int,const struct bgfx_memory*);
        unsigned int(bgfx_set_transform)(const void*,unsigned short);
        const struct bgfx_memory*(bgfx_make_ref_release)(const void*,unsigned int,void(*_releaseFn)(void*,void*),void*);
        void(bgfx_destroy_index_buffer)(struct bgfx_index_buffer_handle);
        void(bgfx_encoder_set_transient_index_buffer)(struct bgfx_encoder*,const struct bgfx_transient_index_buffer*,unsigned int,unsigned int);
        struct bgfx_texture_handle(bgfx_create_texture_3d)(unsigned short,unsigned short,unsigned short,_Bool,enum bgfx_texture_format,unsigned int,const struct bgfx_memory*);
        void(bgfx_dbg_text_vprintf)(unsigned short,unsigned short,unsigned char,const char*,__builtin_va_list);
        enum bgfx_occlusion_query_result(bgfx_get_result)(struct bgfx_occlusion_query_handle,signed int*);
        void(bgfx_encoder_set_instance_data_buffer)(struct bgfx_encoder*,const struct bgfx_instance_data_buffer*,unsigned int);
        void(bgfx_set_dynamic_vertex_buffer)(unsigned char,struct bgfx_dynamic_vertex_buffer_handle,unsigned int,unsigned int);
        void(bgfx_alloc_transient_vertex_buffer)(struct bgfx_transient_vertex_buffer*,unsigned int,const struct bgfx_vertex_decl*);
        struct bgfx_program_handle(bgfx_create_program)(struct bgfx_shader_handle,struct bgfx_shader_handle,_Bool);
        void(bgfx_end)(struct bgfx_encoder*);
        void(bgfx_set_state)(unsigned long,unsigned int);
        void(bgfx_vertex_decl_add)(struct bgfx_vertex_decl*,enum bgfx_attrib,unsigned char,enum bgfx_attrib_type,_Bool,_Bool);
        struct bgfx_frame_buffer_handle(bgfx_create_frame_buffer_from_nwh)(void*,unsigned short,unsigned short,enum bgfx_texture_format);
        void(bgfx_reset)(unsigned int,unsigned int,unsigned int);
        unsigned int(bgfx_frame)(_Bool);
        void(bgfx_encoder_set_compute_vertex_buffer)(struct bgfx_encoder*,unsigned char,struct bgfx_vertex_buffer_handle,enum bgfx_access);
        void(bgfx_destroy_dynamic_vertex_buffer)(struct bgfx_dynamic_vertex_buffer_handle);
        void(bgfx_reset_view)(unsigned short);
        void(bgfx_encoder_set_uniform)(struct bgfx_encoder*,struct bgfx_uniform_handle,const void*,unsigned short);
        void(bgfx_vertex_unpack)(float,enum bgfx_attrib,const struct bgfx_vertex_decl*,const void*,unsigned int);
        void(bgfx_set_vertex_buffer)(unsigned char,struct bgfx_vertex_buffer_handle,unsigned int,unsigned int);
        void(bgfx_set_view_order)(unsigned short,unsigned short,const unsigned short*);
        void(bgfx_set_marker)(const char*);
        void(bgfx_set_texture)(unsigned char,struct bgfx_uniform_handle,struct bgfx_texture_handle,unsigned int);
        _Bool(bgfx_alloc_transient_buffers)(struct bgfx_transient_vertex_buffer*,const struct bgfx_vertex_decl*,unsigned int,struct bgfx_transient_index_buffer*,unsigned int);
        void(bgfx_calc_texture_size)(struct bgfx_texture_info*,unsigned short,unsigned short,unsigned short,_Bool,_Bool,unsigned short,enum bgfx_texture_format);
        void(bgfx_vertex_convert)(const struct bgfx_vertex_decl*,void*,const struct bgfx_vertex_decl*,const void*,unsigned int);
        void(bgfx_destroy_texture)(struct bgfx_texture_handle);
        void(bgfx_request_screen_shot)(struct bgfx_frame_buffer_handle,const char*);
        void(bgfx_dispatch)(unsigned short,struct bgfx_program_handle,unsigned int,unsigned int,unsigned int,unsigned char);
        void(bgfx_encoder_set_index_buffer)(struct bgfx_encoder*,struct bgfx_index_buffer_handle,unsigned int,unsigned int);
        void(bgfx_encoder_set_instance_data_from_dynamic_vertex_buffer)(struct bgfx_encoder*,struct bgfx_dynamic_vertex_buffer_handle,unsigned int,unsigned int);
        void(bgfx_encoder_set_transient_vertex_buffer)(struct bgfx_encoder*,unsigned char,const struct bgfx_transient_vertex_buffer*,unsigned int,unsigned int);
        struct bgfx_dynamic_index_buffer_handle(bgfx_create_dynamic_index_buffer_mem)(const struct bgfx_memory*,unsigned short);
        void(bgfx_encoder_set_vertex_buffer)(struct bgfx_encoder*,unsigned char,struct bgfx_vertex_buffer_handle,unsigned int,unsigned int);
        void(bgfx_encoder_set_scissor_cached)(struct bgfx_encoder*,unsigned short);
        void(bgfx_set_view_name)(unsigned short,const char*);
        void(bgfx_encoder_submit_occlusion_query)(struct bgfx_encoder*,unsigned short,struct bgfx_program_handle,struct bgfx_occlusion_query_handle,signed int,_Bool);
        void(bgfx_set_view_clear_mrt)(unsigned short,unsigned short,float,unsigned char,unsigned char,unsigned char,unsigned char,unsigned char,unsigned char,unsigned char,unsigned char,unsigned char);
        void(bgfx_set_condition)(struct bgfx_occlusion_query_handle,_Bool);
        unsigned char(bgfx_get_supported_renderers)(unsigned char,enum bgfx_renderer_type*);
        void(bgfx_alloc_transient_index_buffer)(struct bgfx_transient_index_buffer*,unsigned int);
        void(bgfx_destroy_frame_buffer)(struct bgfx_frame_buffer_handle);
        struct bgfx_encoder*(bgfx_begin)();
        const struct bgfx_caps*(bgfx_get_caps)();
        struct bgfx_texture_handle(bgfx_create_texture_cube)(unsigned short,_Bool,unsigned short,enum bgfx_texture_format,unsigned int,const struct bgfx_memory*);
        unsigned short(bgfx_set_scissor)(unsigned short,unsigned short,unsigned short,unsigned short);
        struct bgfx_shader_handle(bgfx_create_shader)(const struct bgfx_memory*);
        void(bgfx_set_view_frame_buffer)(unsigned short,struct bgfx_frame_buffer_handle);
        void(bgfx_update_texture_cube)(struct bgfx_texture_handle,unsigned short,unsigned char,unsigned char,unsigned short,unsigned short,unsigned short,unsigned short,const struct bgfx_memory*,unsigned short);
        struct bgfx_indirect_buffer_handle(bgfx_create_indirect_buffer)(unsigned int);
        void(bgfx_set_compute_indirect_buffer)(unsigned char,struct bgfx_indirect_buffer_handle,enum bgfx_access);
        _Bool(bgfx_init)(enum bgfx_renderer_type,unsigned short,unsigned short,struct bgfx_callback_interface*,struct bgfx_allocator_interface*);
        struct bgfx_uniform_handle(bgfx_create_uniform)(const char*,enum bgfx_uniform_type,unsigned short);
        struct bgfx_dynamic_vertex_buffer_handle(bgfx_create_dynamic_vertex_buffer_mem)(const struct bgfx_memory*,const struct bgfx_vertex_decl*,unsigned short);
        void(bgfx_set_compute_dynamic_vertex_buffer)(unsigned char,struct bgfx_dynamic_vertex_buffer_handle,enum bgfx_access);
        unsigned short(bgfx_encoder_set_scissor)(struct bgfx_encoder*,unsigned short,unsigned short,unsigned short,unsigned short);
        void(bgfx_encoder_set_compute_dynamic_index_buffer)(struct bgfx_encoder*,unsigned char,struct bgfx_dynamic_index_buffer_handle,enum bgfx_access);
        void(bgfx_encoder_set_instance_data_from_vertex_buffer)(struct bgfx_encoder*,struct bgfx_vertex_buffer_handle,unsigned int,unsigned int);
        void(bgfx_encoder_set_condition)(struct bgfx_encoder*,struct bgfx_occlusion_query_handle,_Bool);
        void(bgfx_topology_sort_tri_list)(enum bgfx_topology_sort,void*,unsigned int,const float,const float,const void*,unsigned int,const void*,unsigned int,_Bool);
        struct bgfx_frame_buffer_handle(bgfx_create_frame_buffer_from_attachment)(unsigned char,const struct bgfx_attachment*,_Bool);
        const struct bgfx_memory*(bgfx_alloc)(unsigned int);
        struct bgfx_program_handle(bgfx_create_compute_program)(struct bgfx_shader_handle,_Bool);
        void(bgfx_update_texture_2d)(struct bgfx_texture_handle,unsigned short,unsigned char,unsigned short,unsigned short,unsigned short,unsigned short,const struct bgfx_memory*,unsigned short);
        void(bgfx_update_texture_3d)(struct bgfx_texture_handle,unsigned char,unsigned short,unsigned short,unsigned short,unsigned short,unsigned short,unsigned short,const struct bgfx_memory*);
        void(bgfx_vertex_decl_skip)(struct bgfx_vertex_decl*,unsigned char);
        unsigned int(bgfx_encoder_set_transform)(struct bgfx_encoder*,const void*,unsigned short);
        void(bgfx_vertex_decl_end)(struct bgfx_vertex_decl*);
        unsigned int(bgfx_get_avail_transient_vertex_buffer)(unsigned int,const struct bgfx_vertex_decl*);
        void(bgfx_dbg_text_image)(unsigned short,unsigned short,unsigned short,unsigned short,const void*,unsigned short);
        void(bgfx_set_compute_vertex_buffer)(unsigned char,struct bgfx_vertex_buffer_handle,enum bgfx_access);
        void(bgfx_encoder_submit)(struct bgfx_encoder*,unsigned short,struct bgfx_program_handle,signed int,_Bool);
        unsigned short(bgfx_get_shader_uniforms)(struct bgfx_shader_handle,struct bgfx_uniform_handle*,unsigned short);
        void(bgfx_set_index_buffer)(struct bgfx_index_buffer_handle,unsigned int,unsigned int);
        void(bgfx_destroy_indirect_buffer)(struct bgfx_indirect_buffer_handle);
        void(bgfx_dispatch_indirect)(unsigned short,struct bgfx_program_handle,struct bgfx_indirect_buffer_handle,unsigned short,unsigned short,unsigned char);
        void(bgfx_encoder_set_transform_cached)(struct bgfx_encoder*,unsigned int,unsigned short);
        void(bgfx_encoder_discard)(struct bgfx_encoder*);
        void(bgfx_set_transient_index_buffer)(const struct bgfx_transient_index_buffer*,unsigned int,unsigned int);
        void(bgfx_set_scissor_cached)(unsigned short);
        void(bgfx_encoder_set_compute_index_buffer)(struct bgfx_encoder*,unsigned char,struct bgfx_index_buffer_handle,enum bgfx_access);
        struct bgfx_frame_buffer_handle(bgfx_create_frame_buffer_from_handles)(unsigned char,const struct bgfx_texture_handle*,_Bool);
        void(bgfx_submit)(unsigned short,struct bgfx_program_handle,signed int,_Bool);
        void(bgfx_destroy_program)(struct bgfx_program_handle);
        void(bgfx_encoder_set_dynamic_index_buffer)(struct bgfx_encoder*,struct bgfx_dynamic_index_buffer_handle,unsigned int,unsigned int);
        void(bgfx_destroy_vertex_buffer)(struct bgfx_vertex_buffer_handle);
        void(bgfx_touch)(unsigned short);
        void(bgfx_set_image)(unsigned char,struct bgfx_texture_handle,unsigned char,enum bgfx_access,enum bgfx_texture_format);
        void(bgfx_encoder_set_state)(struct bgfx_encoder*,unsigned long,unsigned int);
        void(bgfx_encoder_blit)(struct bgfx_encoder*,unsigned short,struct bgfx_texture_handle,unsigned char,unsigned short,unsigned short,unsigned short,struct bgfx_texture_handle,unsigned char,unsigned short,unsigned short,unsigned short,unsigned short,unsigned short,unsigned short);
        void(bgfx_encoder_dispatch_indirect)(struct bgfx_encoder*,unsigned short,struct bgfx_program_handle,struct bgfx_indirect_buffer_handle,unsigned short,unsigned short,unsigned char);
        void(bgfx_encoder_dispatch)(struct bgfx_encoder*,unsigned short,struct bgfx_program_handle,unsigned int,unsigned int,unsigned int,unsigned char);
        void(bgfx_encoder_set_compute_indirect_buffer)(struct bgfx_encoder*,unsigned char,struct bgfx_indirect_buffer_handle,enum bgfx_access);
        void(bgfx_encoder_set_compute_dynamic_vertex_buffer)(struct bgfx_encoder*,unsigned char,struct bgfx_dynamic_vertex_buffer_handle,enum bgfx_access);
        void(bgfx_encoder_set_image)(struct bgfx_encoder*,unsigned char,struct bgfx_texture_handle,unsigned char,enum bgfx_access,enum bgfx_texture_format);
        void(bgfx_encoder_submit_indirect)(struct bgfx_encoder*,unsigned short,struct bgfx_program_handle,struct bgfx_indirect_buffer_handle,unsigned short,unsigned short,signed int,_Bool);
        struct bgfx_texture_handle(bgfx_create_texture_2d_scaled)(enum bgfx_backbuffer_ratio,_Bool,unsigned short,enum bgfx_texture_format,unsigned int);
        unsigned int(bgfx_topology_convert)(enum bgfx_topology_convert,void*,unsigned int,const void*,unsigned int,_Bool);
        unsigned short(bgfx_weld_vertices)(unsigned short*,const struct bgfx_vertex_decl*,const void*,unsigned short,float);
        void(bgfx_destroy_uniform)(struct bgfx_uniform_handle);
        void(bgfx_shutdown)();
        void(bgfx_vertex_decl_begin)(struct bgfx_vertex_decl*,enum bgfx_renderer_type);
        void(bgfx_set_view_scissor)(unsigned short,unsigned short,unsigned short,unsigned short,unsigned short);
        void(bgfx_submit_indirect)(unsigned short,struct bgfx_program_handle,struct bgfx_indirect_buffer_handle,unsigned short,unsigned short,signed int,_Bool);
        unsigned int(bgfx_alloc_transform)(struct bgfx_transform*,unsigned short);
        void(bgfx_vertex_pack)(const float,_Bool,enum bgfx_attrib,const struct bgfx_vertex_decl*,void*,unsigned int);
        void(bgfx_set_stencil)(unsigned int,unsigned int);
        struct bgfx_texture_handle(bgfx_create_texture)(const struct bgfx_memory*,unsigned int,unsigned char,struct bgfx_texture_info*);
        void(bgfx_encoder_touch)(struct bgfx_encoder*,unsigned short);
        void(bgfx_set_view_transform_stereo)(unsigned short,const void*,const void*,unsigned char,const void*);
        struct bgfx_frame_buffer_handle(bgfx_create_frame_buffer_scaled)(enum bgfx_backbuffer_ratio,enum bgfx_texture_format,unsigned int);
        void(bgfx_submit_occlusion_query)(unsigned short,struct bgfx_program_handle,struct bgfx_occlusion_query_handle,signed int,_Bool);
        const struct bgfx_memory*(bgfx_copy)(const void*,unsigned int);
        enum bgfx_renderer_type(bgfx_get_renderer_type)();
        const struct bgfx_hmd*(bgfx_get_hmd)();
        void(bgfx_encoder_set_texture)(struct bgfx_encoder*,unsigned char,struct bgfx_uniform_handle,struct bgfx_texture_handle,unsigned int);
        void(bgfx_set_uniform)(struct bgfx_uniform_handle,const void*,unsigned short);
        void(bgfx_destroy_dynamic_index_buffer)(struct bgfx_dynamic_index_buffer_handle);
        const struct bgfx_stats*(bgfx_get_stats)();
        struct bgfx_index_buffer_handle(bgfx_create_index_buffer)(const struct bgfx_memory*,unsigned short);
        void(bgfx_set_debug)(unsigned int);
        const char*(bgfx_get_renderer_name)(enum bgfx_renderer_type);
        void(bgfx_set_shader_name)(struct bgfx_shader_handle,const char*);
        void(bgfx_set_texture_name)(struct bgfx_texture_handle,const char*);
        const struct bgfx_memory*(bgfx_make_ref)(const void*,unsigned int);
        void(bgfx_set_instance_data_buffer)(const struct bgfx_instance_data_buffer*,unsigned int);
        unsigned int(bgfx_get_avail_instance_data_buffer)(unsigned int,unsigned short);
        void(bgfx_destroy_shader)(struct bgfx_shader_handle);
        void(bgfx_get_uniform_info)(struct bgfx_uniform_handle,struct bgfx_uniform_info*);
        unsigned int(bgfx_read_texture)(struct bgfx_texture_handle,void*,unsigned char);
        struct bgfx_vertex_buffer_handle(bgfx_create_vertex_buffer)(const struct bgfx_memory*,const struct bgfx_vertex_decl*,unsigned short);
        struct bgfx_frame_buffer_handle(bgfx_create_frame_buffer)(unsigned short,unsigned short,enum bgfx_texture_format,unsigned int);
        unsigned int(bgfx_encoder_alloc_transform)(struct bgfx_encoder*,struct bgfx_transform*,unsigned short);
        void(bgfx_set_view_mode)(unsigned short,enum bgfx_view_mode);
        struct bgfx_texture_handle(bgfx_get_texture)(struct bgfx_frame_buffer_handle,unsigned char);
        void(bgfx_destroy_occlusion_query)(struct bgfx_occlusion_query_handle);
        void(bgfx_set_view_rect)(unsigned short,unsigned short,unsigned short,unsigned short,unsigned short);
        void(bgfx_set_view_transform)(unsigned short,const void*,const void*);
        unsigned int(bgfx_get_avail_transient_index_buffer)(unsigned int);
        void(bgfx_update_dynamic_index_buffer)(struct bgfx_dynamic_index_buffer_handle,unsigned int,const struct bgfx_memory*);
        void(bgfx_set_instance_data_from_dynamic_vertex_buffer)(struct bgfx_dynamic_vertex_buffer_handle,unsigned int,unsigned int);
        struct bgfx_dynamic_index_buffer_handle(bgfx_create_dynamic_index_buffer)(unsigned int,unsigned short);
        void(bgfx_set_transform_cached)(unsigned int,unsigned short);
        void(bgfx_set_dynamic_index_buffer)(struct bgfx_dynamic_index_buffer_handle,unsigned int,unsigned int);
        void(bgfx_set_transient_vertex_buffer)(unsigned char,const struct bgfx_transient_vertex_buffer*,unsigned int,unsigned int);
        void(bgfx_dbg_text_printf)(unsigned short,unsigned short,unsigned char,const char*,...);
        void(bgfx_set_view_clear)(unsigned short,unsigned short,unsigned int,float,unsigned char);
        void(bgfx_set_compute_index_buffer)(unsigned char,struct bgfx_index_buffer_handle,enum bgfx_access);
        void(bgfx_set_compute_dynamic_index_buffer)(unsigned char,struct bgfx_dynamic_index_buffer_handle,enum bgfx_access);
        void(bgfx_discard)();
        void(bgfx_encoder_set_marker)(struct bgfx_encoder*,const char*);
        void(bgfx_encoder_set_stencil)(struct bgfx_encoder*,unsigned int,unsigned int);
        void(bgfx_encoder_set_dynamic_vertex_buffer)(struct bgfx_encoder*,unsigned char,struct bgfx_dynamic_vertex_buffer_handle,unsigned int,unsigned int);


    ]]