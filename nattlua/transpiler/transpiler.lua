--[[#local type { Token } = import_type("nattlua/lexer/token.nlua")]]

local ipairs = ipairs
local assert = assert
local type = type
local META = {}
META.__index = META
--[[#
type META.@Self = {
    done = {[string] = true} | {},
    out = {[1 .. inf] = string} | {},
    i = 1 .. inf,
    last_indent_index = 1 .. inf,
    last_non_space_index = 1 .. inf,
    last_newline_index = 1 .. inf,
    inside_call_expression = boolean,
    pre_toggle_level = 0 .. inf,
    toggled_indents = {
        [string] = boolean,
    },
    tracking_indents = {
        [string] = {
            [1 .. inf] = {
                info = any,
                level = 1 .. inf
            }
        }
    },
    level = 0 .. inf,
    config = {}|{
        extra_indent = {
			[string] = "toggle"|{to=string},
		},
        preserve_whitespace = boolean | nil,
    }
}
]]
function META:Whitespace(str --[[#: string]], force --[[#: boolean | nil]])
    if self.config.preserve_whitespace == nil and not force then return end

    if str == "\t" then
        if self.config.no_newlines then
            self:Emit(" ")
        else
            self:Emit(("\t"):rep(self.level))
            self.last_indent_index = #self.out -- [[# as 1 .. inf]]
        end
    elseif str == "\t+" then
        self:Indent()
    elseif str == "\t-" then
        self:Outdent()
    elseif str == " " then
        self:Emit(" ")
    elseif str == "\n" then
        self:Emit(self.config.no_newlines and " " or "\n")
        self.last_newline_index = #self.out
    else
        error("unknown whitespace " .. ("%q"):format(str))
    end
end

function META:Emit(str --[[#: string]])
    if type(str) ~= "string" then
        error(debug.traceback("attempted to emit a non string " .. tostring(str)))
    end

    self.out[self.i] = str or ""
    self.i = self.i + 1
end

function META:EmitNonSpace(str --[[#: string]])
    self:Emit(str)
    self.last_non_space_index = #self.out --[[# as 1 .. inf]]
end

function META:EmitSpace(str --[[#: string]])
    self:Emit(str)
end

function META:Indent()
    self.level = self.level + 1
end

function META:Outdent()
    self.level = self.level - 1
end

function META:GetPrevChar()
    if self.i <= 1 then return 0 end
    local prev = self.out[self.i - 1]
    local char = prev and prev:sub(-1)
    return char and char:byte() or 0
end

function META:EmitWhitespace(token --[[#: Token]])
    if self.config.preserve_whitespace == false and token.type == "space" then return end
    self:EmitToken(token)

    if token.type ~= "space" then
        self:Whitespace("\n")
        self:Whitespace("\t")
    end
end

function META:EmitToken(token --[[#: Token]], translate --[[#: any]])
    if
        self.config.extra_indent and
        self.config.preserve_whitespace == false and
        self.inside_call_expression
    then
        self.tracking_indents = self.tracking_indents or {}

        if type(self.config.extra_indent[token.value]) == "table" then
            self:Indent()
            local info = self.config.extra_indent[token.value]

            if type(info.to) == "table" then
                for to in pairs(info.to) do
                    self.tracking_indents[to] = self.tracking_indents[to] or {}
                    table.insert(self.tracking_indents[to], {info = info, level = self.level})
                end
            else
                self.tracking_indents[info.to] = self.tracking_indents[info.to] or {}
                table.insert(self.tracking_indents[info.to], {info = info, level = self.level})
            end
        elseif self.tracking_indents[token.value] then
            for _, info in ipairs(self.tracking_indents[token.value]) do
                if info.level == self.level or info.level == self.pre_toggle_level then
                    self:Outdent()
                    local info = self.tracking_indents[token.value]

                    for key, val in pairs(self.tracking_indents) do
                        if info == val.info then
                            self.tracking_indents[key] = nil
                        end
                    end

                    if self.out[self.last_indent_index] then
                        self.out[self.last_indent_index] = self.out[self.last_indent_index]:sub(2)
                    end

                    if self.toggled_indents then
                        self:Outdent()
                        self.toggled_indents = {}

                        if self.out[self.last_indent_index] then
                            self.out[self.last_indent_index] = self.out[self.last_indent_index]:sub(2)
                        end
                    end

                    break
                end
            end
        end

        if self.config.extra_indent[token.value] == "toggle" then
            self.toggled_indents = self.toggled_indents or {}

            if not self.toggled_indents[token.value] then
                self.toggled_indents[token.value] = true
                self.pre_toggle_level = self.level
                self:Indent()
            elseif self.toggled_indents[token.value] then
                if self.out[self.last_indent_index] then
                    self.out[self.last_indent_index] = self.out[self.last_indent_index]:sub(2)
                end
            end
        end
    end

    if token.whitespace then
        if self.config.preserve_whitespace == false then
            local emit_all_whitespace = false

            for _, token in ipairs(token.whitespace) do
                if token.type == "line_comment" or token.type == "multiline_comment" then
                    emit_all_whitespace = true

                    break
                end
            end

            if emit_all_whitespace then
                -- wipe out all space emitted before this
                if self.last_non_space_index then
                    for i = self.last_non_space_index + 1, #self.out do
                        self.out[i] = ""
                    end
                end

                for _, token in ipairs(token.whitespace) do
                    self:EmitToken(token)
                end
            end
        else
            for _, token in ipairs(token.whitespace) do
                self:EmitWhitespace(token)
            end
        end 
    end

    if self.TranslateToken then
        translate = self:TranslateToken(token) or translate
    end

    if translate then
        if type(translate) == "table" then
            self:Emit(translate[token.value] or token.value)
        elseif type(translate) == "function" then
            self:Emit(translate(token.value))
        elseif translate ~= "" then
            self:Emit(translate)
        end
    else
        self:Emit(token.value)
    end

    if
        token.type ~= "line_comment" and
        token.type ~= "multiline_comment" and
        token.type ~= "space"
    then
        self.last_non_space_index = #self.out
    end
end

function META:Concat()
    return table.concat(self.out)
end

function META:BuildCode(block)
    if block.imports then
        self.done = {}
        self:Emit("IMPORTS = IMPORTS or {}\n")

        for i, node in ipairs(block.imports) do
            if not self.done[node.path] then
                self:Emit(
                    "IMPORTS['" .. node.path .. "'] = function(...) " .. node.root:Render({}) .. " end\n"
                )
                self.done[node.path] = true
            end
        end
    end

    self:EmitStatements(block.statements)
    return self:Concat()
end

function META:EmitStatements(node--[[#: any]])

end

function META:TranslateToken(tk)
    
end

function META.New()
    --[[# print(META.@Self) ]]
    local self = setmetatable({
        level = 0,
        out = {},
        i = 1,

        done = {},

        last_indent_index = 1,
        last_non_space_index = 1,
        last_newline_index = 1,

        config = {},
	}, META)

    return self
end