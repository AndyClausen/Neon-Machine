local CREDITS = {
	"LeDark Lua a.k.a. Laurynas Šuopys",
	"Andreas \"Andy\" Clausen",
}

local socket = require("socket")
local floor=math.floor
local ceil=math.ceil
local twofivefive = 1/255
function round( num )
	if num >= 0 then return floor( num+.5 ) 
	else return ceil( num-.5 ) end
end
local canvas
local function map( n, start1, stop1, start2, stop2 )
	return (n - start1) / (stop1 - start1) * (stop2 - start2) + start2
end
math.map = map
local win = {
	[ "width" ] = 200;
	[ "height" ] = 150;
	[ "scale" ] = 4;
}
local blueCutoff = 0
local blueAmount = 5
local MAKE_TRUE_SIZE = 8
local MAX_RAM = 16384
local USED_RAM = 0
local MAX_STORAGE = 131072
local USED_STORAGE = 0
local CPU_SPEED = 1

local LOADED_PRGS = {}
local gfx = {}
local gfxSize = ( win.width * win.height )-1
local currKeyPressed = ""
local currKeyReleased = ""
local currMousePressed = 0
local currMouseReleased = 0
local progs = {}
local wins = win.scale
local winss = 1/win.scale
local mousegetX = love.mouse.getX
local mousegetY = love.mouse.getY
local lfgi = love.filesystem.getInfo
local lfgdi = love.filesystem.getDirectoryItems
local function determineSize( dir )
	local size = 0
	local files = lfgdi( dir )
	for i=1, #files do
		local info = lfgi( dir..files[ i ] )
		if info then
			if info.type == "directory" then
				size = size + determineSize( dir..files[ i ].."/" )
			elseif info.type == "file" then
				size = size + round( info.size/MAKE_TRUE_SIZE )
			end
		end
	end
	return size
end
local function reset()
	canvas = love.graphics.newCanvas( win.width, win.height, {
		[ "dpiscale" ] = love.graphics.getDPIScale();
		--[ "format" ] = "hdr";
	} )
	--canvasimageData = canvas:newImageData()
	canvas:setFilter( "nearest", "nearest" )
	love.graphics.setCanvas( canvas )
	for i=0, gfxSize do
		gfx[ i ] = {0,0,0}
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
		G_ENV.gfx.width = win.width
		G_ENV.gfx.height = win.height
		setfenv( ok, G_ENV )
		ok, err = pcall( ok )
		if not ok then error( err ) end
	end
	love.mouse.setVisible( false )
	if love.filesystem.getInfo( "root" ) == nil then
		love.filesystem.createDirectory( 'root' )
	end
	love.graphics.setCanvas()
end
local function sliceDirs( input )
	local cm = {}
	local word = ""
	local j = 0
	for i=1, #input do
		local c = input:sub( i, i )
		if c == "/" then
			cm[ #cm + 1 ] = word
			word = ""
			j = i+1
		else
			word = word .. c
		end
	end
	cm[ #cm + 1 ] = input:sub( j )
	return cm
end
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
	[ "credits" ] = function()
		return CREDITS
	end;
	[ "fs" ] = {
		[ "getName" ] = function( path )
			local lastIndex = 1
			for i=1, #path do
				local c=path:sub( i, i )
				if c == "/" then
					lastIndex = i+1
				end
			end
			return path:sub( lastIndex, #path )
		end;
		[ "mkdir" ] = function( path )
			if path:sub( 1, 1 ) == "/" then
				if #path > 2 then
					path = path:sub( 2 )
				else
					path = ""
				end
			end
			love.filesystem.createDirectory( "root/"..path )
		end;
		[ "exists" ] = function( path )
			local opath = "root/"
			if path:sub( 1, 1 ) == "/" then
				if #path > 2 then
					path = path:sub( 2 )
				else
					path = ""
				end
			end
			local original = sliceDirs( path )[ 1 ]
			if original == "rom" then
				opath = "kernel/"
			end
			if love.filesystem.getInfo( opath..path ) == nil then
				return false
			else
				return true
			end
		end;
		[ "getInfo" ] = function( path )
			local opath = "root/"
			if path:sub( 1, 1 ) == "/" then
				if #path > 2 then
					path = path:sub( 2 )
				else
					path = ""
				end
			end
			local original = sliceDirs( path )[ 1 ]
			if original == "rom" then
				opath = "kernel/"
			end
			local info = love.filesystem.getInfo( opath..path )
			if info then
				if info.type == "directory" then
					info.size = determineSize( opath..path.."/" )
				else
					if info.size then
						info.size = round( info.size / MAKE_TRUE_SIZE )
					end
				end
			end
			return info
		end;
		[ "list" ] = function( path )
			local opath = "root/"
			if path:sub( 1, 1 ) == "/" then
				if #path > 2 then
					path = path:sub( 2 )
				else
					path = ""
				end
			end
			local original = sliceDirs( path )[ 1 ]
			if original == "rom" then
				opath = "kernel/"
			end
			local files = love.filesystem.getDirectoryItems( opath..path )
			if path == "" then
				files[ #files + 1 ] = "rom"
			end
			return files
		end;
		[ "open" ] = function( path, rt )
			local opath = "root/"
			if path:sub( 1, 1 ) == "/" then
				if #path > 2 then
					path = path:sub( 2 )
				else
					path = ""
				end
			end
			if rt == 'r' then
				local original = sliceDirs( path )[ 1 ]
				if original == "rom" then
					opath = "kernel/"
				end
			end
			return love.filesystem.newFile( opath..path, rt )
		end;
		[ "read" ] = function( path )
			local opath = "root/"
			if path:sub( 1, 1 ) == "/" then
				if #path > 2 then
					path = path:sub( 2 )
				else
					path = ""
				end
			end
			local original = sliceDirs( path )[ 1 ]
			if original == "rom" then
				opath = "kernel/"
			end
			return love.filesystem.read( opath..path )
		end;
		[ "write" ] = function( path, value )
			if path:sub( 1, 1 ) == "/" then
				if #path > 2 then
					path = path:sub( 2 )
				else
					path = ""
				end
			end
			return love.filesystem.write( "root/"..path, value )
		end;
		[ "delete" ] = function( path )
			if path:sub( 1, 1 ) == "/" then
				if #path > 2 then
					path = path:sub( 2 )
				else
					path = ""
				end
			end
			love.filesystem.remove( "root/"..path )
		end;
	};
	[ "program" ] = {
		[ "load" ] = function( path, loadedBy )
			local opath = "root/"
			if path:sub( 1, 1 ) == "/" then
				if #path > 2 then
					path = path:sub( 2 )
				else
					path = ""
				end
			end
			local original = sliceDirs( path )[ 1 ]
			if original == "rom" then
				opath = "kernel/"
			end
			local tbl, err = love.filesystem.getInfo( opath..path )
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
					[ "func" ] = love.filesystem.load( opath..path );
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
				LOADED_PRGS[ path ].sandbox.__NAME = path
				local ok, err = pcall( LOADED_PRGS[ path ].func, ... )
				return ok, err
			else
				return false, "Program not loaded!"
			end
		end;
		[ "getSize" ] = function( path )
			if LOADED_PRGS[ path ] then
				return LOADED_PRGS[ path ].size
			end
		end;
		[ "getLoadedBy" ] = function( path )
			if LOADED_PRGS[ path ] then
				return LOADED_PRGS[ path ].loadedBy
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
		[ "filterBlue" ] = function( amount )
			if amount > 0 and amount <= 1 then
				blueCutoff = floor( blueAmount*amount )
			else
				blueCutoff = 0
			end
		end;
		[ "setScreenMode" ] = function( mode )
			if mode == "low" then
				if love.system.getOS() == "Android" then
					win.scale = 1
					wins = 1
					winss = 1
				else
					win.scale = 3
					wins = 3
					winss = 1/3
				end
			elseif mode == "high" then
				if love.system.getOS() == "Android" then
					win.scale = 3
					wins = 3
					winss = 1/3
				else
					win.scale = 5
					wins = 5
					winss = 1/5
				end
			else
				if love.system.getOS() == "Android" then
					win.scale = 2
					wins = 2
					winss = 1/2
				else
					win.scale = 4
					wins = 4
					winss = 1/4
				end
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
		[ "getUsedStorage" ] = function()
			return USED_STORAGE
		end;
		[ "getCPUSpeed" ] = function()
			return CPU_SPEED
		end;
		[ "textInput" ] = "";
		[ "isKeyDown" ] = love.keyboard.isDown;
		[ "getMousePos" ] = function()
			return floor(mousegetX() * winss), floor(mousegetY() * winss)
		end;
		[ "mouseIsDown" ] = love.mouse.isDown;
		[ "mousePressed" ] = function( key )
			if currMousePressed == key then
				currMousePressed = 0
				return true
			end
			return false
		end;
		[ "reset" ] = reset;
		[ "mouseReleased" ] = function( key )
			if currMouseReleased == key then
				currMouseReleased = 0
				return true
			end
			return false
		end;
		[ "keyPressed" ] = function( key )
			if currKeyPressed == key then
				return true
			end
			return false
		end;
		[ "keyReleased" ] = function( key )
			if currKeyReleased == key then
				return true
			end
			return false
		end;
		[ "setKeyRepeat" ] = love.keyboard.setKeyRepeat;
		[ "getKeyRepeat" ] = love.keyboard.hasKeyRepeat;
	}
}

function love.textinput( t )
	G_ENV.sys.textInput = G_ENV.sys.textInput .. t
end

function love.keypressed(key)
	currKeyPressed = key
end

function love.keyreleased(key)
	currKeyReleased = key
end

function love.mousepressed(_,_,key)
	currMousePressed = key
	currMouseReleased = 0
end

function love.mousereleased(_,_,key)
	currMouseReleased = key
	currMousePressed = 0
end

local setColor = love.graphics.setColor
local point = love.graphics.points
local clear = love.graphics.clear
local ccr = 0
local ccg = 0
local ccb = 0
local csr = 0
local csg = 0
local csb = 0
G_ENV.gfx.clear = function( rgb )
	local rgb = rgb or { 0x0, 0x0, 0x0 }
	for i=0, gfxSize do
		gfx[ i ] = rgb
	end
	if csr ~= rgb[1] then
		csr = rgb[1]
		ccr = (rgb[1]*17)*twofivefive
	end
	if csg ~= rgb[2] then
		csg = rgb[2]
		ccg = (rgb[2]*17)*twofivefive
	end
	if csb ~= rgb[3] then
		csb = rgb[3]
		ccb = (rgb[3]*17)*twofivefive
	end
	clear( ccr, ccg, ccb )
end
math.round=round
local winw = win.width
local winww = 1/win.width
local winsh = wins/2
local pcr = 0
local pcg = 0
local pcb = 0
local ppr = 0
local ppg = 0
local ppb = 0
G_ENV.gfx.putPixel = function( x, y, rgb )
	x=round(x)
	y=round(y)
	if x >= 0 and x < winw and y>=0 and y<win.height then
		rgb = rgb or { 0xF, 0xF, 0xF }
		if ppr ~= rgb[1] then
			ppr = rgb[1]
			pcr = (rgb[1]*17)*twofivefive
		end
		if ppg ~= rgb[2] then
			ppg = rgb[2]
			pcg = (rgb[2]*17)*twofivefive
		end
		if ppb ~= rgb[3] then
			ppb = rgb[3]
			pcb = (rgb[3]*17)*twofivefive
		end
		gfx[ y*winw+x ] = rgb
		setColor( pcr, pcg, pcb )
		point( 1+x, 1+y )
	end
end
local one17=1/17
G_ENV.gfx.getPixel = function( x, y )
	x=round(x)
	y=round(y)
	if x >= 0 and x < winw and y>=0 and y<win.height then
		return gfx[ y*winw+x ]
	end
end

function love.load()
	if love.system.getOS() == "Android" then
		love.keyboard.setTextInput( true )
		love.keyboard.setKeyRepeat( true )
		win.scale = 2
		wins = 2
		winss = 1/2
	end
	love.filesystem.setIdentity( "Neon Machine", false )
	love.window.setMode(0, 0)
	screen_xoff = love.graphics.getWidth()/2-(win.width*win.scale/2)
	screen_yoff = love.graphics.getHeight()/2-(win.height*win.scale/2)
	if love.system.getOS() ~= "Android" then
		success = love.window.setMode( round(love.graphics.getWidth()/win.scale), round(love.graphics.getHeight()/win.scale), {
			[ "vsync" ] = false;
			[ "stencil" ] = false;
			[ "borderless" ] = true;
			[ "fullscreen" ] = true;
		} )
	else success = true
	end
	--love.graphics.setPointSize( win.scale )
	if( success ) then
		reset()
	end
	love.graphics.setCanvas()
end

local mydt = 0
local counter = 0
local genvu = G_ENV.update
local setCanvas = love.graphics.setCanvas
function love.update( dt )
	if love.system.getOS() == "Android" then
		local touches = love.touch.getTouches()
		for i, id in ipairs(touches) do
			local x, y=love.touch.getPosition(id)
			if x < screen_xoff or x > screen_xoff + (canvas:getWidth()*win.scale) then
				if love.keyboard.hasTextInput() == false then
					love.keyboard.setTextInput( true )
				end
			else
				if love.keyboard.hasTextInput() == true then
					love.keyboard.setTextInput( false )
				end
			end
		end
	end
	if genvu then
		setCanvas( canvas )
		local ok, err = pcall( genvu, dt )
		if not ok then error( err ) end
		setCanvas()
		mydt = mydt + dt
		if currKeyReleased ~= '' then
		 currKeyReleased = ""
		end
		if currKeyPressed ~= '' then
		 currKeyPressed = ""
		end
		currMouseReleased = 0
		currMousePressed = 0
	else
		genvu = G_ENV.update
	end
	if counter >= 60 then
		CPU_SPEED = mydt
		mydt = 0
		counter = 0
		USED_STORAGE = determineSize( 'root/' )
		if winw ~= win.width then
			winw = win.width
			winww = 1/win.width
		end
	end
	counter = counter + 1
end

local floor = math.floor
local draw = love.graphics.draw
function love.draw()
	if screen_xoff and screen_yoff then
		--for i=0, gfxSize do
			--if gfa[ i ] > 0 then
				--local curr = gfx[ i ]
				--local b = curr[ 3 ]-blueCutoff
				--if b < 0 then b = 0 end
				--setColor( (curr[ 1 ]*17)*twofivefive, (curr[ 2 ]*17)*twofivefive, (b*17)*twofivefive )
				--point( screen_xoff+(i%winw)*wins, screen_yoff+floor(i*winww)*wins )
			--end
		--end
		setColor( 1, 1, 1 )
		draw( canvas, screen_xoff, screen_yoff, 0, wins, wins )
	end
end








