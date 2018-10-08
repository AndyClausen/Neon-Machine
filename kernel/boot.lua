local abs=math.abs
gfx.drawFillRect=function(x, y, w, h, rgb)
	for j=y, (y+h)-1 do
		for i=x, (x+w)-1 do
			gfx.putPixel(i, j, rgb)
		end
	end
end
local round = math.round
gfx.drawFillRectAlpha=function(x, y, w, h, rgba)
	for j=y, (y+h)-1 do
		for i=x, (x+w)-1 do
			rOut = ((rgba[1] * rgba[4]) / 15) + ((gfx.getPixel( i, j )[1] * 15 * ( 15 - rgba[4] )) / 225)
			gOut = ((rgba[2] * rgba[4]) / 15) + ((gfx.getPixel( i, j )[2] * 15 * ( 15 - rgba[4] )) / 225)
			bOut = ((rgba[3] * rgba[4]) / 15) + ((gfx.getPixel( i, j )[3] * 15 * ( 15 - rgba[4] )) / 225)
			gfx.putPixel(i, j, {round(rOut),round(gOut),round(bOut)})
		end
	end
end
gfx.drawLine=function(x1, y1, x2, y2, rgb)
	local dx = abs(x2-x1)
	local dy = abs(y2-y1)
	local sx, sy
	if x1 < x2 then sx = 1 else sx = -1 end
	if y1 < y2 then sy = 1 else sy = -1 end
	local err
	if dx>dy then err = dx/2 else err = -dy/2 end
	while true do
		gfx.putPixel(x1,y1,rgb)
		if x1==x2 and y1==y2 then break end
		local e2=err
		if e2>-dx then
			err=err-dy
			x1=x1+sx
		end
		if e2<dy then
			err=err+dx
			y1=y1+sy
		end
	end
end
gfx.drawRect=function(x, y, w, h, rgb)
	w=w-1
	h=h-1
	gfx.drawLine( x, y, x+w, y, rgb )
	gfx.drawLine( x+w, y, x+w, y+h, rgb )
	gfx.drawLine( x+w, y+h, x, y+h, rgb )
	gfx.drawLine( x, y+h, x, y, rgb )
end
font={
	["fonts"]={};
	["NO_FONT"]=nil;
	["current"]="";
}
font.load=function(path, name)
	if fs.exists(path) then
		local ok, err=loadstring("return "..fs.read(path))()
		if not ok then error(err) end
		font.fonts[name]=ok
	else
		error("ERRORAS")
	end
end
font.set=function(name)
	if font.fonts[name] then
		font.current=name
	else
		error("ERR")
	end
end
local tochar=string.byte
font.getWidth=function(chr)
	local curr=font.fonts[font.current]
	if curr then
		local char=tochar(chr)-0x1F
		local x = 0
		for yy=1, #curr do
			local curryy=curr[yy]
			if #curryy[char] > x then
				x = #curryy[char]
			end
		end
		return x
	end
end
font.getHeight=function()
	local curr=font.fonts[font.current]
	if curr then
		return #curr
	end
end
gfx.print=function(v, x, y, c)
	if font.current then
		x = x - 1
		v=tostring(v)
		local offset=0
		for i=1, #v do
			local char=tochar(v, i)-0x1F
			local curr=font.fonts[font.current]
			for yy=1, #curr do
				local curryy=curr[yy]
				for j=1, #curryy do
					if curryy then
						if curryy[char] then
							if curryy[char][j]==1 then
								gfx.putPixel(x+j+offset, y+(yy-1), c)
							end
						end
					end
				end
			end
			offset=offset+(font.getWidth(char)+1)
		end
	end
end
gfx.printAlpha=function(v, x, y, rgba)
	if font.current then
		x = x - 1
		v=tostring(v)
		local offset=0
		for i=1, #v do
			local char=tochar(v, i)-0x1F
			local curr=font.fonts[font.current]
			for yy=1, #curr do
				local curryy=curr[yy]
				for j=1, #curryy do
					if curryy then
						if curryy[char] then
							if curryy[char][j]==1 then
								local xloc=x+j+offset
								local yloc=y+(yy-1)
								rOut = ((rgba[1] * rgba[4]) / 15) + ((gfx.getPixel( xloc, yloc )[1] * 15 * ( 15 - rgba[4] )) / 225)
								gOut = ((rgba[2] * rgba[4]) / 15) + ((gfx.getPixel( xloc, yloc )[2] * 15 * ( 15 - rgba[4] )) / 225)
								bOut = ((rgba[3] * rgba[4]) / 15) + ((gfx.getPixel( xloc, yloc )[3] * 15 * ( 15 - rgba[4] )) / 225)
								gfx.putPixel(xloc, yloc, {math.round(rOut),math.round(gOut),math.round(bOut)})
								
							end
						end
					end
				end
			end
			offset=offset+(font.getWidth(char)+1)
		end
	end
end
local prints = {}
function print(msg)
	msg=msg or ""
	prints[#prints+1]={tostring(msg),{15,15,15}}
end
function panic(msg)
	msg=msg or""
	prints[#prints+1]={tostring(msg),{15,1,1}}
end
function good(msg)
	msg=msg or""
	prints[#prints+1]={tostring(msg),{1,15,1}}
end
font.load("fonts/default.fnt", "default")
font.set("default")
good("System check...")
print("On Bootup:")
print("Ram Size: "..sys.getRamSize())
print("Ram Used: "..sys.getRamUsed())
print("Ram Free: "..(sys.getRamSize()-sys.getRamUsed()))

local prgStarted = false
local function startStartup()
	if fs.exists("startup") then
		print()
		print("On main startup:")
		panic("Loading main...")
		program.load("startup",__NAME)
		program.setfenv( "startup", _G )
		good("Loaded!")
		print("Ram Used: "..sys.getRamUsed())
		print("Ram Free: "..(sys.getRamSize()-sys.getRamUsed()))
		panic("Starting up...")
		local ok, err = program.start("startup")
		if not ok then
			panic("Failed.")
			panic(err)
			print()
			print("Clearing RAM...")
			program.unload("startup")
			print("Ram Used: "..sys.getRamUsed())
			print("Ram Free: "..(sys.getRamSize()-sys.getRamUsed()))
			prgStarted = false
		else
			prgStarted = true
			good("Done.")
			print("Ram Used: "..sys.getRamUsed())
			print("Ram Free: "..(sys.getRamSize()-sys.getRamUsed()))
		end
	end
end

startStartup()
function update(dt)
	if prgStarted == true then
		local ok, err = pcall(program.update, "startup", dt)
		if not ok then
			panic("RUNTIME ERROR:")
			panic(tostring(err))
			prgStarted = false
			program.unload("startup")
		end
	else
		gfx.clear()
		for i=1, #prints do
			gfx.print(prints[i][1], 0, (i-1)*6, prints[i][2])
		end
	end
end