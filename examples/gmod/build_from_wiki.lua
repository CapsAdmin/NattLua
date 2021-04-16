
local base_env = require("nattlua.runtime.base_environment")
local json = require("vscode.server.json")
local tprint = require("nattlua.other.table_print")
local util = require("examples.util")

local blob = assert(util.FetchCode("examples/gmod/gmod_wiki.json", "https://github.com/WilliamVenner/vscode-glua-enhanced/blob/master/resources/wiki.json?raw=true"))
local wiki_json = json.decode(blob)

-- i prefix all types with I to avoid conflicts when defining functions like Entity(entindex) in the typesystem
local TypeMap = {}

TypeMap["Color"] = "IColor"
TypeMap["VMatrix"] = "IMatrix"
TypeMap["Vector"] = "IVector"
TypeMap["Angle"] = "IAngle"


-- aren't these two the same from lua's point of view?
TypeMap["Entity"] = "IEntity"
TypeMap["CSEnt"] = "IEntity"

TypeMap["Player"] = "IPlayer"
TypeMap["Vehicle"] = "IVehicle"
TypeMap["NPC"] = "INPC"
TypeMap["Weapon"] = "IWeapon"
TypeMap["Panel"] = "IPanel"

-- unconventional
TypeMap["bf_read"] = "IBfRead"
TypeMap["pixelvis handle t"] = "IPixVis"
TypeMap["sensor"] = "ISensor"

-- what's the difference?
TypeMap["File"] = "IFile"
TypeMap["file_class"] = "IFile"

TypeMap["IVideoWriter"] = "IVideoWriter"
TypeMap["IMaterial"] = "IMaterial"
TypeMap["CMoveData"] = "IMoveData"
TypeMap["PhysObj"] = "IPhysObj"
TypeMap["MarkupObject"] = "IMarkupObject"
TypeMap["ITexture"] = "ITexture"
TypeMap["IMesh"] = "IMesh"
TypeMap["CEffectData"] = "IEffectData"
TypeMap["CUserCmd"] = "IUserCmd"
TypeMap["IRestore"] = "IRestore"
TypeMap["CNavArea"] = "INavArea"
TypeMap["Stack"] = "IStack"
TypeMap["CNavLadder"] = "INavLadder"
TypeMap["Task"] = "ITask"
TypeMap["CTakeDamageInfo"] = "ITakeDamageInfo"
TypeMap["ISave"] = "ISave"
TypeMap["Tool"] = "ITool"
TypeMap["SurfaceInfo"] = "ISurfaceInfo"
TypeMap["Schedule"] = "ISchedule"
TypeMap["ProjectedTexture"] = "IProjectedTexture"
TypeMap["PhysCollide"] = "IPhysCollide"
TypeMap["PathFollower"] = "IPathFollower"
TypeMap["NextBot"] = "INextBot"
TypeMap["IGModAudioChannel"] = "IGModAudioChannel"
TypeMap["CNewParticleEffect"] = "INewParticleEffect"
TypeMap["ConVar"] = "IConVar"
TypeMap["CSoundPatch"] = "ISoundPatch"
TypeMap["CRecipientFilter"] = "IRecipientFilter"
TypeMap["CLuaParticle"] = "ILuaParticle"
TypeMap["CLuaLocomotion"] = "ILuaLocomotion"
TypeMap["CLuaEmitter"] = "ILuaEmitter"

local code = {}
local i = 1
local e = function(str) code[i] = str i = i + 1 end
local t = 0
local function indent()
    e(string.rep("\t", t))
end

local function sort(a, b)
    return a.key > b.key
end

local function to_list(map)
    local list = {}

    for k, v in pairs(map) do
        table.insert(list, {key = k, val = v})
    end

    table.sort(list, sort)

    return list
end

local function spairs(map)
    local list = to_list(map)
    local i = 0
    return function() 
        i = i + 1

        if not list[i] then return end

        return list[i].key, list[i].val
    end
end

local function Class(name)
    if TypeMap[name] then
        return TypeMap[name]
    end
    return name
end

local function emit_atomic_type(val)

    if val.NAME then
        e(val.NAME:gsub("[%p%s]", "_") .. ": ") 
    end

    if val.TYPE:find("|", nil, true) then
        local values = {}
        (val.TYPE .. "|"):gsub("([^|]-)|", function(val) 
            table.insert(values, val)
        end)
        for i, val in ipairs(values) do
            emit_atomic_type({TYPE = val})
            if i ~= #values then
                e(" | ")
            end
        end
        return
    end

    if false then 
    
    elseif val.TYPE == "function" then e("(function(...any): any)")
    elseif val.TYPE == "table" then e("{[any] = any}")
    elseif val.TYPE == "userdata" then e("{[any] = any}")
    elseif val.TYPE == "vararg" then e("...any")        
    elseif val.TYPE == "bool" then e("boolean") -- ?

    -- don't do anything special with these since they are already defined
    elseif val.TYPE == "number" then e(val.TYPE)
    elseif val.TYPE == "boolean" then e(val.TYPE)
    elseif val.TYPE == "string" then e(val.TYPE)
    elseif val.TYPE == "any" then e(val.TYPE)
    elseif val.TYPE == "nil" then e(val.TYPE)
    
    elseif TypeMap[val.TYPE] then e(TypeMap[val.TYPE])

    else
        tprint(val)
        error("NYI")
    end
end

local function emit(key, val, self_argument)
    if val.MEMBERS then
        e("{\n")
        for key, val in pairs(val.MEMBERS) do
            t = t + 1
            indent() e(key) e(" = ") emit(key, val, self_argument) e(",\n")
            t = t - 1
        end
        e("}\n")
    elseif val.FUNCTION then
        --e("function(...any): any")
        e("(")
        e("function(")

        if not val.ARGUMENTS and self_argument then
            val.ARGUMENTS = {}
        end

        if val.ARGUMENTS then
            local list = val.ARGUMENTS

            if self_argument then
                table.insert(list, 1, {
                    TYPE = self_argument,
                })
            end

            for i, val in ipairs(list) do
                emit_atomic_type(val)
                if i ~= #list then
                    e(", ")
                end
            end
        end
        e("): ")
        if val.RETURNS then
            local list = val.RETURNS
            for i, val in ipairs(list) do
                emit_atomic_type(val)
                if i ~= #list then
                    e(", ")
                end
            end
        else
            e("nil")
        end
        e(")")
    elseif val.LINK == "utf8.charpattern" then
        e('"[%z\x01-\x7F\xC2-\xF4][\x80-\xBF]*"')
    elseif val.LINK == "derma.Controls" then
        e('{ClassName = string, Description = string, BaseClass = string}')
    elseif val.LINK == "derma.SkinList" then
        e('{[number] = any}') -- numeric list?
    else
        for k,v in pairs(val) do
            print(k, "\t\t=\t\t", v)
        end
        error("NYI")
    end
end

for class_name in spairs(wiki_json.CLASSES) do
    class_name = Class(class_name)
    e("type ") e(class_name) e(" = {}\n")
end

local function binary_operator(a, b, r)
    return {
        binary_operator = true,
        CLIENT = true,
        SERVER = true,
        FUNCTION = true,
        ARGUMENTS = {
            {
                TYPE = a,
            },
            {
                TYPE = b,
            }
        },
        RETURNS = {
            {
                TYPE = r,
            }
        }
    }
end

for class_name, lib in spairs(wiki_json.CLASSES) do
    local original_name = class_name
    class_name = Class(class_name)

    e("do\n")
    t = t + 1

    indent() e("type ") e(class_name) e(".@MetaTable = ") e(class_name) e("\n")
    indent() e("type ") e(class_name) e(".@Name = \"") e(class_name) e("\"\n")
    indent() e("type ") e(class_name) e(".__index = ") e(class_name) e("\n")

    
    do -- these are not defined in the wiki json
        if class_name == "IVector" or class_name == "IAngle" then
            lib.MEMBERS.__add = binary_operator(original_name, original_name,  original_name)
            lib.MEMBERS.__sub = binary_operator(original_name, original_name, original_name)
            lib.MEMBERS.__mul = binary_operator(original_name, original_name, original_name)
            lib.MEMBERS.__div = binary_operator(original_name, original_name, original_name)
        end

        if class_name == "IVector" then
            indent() e("type ") e(class_name) e(".") e("x") e(" = ") e("number") e("\n")
            indent() e("type ") e(class_name) e(".") e("y") e(" = ") e("number") e("\n")
            indent() e("type ") e(class_name) e(".") e("z") e(" = ") e("number") e("\n")
        elseif class_name == "IAngle" then
            indent() e("type ") e(class_name) e(".") e("p") e(" = ") e("number") e("\n")
            indent() e("type ") e(class_name) e(".") e("y") e(" = ") e("number") e("\n")
            indent() e("type ") e(class_name) e(".") e("r") e(" = ") e("number") e("\n")
        end
        
        if class_name == "IMatrix" then
            lib.MEMBERS.__mul = binary_operator(original_name, original_name .. "|Vector", original_name)
            lib.MEMBERS.__sub = binary_operator(original_name, original_name, original_name)
            lib.MEMBERS.__add = binary_operator(original_name, original_name, original_name)
        end
    end

    for key, val in spairs(lib.MEMBERS) do
        indent() e("type ") e(class_name) e(".") e(key) e(" = ") emit(key, val, not val.binary_operator and original_name) e("\n")
    end

    indent() e("type ") e(class_name) e(".@Contract = ") e(class_name) e("\n")

    t = t - 1
    e("end\n")
end

for key, val in spairs(wiki_json.GLOBALS) do
    if not base_env:Get(key) then
        if key == "Matrix" then
            val.ARGUMENTS[1].TYPE = "table|nil"
        end

        e("type ") e(key) e(" = ") emit(key, val) e("\n")
    end
end

for lib_name, lib in spairs(wiki_json.LIBRARIES) do
    if not base_env:Get(lib_name) then
        e("type ") e(lib_name) e(" = ") emit(lib_name, lib)
    end
end

code = table.concat(code)

-- pixvis and "sensor is never defined on the wiki as a class
code = "type IPixVis = {}\ntype ISensor = {}\n" .. code .. "\n"

code = code .. [[
    local m = Matrix()
    type_assert<|m * Vector(1,1,0), IMatrix|>
    
    local ent = ents.GetByIndex(5)
    type_assert<|ent:GetPos().x, number|>
]]

local f = io.open("examples/gmod/glua.nlua", "w")
f:write(code)
f:close()

nl.Code(code):Analyze()