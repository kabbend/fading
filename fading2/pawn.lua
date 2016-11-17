
local theme		= require 'theme'	-- global theme

--
--  Pawn object 
--  A pawn holds the image, with proper scale defined at pawn creation on the map,
--  along with the ID of the corresponding PJ/PNJ.
--  Both sizes of the pawn image (sizex and sizey) are computed to follow the image
--  original height/width ratio. Sizex is directly defined by the MJ at pawn creation,
--  using the arrow on the map, sizey is then derived from it
-- 
local Pawn = {}
function Pawn:new( id, snapshot, width , x, y ) 
  local new = {}
  setmetatable(new,self)
  self.__index = self 
  new.id = id
  new.layer = pawnMaxLayer 
  new.x, new.y = x or 0, y or 0 		-- current pawn position, relative to the map
  new.moveToX, new.moveToY = new.x, new.y 	-- destination of a move 
  new.snapshot = snapshot
  new.sizex = width 				-- width size of the image in pixels, for map at scale 1
  local w,h = new.snapshot.w, new.snapshot.h
  new.sizey = new.sizex * (h/w) 
  local f1,f2 = new.sizex/w, new.sizey/h
  new.f = math.min(f1,f2)
  new.offsetx = (new.sizex + 3*2 - w * new.f ) / 2
  new.offsety = (new.sizey + 3*2 - h * new.f ) / 2
  new.PJ = false
  new.color = theme.color.white
  return new
  end

return Pawn

