
--applies a transformation that maps 
--  0,0 => ox, oy
--  1,0 => xx, xy
--  0,1 => yx, yy
-- via love.graphics.translate, .rotate and .scale

function love.graphics.transform(ox, oy, xx, xy, yx, yy)
  
  local ex, ey, fx,fy = xx-ox, xy-oy, yx-ox, yy-oy
  if ex*fy<ey*fx then ex,ey,fx,fy=fx,fy,ex,ey end
  local e,f = math.sqrt(ex*ex+ey*ey), math.sqrt(fx*fx+fy*fy)
  
  ex,ey = ex/e, ey/e
  fx,fy = fx/f, fy/f
  
  local desiredOrientation=math.atan2(ey+fy,ex+fx)
  local desiredAngle=math.acos(ex*fx+ey*fy)/2
  local z=math.tan(desiredAngle)
  local distortion=math.sqrt((1+z*z)/2)
  
  love.graphics.translate(ox, oy)
  love.graphics.rotate(desiredOrientation)
  love.graphics.scale(1, z)
  love.graphics.rotate(-math.pi/4)
  love.graphics.scale(e/distortion,f/distortion)

end

--cached load for images
local imageCache = {}
function love.graphics.getImage(filename)
  if not imageCache[filename] then
    imageCache[filename]=love.graphics.newImage(filename)
  end
  return imageCache[filename]
end


--a polygon function that unpacks a list of points for a polygon
local lovepolygon=love.graphics.polygon
function love.graphics.polygon(mode,p,...)
  if type(p)=="number" then return lovepolygon(mode,p,...) end
  local pts={}
  for i=1,#p do table.insert(pts,p[i][1]) table.insert(pts,p[i][2]) end
  return lovepolygon(mode,unpack(pts))
end


function love.graphics.dbg()
  if not dbg then return end
  love.graphics.setColor(255,255,255)
  local x,y=5,15
  for _,s in ipairs(pretty.table(dbg,4)) do
    love.graphics.print(s,x,y)
    y=y+15
    if y>love.graphics.getHeight()-15 then x,y=x+200,15 end
  end
end

local lastx,lasty
function love.mouse.delta()
  local x,y=love.mouse.getPosition()
  lastx,lasty, x,y = x,y, x-(lastx or x),y-(lasty or y)
  return x,y
end

