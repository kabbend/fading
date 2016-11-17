

local Atlas = {}
Atlas.__index = Atlas

function Atlas:getScenario() return self.scenario end
function Atlas:removeVisible() self.visible = nil end
function Atlas:isVisible(map) return self.visible == map end
function Atlas:getVisible() return self.visible end 
function Atlas:toggleVisible( map )
	if not map then return end
	if map.kind == "scenario" then return end -- a scenario is never displayed to the players
	if self.visible == map then 
		self.visible = nil 
		map.sticky = false
		-- erase snapshot !
		self.pWindow.currentImage = nil 
	  	-- remove all pawns remotely !
		tcpsend( projector, "ERAS")
	  	-- send hide command to projector
		tcpsend( projector, "HIDE")
	else    
		self.visible = map 
		-- change snapshot !
		self.pWindow.currentImage = map.im
	  	-- remove all pawns remotely !
		tcpsend( projector, "ERAS")
		-- send to projector
		if map.is_local and not fullBinary then
		  tcpsendBinary{ file=map.file } 
 		  tcpsend(projector,"BEOF")
		elseif fullBinary then
		  tcpsendBinary{ filename=map.filename } 
 		  tcpsend(projector,"BEOF")
		else 
  		  tcpsend( projector, "OPEN " .. map.baseFilename )
		end
  		-- send mask if applicable
  		if map.mask then
			for k,v in pairs( map.mask ) do
				tcpsend( projector, v )
			end
  		end
		-- send pawns if any
		for i=1,#map.pawns do
			local p = map.pawns[i]
			-- check the pawn state before sending it: 
			-- * it might happen that the character has been removed from the list
			-- * don't send dead pawns (what for?)
			local index = findPNJ( p.id )
			if index and (not PNJTable[index].is_dead) then
				local flag = 0
				if p.PJ then flag = 1 end
				-- send over the socket
				if p.snapshot.is_local then
					tcpsendBinary{ file=p.snapshot.file }
	  				tcpsend( projector, "PEOF " .. p.id .. " " .. math.floor(p.x) .. " " .. math.floor(p.y) .. " " .. math.floor(p.sizex) .. " " .. flag )
				elseif fullBinary then
					tcpsendBinary{ filename=p.snapshot.filename }
	  				tcpsend( projector, "PEOF " .. p.id .. " " .. math.floor(p.x) .. " " .. math.floor(p.y) .. " " .. math.floor(p.sizex) .. " " .. flag )
				else
	  				local f = p.snapshot.filename
	  				f = string.gsub(f,baseDirectory,"")
	  				tcpsend( projector, "PAWN " .. p.id .. " " .. math.floor(p.x) .. " " .. math.floor(p.y) .. " " .. math.floor(p.sizex) .. " " .. flag .. " " .. f)
				end
			end
		end
		-- set map frame
  		tcpsend( projector, "MAGN " .. 1/map.mag)
  		tcpsend( projector, "CHXY " .. math.floor(map.x+map.translateQuadX) .. " " .. math.floor(map.y+map.translateQuadY) )
  		tcpsend( projector, "DISP")

	end
	end

function Atlas.new( projectorWindow ) 
  local new = {}
  setmetatable(new,Atlas)
  new.visible = nil -- map currently visible (or nil if none)
  new.scenario = nil -- reference the scenario window if any
  new.pWindow = projectorWindow
  return new
  end

return Atlas

