_G.IMPORTS = _G.IMPORTS or {}
IMPORTS["examples/projects/love2d/game/love_api.nlua"] = function()
	return love
end
IMPORTS["examples/projects/love2d/game/maze.nlua"] = function()
	local Maze = {}
	Maze.__index = Maze

	function Maze:__tostring()
		local out = {}
		table.insert(out, "Maze " .. self.width .. "x" .. self.height .. "\n")

		for y = 0, self.height - 1 do
			for x = 0, self.width - 1 do
				if self:Get(x, y) == 0 then
					table.insert(out, " ")
				else
					table.insert(out, "█")
				end
			end

			table.insert(out, "\n")
		end

		return table.concat(out)
	end

	function Maze:Get(x, y)
		return self.grid[y * self.width + x]
	end

	function Maze:Set(x, y, v)
		self.grid[y * self.width + x] = v
	end

	function Maze:Build(seed)
		math.randomseed(seed)

		local function build(x, y)
			local r = math.random(0, 3)
			self:Set(x, y, 0)

			for i = 0, 3 do
				local d = (i + r) % 4
				local dx = 0
				local dy = 0

				if d == 0 then
					dx = 1
				elseif d == 1 then
					dx = -1
				elseif d == 2 then
					dy = 1
				else
					dy = -1
				end

				local nx = x + dx
				local ny = y + dy
				local nx2 = nx + dx
				local ny2 = ny + dy

				if self:Get(nx, ny) == 1 then
					if self:Get(nx2, ny2) == 1 then
						self:Set(nx, ny, 0)
						build(nx2, ny2)
					end
				end
			end
		end

		build(2, 2)
		self.grid[self.width + 2] = 0
		self.grid[(self.height - 2) * self.width + self.width - 3] = 0
	end

	local function constructor(_, width, height)
		local self = setmetatable({width = width, height = height, grid = {}}, Maze)

		for y = 0, height - 1 do
			for x = 0, width - 1 do
				self.grid[y * width + x] = 1
			end

			self.grid[y * width + 0] = 0
			self.grid[y * width + width - 1] = 0
		end

		for x = 0, width - 1 do
			self.grid[0 * width + x] = 0
			self.grid[(height - 1) * width + x] = 0
		end

		return self
	end

	setmetatable(Maze, {__call = constructor})
	return Maze
end
local Maze = IMPORTS["examples/projects/love2d/game/maze.nlua"]("./maze.nlua")
local maze_width = 13
local maze_height = 13
local cell_size = 30
local grid = {}

do
	local maze = Maze(maze_width, maze_height)
	maze:Build(3)
	local neighbours = {{-1, 0}, {0, -1}, {1, 0}, {0, 1}}

	local function get_neighbours(x, y)
		local tbl = {}

		for _, xy in ipairs(neighbours) do
			local x = xy[1] + x
			local y = xy[2] + y
			local found = grid[y] and grid[y][x]

			if found then table.insert(tbl, found) end
		end

		return tbl
	end

	local function normalize_vector(x, y)
		local length = math.sqrt(x * x + y * y)

		if length == 0 then return 0, 0 end

		return x / length, y / length
	end

	local stop

	for y = 1, maze.height do
		grid[y] = grid[y] or {}

		for x = 1, maze.width do
			local state = {
				x = x,
				y = y,
				wall = maze:Get(x - 1, y - 1) == 1,
			}

			if x == maze.width and y == maze.height - 2 then
				stop = state
				stop.goal = true
			end

			grid[y][x] = state
		end
	end

	stop.distance = 0
	local to_visit = {stop}

	for _, node in ipairs(to_visit) do
		if node.wall then
			node.distance = 100
			node.visited = true
		else
			if node.distance then
				local neighbours = get_neighbours(node.x, node.y)

				for _, n in ipairs(neighbours) do
					if not n.visited and not n.wall then
						n.visited = true
						n.distance = node.distance + 1
						table.insert(to_visit, n)
					end
				end
			end
		end
	end

	for y = 1, #grid do
		for x = 1, #grid[y] do
			local center = grid[y][x]

			if not center.wall then
				local neighbours = get_neighbours(center.x, center.y)
				local x = 0
				local y = 0

				for _, n in ipairs(neighbours) do
					if n.distance and center.distance then
						local xx, yy = n.x - center.x, n.y - center.y
						local dist = center.distance - n.distance
						x = x + xx * dist
						y = y + yy * dist
					end
				end

				local xx, yy = normalize_vector(x, y)
				center.direction = {
					x = xx,
					y = yy,
				}
			end
		end
	end
end

function love.load()
	love.window.setMode(1500, 1500, {resizable = true, vsync = true, minwidth = 400, minheight = 300})
end

local function draw_arrow(x1, y1, x2, y2, arrlen, angle)
	love.graphics.line(x1, y1, x2, y2)
	local a = math.atan2(y1 - y2, x1 - x2)
	love.graphics.line(x2, y2, x2 + arrlen * math.cos(a + angle), y2 + arrlen * math.sin(a + angle))
	love.graphics.line(x2, y2, x2 + arrlen * math.cos(a - angle), y2 + arrlen * math.sin(a - angle))
end

function love.draw()
	for y = 1, #grid do
		for x = 1, #grid[y] do
			local state = grid[y][x]

			if state.wall then
				love.graphics.setColor(1, 1, 1)
			elseif state.goal then
				love.graphics.setColor(0, 1, 0)
			else
				love.graphics.setColor(0.1, 0, 0, state.distance and 10 / state.distance or 1)
			end

			local px = (x - 1) * cell_size
			local py = (y - 1) * cell_size
			love.graphics.rectangle("fill", px, py, cell_size, cell_size)
			love.graphics.setColor(0.5, 0.5, 0.5)
		end
	end

	for y = 1, #grid do
		for x = 1, #grid[y] do
			local state = grid[y][x]
			local px = (x - 1) * cell_size
			local py = (y - 1) * cell_size

			if state.direction then
				local s = cell_size / 2
				local dx = state.direction.x
				local dy = state.direction.y
				love.graphics.setColor(0.5, 0.5, 0.5, 1)
				draw_arrow(
					px + s - dx * s,
					py + s - dy * s,
					px + s + dx * s,
					py + s + dy * s,
					cell_size / 8,
					math.pi / 4
				)
			end
		end
	end
end
