local ffi = require("ffi")

local terminal = {}

if jit.os ~= "OSX" then
    ffi.cdef([[
        struct termios
        {
            unsigned int c_iflag;		/* input mode flags */
            unsigned int c_oflag;		/* output mode flags */
            unsigned int c_cflag;		/* control mode flags */
            unsigned int c_lflag;		/* local mode flags */
            unsigned char c_line;			/* line discipline */
            unsigned char c_cc[32];		/* control characters */
            unsigned int c_ispeed;		/* input speed */
            unsigned int c_ospeed;		/* output speed */
        };
    ]])
else
    ffi.cdef([[
        struct termios
        {
            unsigned long c_iflag;		/* input mode flags */
            unsigned long c_oflag;		/* output mode flags */
            unsigned long c_cflag;		/* control mode flags */
            unsigned long c_lflag;		/* local mode flags */
            unsigned char c_cc[20];		/* control characters */
            unsigned long c_ispeed;		/* input speed */
            unsigned long c_ospeed;		/* output speed */
        };
    ]])
end

ffi.cdef([[
    int tcgetattr(int, struct termios *);
    int tcsetattr(int, int, const struct termios *);

    typedef struct FILE FILE;
    size_t fwrite(const char *ptr, size_t size, size_t nmemb, FILE *stream);
    size_t fread( char * ptr, size_t size, size_t count, FILE * stream );

    ssize_t read(int fd, void *buf, size_t count);
    int fileno(FILE *stream);

    int ferror(FILE*stream);
]])

local VMIN = 6
local VTIME = 5
local TCSANOW = 0
local flags

if jit.os ~= "OSX" then
    flags = {
        ECHOCTL = 512,
        EXTPROC = 65536,
        ECHOK = 32,
        NOFLSH = 128,
        FLUSHO = 4096,
        ECHONL = 64,
        ECHOE = 16,
        ECHOKE = 2048,
        ECHO = 8,
        ICANON = 2,
        IEXTEN = 32768,
        PENDIN = 16384,
        XCASE = 4,
        ECHOPRT = 1024,
        TOSTOP = 256,
        ISIG = 1,
    }
else
    VMIN = 16
    VTIME = 17
    flags = {
        ECHOKE = 0x00000001,
        ECHOE = 0x00000002,
        ECHOK = 0x00000004,
        ECHO = 0x00000008,
        ECHONL = 0x00000010,
        ECHOPRT = 0x00000020,
        ECHOCTL = 0x00000040,
        ISIG = 0x00000080,
        ICANON = 0x00000100,
        ALTWERASE = 0x00000200,
        IEXTEN = 0x00000400,
        EXTPROC = 0x00000800,
        TOSTOP = 0x00400000,
        FLUSHO = 0x00800000,
        NOKERNINFO = 0x02000000,
        PENDIN = 0x20000000,
        NOFLSH = 0x80000000,
    }
end

local stdin = 0

local old_attributes

function terminal.Initialize()
	io.stdin:setvbuf("no")
	io.stdout:setvbuf("no")

    if not old_attributes then
        old_attributes = ffi.new("struct termios[1]")
        ffi.C.tcgetattr(stdin, old_attributes)
    end

    local attr = ffi.new("struct termios[1]")
    if ffi.C.tcgetattr(stdin, attr) ~= 0 then error(ffi.strerror(), 2) end
	attr[0].c_lflag = bit.band(tonumber(attr[0].c_lflag), bit.bnot(bit.bor(flags.ICANON, flags.ECHO, flags.ISIG, flags.ECHOE, flags.ECHOCTL, flags.ECHOKE, flags.ECHOK)))
    attr[0].c_cc[VMIN] = 0
    attr[0].c_cc[VTIME] = 0
    if ffi.C.tcsetattr(stdin, TCSANOW, attr) ~= 0 then error(ffi.strerror(), 2) end

    if ffi.C.tcgetattr(stdin, attr) ~= 0 then error(ffi.strerror(), 2) end
    if attr[0].c_cc[VMIN] ~= 0 or attr[0].c_cc[VTIME] ~= 0 then terminal.Shutdown() error("unable to make stdin non blocking", 2) end

	terminal.EnableCaret(true)
end

function terminal.Shutdown()
    if old_attributes then
        ffi.C.tcsetattr(stdin, TCSANOW, old_attributes)
        old_attributes = nil
    end
end

function terminal.EnableCaret(b)

end

function terminal.Clear()
	os.execute("clear")
end

do
    local buff = ffi.new("char[512]")
    local buff_size = ffi.sizeof(buff)
    function terminal.Read() do return io.read() end
        local len = ffi.C.read(stdin, buff, buff_size)
        if len > 0 then
            return ffi.string(buff, len)
        end
    end
end

function terminal.Write(str)
	if terminal.writing then return end
	terminal.writing = true
	terminal.WriteNow(str)
	terminal.writing = false
end

function terminal.WriteNow(str)
	ffi.C.fwrite(str, 1, #str, io.stdout)
end

function terminal.SetTitle(str)
    --terminal.Write("\27[s\27[0;0f" .. str .. "\27[u")
    io.write(str, "\n")
end

function terminal.SetCaretPosition(x, y)
    x = math.max(math.floor(x), 0)
    y = math.max(math.floor(y), 0)
    terminal.Write("\27[" .. y .. ";" .. x .. "f")
end

local function process_input(str)
    if str == "" or str == "\n" or str == "\r" then
        table.insert(terminal.event_buffer, {"enter"})
    elseif str:byte() >= 32 and str:byte() < 127 then
        table.insert(terminal.event_buffer, {"string", str})
    elseif str:sub(1,2) == "\27[" then
        local seq = str:sub(3, str:len())

        if seq == "3~" then
            table.insert(terminal.event_buffer, {"delete"})
        elseif seq == "3;5~" then
            table.insert(terminal.event_buffer, {"ctrl_delete"})
        elseif seq == "D" then
            table.insert(terminal.event_buffer, {"left"})
        elseif seq == "C" then
            table.insert(terminal.event_buffer, {"right"})
        elseif seq == "A" then
            table.insert(terminal.event_buffer, {"up"})
        elseif seq == "B" then
            table.insert(terminal.event_buffer, {"down"})
        elseif seq == "H" or seq == "1~" then
            table.insert(terminal.event_buffer, {"home"})
        elseif seq == "F" or seq == "4~" then
            table.insert(terminal.event_buffer, {"end"})
        elseif seq == "1;5C" then
            table.insert(terminal.event_buffer, {"ctrl_right"})
        elseif seq == "1;5D" then
            table.insert(terminal.event_buffer, {"ctrl_left"})
        else
            --print("ansi escape sequence: " .. seq)
        end
    elseif str:sub(1,1) == "\27" then
        local seq = str:sub(2, str:len())
        if seq == "b" then
            table.insert(terminal.event_buffer, {"ctrl_left"})
        elseif seq == "f" then
            table.insert(terminal.event_buffer, {"ctrl_right"})
        elseif seq == "D" then
            table.insert(terminal.event_buffer, {"ctrl_delete"})
        end
    else
        -- in a tmux session over ssh
        if str == "\127\127" then
            str = "\127"
        end

        if #str == 1 then
            local byte = str:byte()
            if byte == 3 then -- ctrl c
                table.insert(terminal.event_buffer, {"ctrl_c"})
            elseif byte == 127 then -- backspace
                table.insert(terminal.event_buffer, {"backspace"})
            elseif byte == 23 or byte == 8 then -- ctrl backspace
                table.insert(terminal.event_buffer, {"ctrl_backspace"})
            elseif byte == 22 then
                table.insert(terminal.event_buffer, {"ctrl_v"})
            elseif byte == 1 then
                table.insert(terminal.event_buffer, {"home"})
            elseif byte == 5 then
                table.insert(terminal.event_buffer, {"end"})
            elseif byte == 21 then
                table.insert(terminal.event_buffer, {"cmd_backspace"})
            else
                --print("byte: " .. byte)
            end
        elseif str:byte() < 127 then
            if str == "\27\68" then -- ctrl delete
                table.insert(terminal.event_buffer, {"ctrl_delete"})
            else
                for _, char in ipairs(str:utotable()) do
                    process_input(char)
                end
                --print("char sequence: " .. table.concat({str:byte(1, str:ulen())}, ", ") .. " (" .. str:ulen() .. ")")
            end
        else -- unicode ?
            table.insert(terminal.event_buffer, {"string", str})
        end
    end
end

local function read_coordinates()
    while true do

		local str = terminal.Read()

		if str then
            local a,b = str:match("^\27%[(%d+);(%d+)R$")
            if a then
                return tonumber(a), tonumber(b)
            else
                process_input(str)
            end
            return
        end
    end
end

do
    local _x, _y = 0, 0

    function terminal.GetCaretPosition()
		terminal.WriteNow("\x1b[6n")

        local y,x = read_coordinates()

        if y then
            _x, _y = x, y
        end

        return _x, _y
    end
end

do
    local _w, _h = 0, 0

    function terminal.GetSize()
        terminal.WriteNow("\27[s\27[999;999f\x1b[6n\27[u")

        local h,w = read_coordinates()

        if h then
            _w, _h = w, h
        end

        return _w,_h
    end
end

function terminal.WriteStringToScreen(x, y, str)
	terminal.Write("\27[s\27[" .. y .. ";" .. x .. "f" .. str .. "\27[u")
end

function terminal.ForegroundColor(r,g,b)
    r = math.floor(r * 255)
    g = math.floor(g * 255)
    b = math.floor(b * 255)
    terminal.Write("\27[38;2;" .. r .. ";" .. g .. ";" .. b .. "m")
end

function terminal.ForegroundColorFast(r,g,b)
    terminal.Write(string.format("\27[38;2;%i;%i;%im",r,g,b))
end

function terminal.BackgroundColor(r,g,b)
    r = math.floor(r * 255)
    g = math.floor(g * 255)
    b = math.floor(b * 255)
    terminal.Write("\27[48;2;" .. r .. ";" .. g .. ";" .. b .. "m")
end

function terminal.ResetColor()
    terminal.Write("\27[0m")
end

terminal.event_buffer = {}

function terminal.ReadEvents()
    local str = terminal.Read()

    if str then
        process_input(str)
	end


    return terminal.event_buffer
end

return terminal