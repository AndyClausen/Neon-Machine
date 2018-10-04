local socket = require("socket")
local floor=math.floor
local ceil=math.ceil
function round(num) 
	if num >= 0 then return floor(num+.5) 
	else return ceil(num-.5) end
end
local win = {
	[ "width" ] = 320;
	[ "height" ] = 240;
	[ "scale" ] = 4;
}
local MAKE_TRUE_SIZE = 4
local MAX_RAM = 16384
local USED_RAM = 0 
local MAX_STORAGE = 131072
local USED_STORAGE = 0
local CPU_SPEED = 1

local LOADED_PRGS = {}
local gfx = {}
local gfxSize = (win.width*win.height)-1
local currKeyPressed = ""
local currKeyReleased = ""
local progs = {}
G_ENV = {
	[ "gfx" ] = {};
	[ "network" ] = {
		[ "isConnected" ] = function()
			local test = socket.tcp()
			test:settimeout(1000)
			local testResult = test:connect("www.google.com", 80)
			test:close()
			test = nil
			if not(testResult == nil) then
				return true
			else
				return false
			end
		end;
	};
	[ "fs" ] = {
		[ "mkdir" ] = function( path )
			love.filesystem.mkdir( "root/"..path )
		end;
		[ "exists" ] = function( path )
			if love.filesystem.getInfo( "root/"..path ) == nil then
				return false
			else
				return true
			end
		end;
		[ "getInfo" ] = function( path )
			return love.filesystem.getInfo( "root/"..path )
		end;
		[ "list" ] = function( path )
			return love.filesystem.enumerate( "root/"..path )
		end;
		[ "open" ] = function( path, rt )
			return love.filesystem.newFile( "root/"..path, rt )
		end;
		[ "read" ] = function( path )
			return love.filesystem.read( "root/"..path )
		end;
		[ "write" ] = function( path )
			return love.filesystem.write( "root/"..path )
		end;
	};
	[ "program" ] = {
		[ "load" ] = function( path, loadedBy )
			local tbl, err = love.filesystem.getInfo( "root/"..path )
			local size = 0
			if tbl then
				if tbl.size >= MAKE_TRUE_SIZE then
					size = math.floor(tbl.size/MAKE_TRUE_SIZE)
				end
			else
				return false, "No such program '"..path.."'"
			end
			USED_RAM = USED_RAM + size
			if USED_RAM > MAX_RAM then
				USED_RAM = USED_RAM - size
				return false, "Max RAM Exceeded!"
			else
				LOADED_PRGS[ path ] = {
					[ "size" ] = size;
					[ "func" ] = love.filesystem.load( "root/"..path );
					[ "loadedBy" ] = loadedBy;
					[ "sandbox" ] = {};
				}
				return true
			end
		end;
		[ "unload" ] = function( path )
			if LOADED_PRGS[ path ] then
				USED_RAM = USED_RAM - LOADED_PRGS[ path ].size
				for k, v in pairs( LOADED_PRGS ) do
					if v.loadedBy == path then
						USED_RAM = USED_RAM - v.size
						LOADED_PRGS[ k ] = nil
					end
				end
				LOADED_PRGS[ path ] = nil
				return true
			else
				return false, "Program not loaded!"
			end
		end;
		[ "setfenv" ] = function( path, env )
			if LOADED_PRGS[ path ] then
				LOADED_PRGS[ path ].sandbox = env
				return true
			else
				return false, "Program not loaded!"
			end
		end;
		[ "start" ] = function( path, ... )
			if LOADED_PRGS[ path ] then
				setmetatable( LOADED_PRGS[ path ].sandbox, {} )
				for k, v in pairs( G_ENV ) do
					LOADED_PRGS[ path ].sandbox[ k ] = v
				end
				setfenv( LOADED_PRGS[ path ].func, LOADED_PRGS[ path ].sandbox )
				local ok, err = pcall( LOADED_PRGS[ path ].func, ... )
				return ok, err
			else
				return false, "Program not loaded!"
			end
		end;
		[ "update" ] = function( path, dt )
			if LOADED_PRGS[ path ] then
				local env = getfenv( LOADED_PRGS[ path ].func )
				if env.update then
					env.update( dt )
				end
			end
		end;
	};
	[ "sys" ] = {
		[ "setScreenMode" ] = function( mode )
			if mode == "low" then
				win.scale = 2
			elseif mode == "high" then
				win.scale = 4
			else
				win.scale = 3
			end
			love.window.setMode(0, 0)
			screen_xoff = love.graphics.getWidth()/2-(win.width*win.scale/2)
			screen_yoff = love.graphics.getHeight()/2-(win.height*win.scale/2)
			success = love.window.setMode( round(love.graphics.getWidth()/win.scale), round(love.graphics.getHeight()/win.scale), {
				[ "vsync" ] = false;
				[ "stencil" ] = false;
				[ "borderless" ] = true;
				[ "fullscreen" ] = true;
			} )
			love.graphics.setPointSize( win.scale )
		end;
		[ "getRamSize" ] = function()
			return MAX_RAM
		end;
		[ "getRamUsed" ] = function()
			return USED_RAM
		end;
		[ "getStorageSize" ] = function()
			return MAX_STORAGE
		end;
		[ "getStorageUsed" ] = function()
			return USED_STORAGE
		end;
		[ "getCPUSpeed" ] = function()
			return CPU_SPEED
		end;
		[ "keyboardTyped" ] = "";
		[ "isKeyDown" ] = love.keyboard.isDown;
		[ "getMousePos" ] = function()
			return math.floor(love.mouse.getX() / win.scale), math.floor(love.mouse.getY() / win.scale)
		end;
		[ "mouseIsDown" ] = love.mouse.isDown;
		[ "keyPressed" ] = function( key )
			if currKeyPressed == key then
				currKeyPressed = ""
				return true
			end
			return false
		end;
		[ "keyReleased" ] = function( key )
			if currKeyReleased == key then
				currKeyReleased = ""
				return true
			end
			return false
		end;
	}
}

function love.textinput( t )
	G_ENV.sys.keyboardTyped = G_ENV.sys.keyboardTyped .. t
end

function love.keypressed(key)
	currKeyPressed = key
end

function love.keyreleased(key)
	currKeyPressed = ""
	currKeyReleased = key
end

G_ENV.gfx.clear = function( rgb )
	local rgb = rgb or { 0x0, 0x0, 0x0 }
	for i=0, gfxSize do
		gfx[ i ] = rgb
	end
end
math.round=round
G_ENV.gfx.putPixel = function( x, y, rgb )
	x=round(x)
	y=round(y)
	if x >= 0 and x < win.width and y>=0 and y<win.height then
		gfx[ y*win.width + x ] = rgb or { 0xF, 0xF, 0xF }
	end
end
G_ENV.gfx.getPixel = function( x, y )
	x=round(x)
	y=round(y)
	if x >= 0 and x < win.width and y>=0 and y<win.height then
		local index = y*win.width + x
		return { gfx[ index ][ 1 ], gfx[ index ][ 2 ], gfx[ index ][ 3 ] }
	end
end

function love.load()
	love.filesystem.setIdentity( "LuaOS", false )
	love.window.setMode(0, 0)
	screen_xoff = love.graphics.getWidth()/2-(win.width*win.scale/2)
	screen_yoff = love.graphics.getHeight()/2-(win.height*win.scale/2)
	success = love.window.setMode( round(love.graphics.getWidth()/win.scale), round(love.graphics.getHeight()/win.scale), {
		[ "vsync" ] = false;
		[ "stencil" ] = false;
		[ "borderless" ] = true;
		[ "fullscreen" ] = true;
	} )
	love.graphics.setPointSize( win.scale )
	if( success ) then
		local rgb = { 0x0, 0x0, 0x0 }
		for i=0, gfxSize do
			gfx[ i ] = rgb
		end
		local ok, err = love.filesystem.load( "kernel/boot.lua" )
		USED_RAM = USED_RAM + math.floor(love.filesystem.getInfo( "kernel/boot.lua" ).size/MAKE_TRUE_SIZE)
		if not ok then error( err ) else
			setmetatable( G_ENV, {} )
			for k, v in pairs( _G ) do
				if k ~= "love" and k ~= "G_ENV" then
					G_ENV[ k ] = v
				end
			end
			G_ENV.__NAME = "boot"
			setfenv( ok, G_ENV )
			ok, err = pcall( ok )
			if not ok then error( err ) end
		end
		love.mouse.setVisible( false )
	end
end

local mydt = 0
local counter = 0
function love.update(dt)
	mydt = mydt + dt
	if G_ENV.update then
		local ok, err = pcall(G_ENV.update, dt)
		if not ok then error( err ) end
	end
	if counter >= 60 then
		CPU_SPEED = mydt
		mydt = 0
		counter = 0
	end
	counter = counter + 1
end

local setColor = love.graphics.setColor
local point = love.graphics.points
local floor = math.floor
function love.draw()
	if screen_xoff and screen_yoff then
		for i=0, gfxSize do
			local curr = gfx[ i ]
			if (curr[ 1 ] + curr[ 2 ] + curr[ 3 ]) > 0 then
				setColor( (curr[ 1 ]*17)/255, (curr[ 2 ]*17)/255, (curr[ 3 ]*17)/255 )
				point( screen_xoff+(i%win.width)*win.scale, screen_yoff+floor(i/win.width)*win.scale )
			end
		end
	end
end