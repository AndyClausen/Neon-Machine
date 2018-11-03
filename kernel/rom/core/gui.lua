local setmetatable, table, assert, pairs = setmetatable, table, assert, pairs

require("kernel.rom.core.libs.tree")
local Tree = tree.Tree

---@module gui
module("gui")

---@class GUI
---@field List table
---@field width number
---@field height number
---@field hitboxes Tree
GUI = {
    List = {}, -- list of instances
}
GUI_mt = {}

---new
---@param _width number
---@param _height number
---@return GUI
function GUI.new(_width, _height)
    local o = setmetatable({
        width = _width or 200,
        height = _height or 150,
        hitboxes = Tree.new(2),
    }, GUI_mt)
    table.insert(GUI.List, o)
    return o
end

---addHitbox
---@param _id string
---@param _onClick function
---@param _x number
---@param _y number
---@param _width number
---@param _height number
---@param _zIndex number
---@return Hitbox
function GUI:addHitbox(_id, _onClick, _onHover, _x, _y, _width, _height, _zIndex)
    assert(_id, "Hitboxes need an id")

    ---@class Hitbox
    ---@field id string
    ---@field onClick function
    ---@field onHover function
    ---@field x number
    ---@field y number
    ---@field z number
    ---@field width number
    ---@field height number
    local o = { -- Prototype/template
        id = _id,
        onClick = _onClick or function() end,
        onHover = _onHover or function() end,
        x = _x or 0,
        y = _y or 0,
        z = _zIndex or 1,
        width = _width or 1,
        height = _height or 1,
    }

    self.hitboxes:insert(o)
    return o
end

---removeHitbox
---@param _id string
---@return Hitbox
function GUI:removeHitbox(_id)
    return self.hitboxes:removeLeaf(_id)
end

---getHitboxAtPoint
---@param x number
---@param y number
---@return Hitbox
function GUI:getHitboxAtPoint(x, y)
    ---@type table
    local res = self.hitboxes:find(x, y)
    ---@type Hitbox
    local b
    ---@param v Hitbox
    for k,v in pairs(res) do
        if v.z and (not b or v.z > b.z) then
            b = v
        end
    end
    return b
end

GUI_mt.__index = GUI
