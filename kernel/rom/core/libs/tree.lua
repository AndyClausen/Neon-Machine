local setmetatable, table, pairs, error = setmetatable, table, pairs, error

---@module tree
module("tree")

-- Classes (and their metatables)
---@class Tree
---@field maxLeaves number
---@field leaves table
---@field root Space
Tree = {}
Tree_mt = {}
---@class Space
Space = {}
Space_mt = {}
---@class Leaf
Leaf = {}
Leaf_mt = {}


-- Local functions
---getPropertiesFromLevel
---@param o Space | Leaf
---@param level number
---@return number, number
local function getPropertiesFromLevel(o, level) -- Only usable by spaces and leaves
    if (level%2 == 1) then
        return o.x, o.width
    else
        return o.y, o.height
    end
end

---intersects
---@param x1 number
---@param l1 number
---@param x2 number
---@param l2 number
---@return boolean
function intersects(x1, l1, x2, l2) -- A one-dimensional intersection checker
    if l1 == 0 then l1 = nil end
    return (x1 >= x2 and x1 <= x2+l2) or (l1 and x1+l1 <= x2 and x1+l1 <= x2+l2)
end


-- Class constructors and methods
---new
---@param _maxLeaves number
---@param _leaves number
---@return Tree
function Tree.new(_maxLeaves, _leaves)
    local o = {
        maxLeaves = _maxLeaves or 3,
        leaves = _leaves or {},
    }
    setmetatable(o, Tree_mt)
    return o
end

---insert
---@param leaf Leaf
---@param parent Space
function Tree:insert(leaf, parent)
    if not parent then -- First insertion (non-recursive)
        leaf = Leaf.new(leaf)
        if leaf.id then
            self.leaves[leaf.id] = leaf
        else
            table.insert(self.leaves, leaf)
        end
        if not self.root then -- Is the tree empty?
            self.root = Space.new({
                x = leaf.x,
                y = leaf.y,
                width = leaf.width,
                height = leaf.height,
            })
            table.insert(self.root.leaves, leaf)
            return
        end
        parent = self.root
    end

    -- Recursive stuff

    -- set space size
    if leaf.x < parent.x then
        parent.width = parent.width + (parent.x-leaf.x)
        parent.x = leaf.x
    end
    if leaf.y < parent.y then
        parent.height = parent.height + (parent.y-leaf.y)
        parent.y = leaf.y
    end
    if leaf.x+leaf.width > parent.x+parent.width then parent.width = leaf.width - (parent.x - leaf.x) end
    if leaf.y+leaf.height > parent.y+parent.height then parent.height = leaf.height - (parent.y - leaf.y) end

    if not parent.leaves then -- insert into child spaces
        local start, length = getPropertiesFromLevel(leaf, parent.level)
        local side = parent:compare(start, length) and "right" or "left"

        if not parent[side] then -- make side if it doesn't exist
            parent[side] = Space.new({
                x = leaf.x,
                y = leaf.y,
                width = leaf.width,
                height = leaf.height,
                level = parent.level+1
            })
        end
        -- add to side
        self:insert(leaf, parent[side])
    else -- insert into leaves
        table.insert(parent.leaves, leaf)

        if #parent.leaves > self.maxLeaves then
            local leaves = parent.leaves
            parent.leaves = nil
            for k,v in pairs(leaves) do
                self:insert(v, parent)
            end
        end
    end
end

---removeLeaf
---@param _id string
---@return Leaf the removed leaf
function Tree:removeLeaf(_id)
    local leaf = self.leaves[_id]
    if leaf then
        self.root:removeLeaf(leaf)
    end
    return leaf
end

function Tree:find(x, y)
    if not self.root then
        return {}
    end
    return self.root:find(x, y)
end

function Tree:findArea(x, width, y, height)

end

Tree_mt.__index = Tree


---new
---@param o table
---@return Space
function Space.new(o)
    local n = {
        x = 0,
        y = 0,
        width = 1,
        height = 1,
        level = 1,
        leaves = {},
    }
    for k,v in pairs(o) do
        n[k] = v
    end
    return setmetatable(n, Space_mt)
end

---compare
---@param p1 number
---@param p2 number
---@return boolean true if the middle of the given points is greater than or equal to the middle of the space
function Space:compare(p1, p2) -- Compare middles
    local start, length = getPropertiesFromLevel(self, self.level)
    return p1 + p2/2 >= start + length/2
end

---intersects
---@param x number
---@param width number
---@param y number
---@param height number
---@return boolean true if the given square (or point) intersects with the space
function Space:intersects(x, width, y, height) -- note that all params are optional
    return (not x or intersects(x, width, self.x, self.width)) and (not y or intersects(y, height, self.y, self.height))
end

function Space:contains(x, y)
    return intersects(x, 0, self.x, self.width) and intersects(y, 0, self.y, self.height)
end

function Space:find(x, y)
    local res = {}
    if self.leaves then
        ---@param v Leaf
        for k,v in pairs(self.leaves) do
            if v:contains(x, y) then
                table.insert(res, v)
            end
        end
    else
        if self.left and self.left:contains(x, y) then
            for k,v in pairs(self.left:find(x,y)) do
                table.insert(res, v)
            end
        end
        if self.right and self.right:contains(x, y) then
            for k,v in pairs(self.right:find(x,y)) do
                table.insert(res, v)
            end
        end
    end

    return res
end

---removeLeaf
---@param leaf Leaf
function Space:removeLeaf(leaf)
    if self.leaves then
        for k,v in pairs(self.leaves) do
            if v == leaf then
                table.remove(self.leaves, k)
            end
        end
    else
        if self.left and self.left:contains(leaf.x, leaf.y) then
            self.left.removeLeaf()
        end
        if self.right and self.right:contains(leaf.x, leaf.y) then
            self.right.removeLeaf()
        end
    end
end

Space_mt.__index = Space


---new
---@param o table
---@return Leaf
function Leaf.new(o)
    ---@type Leaf
    local n = {
        x = 0,
        y = 0,
        width = 1,
        height = 1,
    }
    for k,v in pairs(o) do
        n[k] = v
    end
    return setmetatable(n, Leaf_mt)
end

---contains
---@param x number
---@param y number
---@return Leaf
function Leaf:contains(x, y)
    return intersects(x, 0, self.x, self.width) and intersects(y, 0, self.y, self.height)
end

Leaf_mt.__index = Leaf
