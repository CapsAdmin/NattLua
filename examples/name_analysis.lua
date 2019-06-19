local oh = require("oh.oh")
local util = require("oh.util")

local function levenshtein(a, b)
	local distance = {}

	for i = 0, #a do
	  distance[i] = {}
	  distance[i][0] = i
	end

	for i = 0, #b do
	  distance[0][i] = i
	end

	local str1 = util.UTF8ToTable(a)
	local str2 = util.UTF8ToTable(b)

	for i = 1, #a do
		for j = 1, #b do
			distance[i][j] = math.min(
				distance[i-1][j] + 1,
				distance[i][j-1] + 1,
				distance[i-1][j-1] + (str1[i-1] == str2[j-1] and 0 or 1)
			)
		end
	end

	return distance[#a][#b]
end


function check_tokens(tokens, name, code)
    local score = {}
    for i, tk in ipairs(tokens) do
        if tk.type == "letter" then
            score[tk.value] = score[tk.value] or {} 
            table.insert(score[tk.value], tk)
        end
    end
    local temp = {}
    for k,v in pairs(score) do
        table.insert(temp, {value = k, tokens = v})
    end
    
    table.sort(temp, function(a, b) return #a.tokens > #b.tokens end)

    for _, a in ipairs(temp) do
        for _, b in ipairs(temp) do
            local score = levenshtein(a.value, b.value)
            if score > 0 and score < 3 then
                print(a.value .. " ~ " .. b.value, score)
            end
        end
    end
end

local name = "oh/tokenizer.lua"
local code = io.open(name):read("*all")
local tokens, err = oh.CodeToTokens(code)

local time = os.clock()
check_tokens(tokens, name, code)
print(os.clock() - time)