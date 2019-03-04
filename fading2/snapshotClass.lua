
local codepage = require 'codepage'	-- windows cp1252 support


-- some convenient file loading functions (based on filename or file descriptor)
local function loadDistantImage( filename )

  if __WINDOWS__ then filename =  codepage.utf8tocp1252(filename) end 
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

local lfn = love.filesystem.newFileData
local lin = love.image.newImageData
local lgn = love.graphics.newImage

function createThumbnail(img,scale)
	local canvas = love.graphics.newCanvas(img:getWidth()*scale , img:getHeight()*scale)
	love.graphics.push("all")
	local wasCanvas = love.graphics.getCanvas()
	love.graphics.setCanvas(canvas)
	love.graphics.clear()
	love.graphics.draw(img,0,0,0,scale)
	love.graphics.pop()
	love.graphics.setCanvas(wasCanvas)
	local imageData = canvas:newImageData()
	return lgn(imageData)
end

-- Snapshot class
-- a snapshot holds an image, displayed in the bottom part of the screen.
-- Snapshots are used for general images, and for pawns. For maps, use the
-- specific class Map instead, which is derived from Snapshot.
-- The image itself is stored in memory in its binary form, but for purpose of
-- sending it to the projector, it is also either stored as a path on the shared 
-- filesystem, or a file object on the local filesystem
local Snapshot = { class = "snapshot" , filename = nil, file = nil }

function Snapshot:new( t ) -- create from filename or file object (one mandatory), and size (width in pixels)
  local new = t or {}
  setmetatable( new , self )
  self.__index = self
  new.snapshotSize = t.size or layout.snapshotSize
  assert( new.filename or new.file )
  local image
  if new.filename then 
	image = loadDistantImage( new.filename )
	if not image then return nil end
	new.is_local = false
	new.baseFilename = string.gsub(new.filename,baseDirectory,"")
	new.displayFilename = splitFilename(new.filename)
  else 
	image = loadLocalImage( new.file )
	new.is_local = true
	new.baseFilename = new.file:getFilename() 
	new.displayFilename = splitFilename(new.file:getFilename())
  end

  local img = lgn(lin(lfn(image, 'img', 'file')), { mipmaps=true } ) 
  pcall( function() img:setMipmapFilter( "nearest" ) end )
  new.im = img

  new.w, new.h = new.im:getDimensions()
  local f1, f2 = new.snapshotSize / new.w, new.snapshotSize / new.h
  new.snapmag = math.min( f1, f2 )

  new.thumb = createThumbnail( new.im, new.snapmag )

  new.selected = false
  return new
end

return Snapshot

