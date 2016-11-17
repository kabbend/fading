

-- some convenient file loading functions (based on filename or file descriptor)
local function loadDistantImage( filename )
  local file = assert( io.open( filename, 'rb' ) )
  local image = file:read('*a')
  file:close()
  return image  
end

local function loadLocalImage( file )
  file:open('r')
  local image = file:read()
  file:close()
  return image
end

-- Snapshot class
-- a snapshot holds an image, displayed in the bottom part of the screen.
-- Snapshots are used for general images, and for pawns. For maps, use the
-- specific class Map instead, which is derived from Snapshot.
-- The image itself is stored in memory in its binary form, but for purpose of
-- sending it to the projector, it is also either stored as a path on the shared 
-- filesystem, or a file object on the local filesystem
local Snapshot = { class = "snapshot" , filename = nil, file = nil }

function Snapshot:new( t ) -- create from filename or file object (one mandatory), and kind 
  local new = t or {}
  setmetatable( new , self )
  self.__index = self
  new.snapshotSize = t.size
  assert( new.filename or new.file )
  local image
  if new.filename then 
	image = loadDistantImage( new.filename )
	new.is_local = false
	new.baseFilename = string.gsub(new.filename,baseDirectory,"")
	new.displayFilename = splitFilename(new.filename)
  else 
	image = loadLocalImage( new.file )
	new.is_local = true
	new.baseFilename = new.file:getFilename() 
	new.displayFilename = splitFilename(new.file:getFilename())
  end
  local lfn = love.filesystem.newFileData
  local lin = love.image.newImageData
  local lgn = love.graphics.newImage
  local img = lgn(lin(lfn(image, 'img', 'file')), { mipmaps=true } ) 
  pcall( function() img:setMipmapFilter( "nearest" ) end )
  new.im = img
  new.w, new.h = new.im:getDimensions()
  local f1, f2 = new.snapshotSize / new.w, new.snapshotSize / new.h
  new.snapmag = math.min( f1, f2 )
  new.selected = false
  return new
end

return Snapshot
