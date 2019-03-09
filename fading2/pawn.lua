
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
function Pawn:new( id, snapshot, width , x, y , class ) 
  local new = {}
  setmetatable(new,self)
  self.__index = self 
  new.id 	= id
  new.class 	= class
  new.loaded 	= false				-- true if pawn is loaded with a map at startup
  new.layer 	= pawnMaxLayer 
  new.x, new.y 	= x or 0, y or 0 		-- current pawn position, relative to the map
  new.moveToX	= new.x
  new.moveToY 	= new.y 			-- destination of a move , deprecated
  new.snapshot 	= snapshot
  new.PJ 	= false
  new.color 	= theme.color.white
  new:setSize(width)
  return new
  end

-- set various sizes for the pawn. this assumes it has a snapshot image associated with it already
function Pawn:setSize(width)
  self.sizex = width                             -- width size of the image in pixels, for map at scale 1
  local w,h = self.snapshot.w, self.snapshot.h
  self.sizey = self.sizex * (h/w)
  local f1,f2 = self.sizex/w, self.sizey/h
  self.f = math.min(f1,f2)
  self.offsetx = (self.sizex + 3*2 - w * self.f ) / 2
  self.offsety = (self.sizey + 3*2 - h * self.f ) / 2
  end

return Pawn

