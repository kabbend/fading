
local rpg 		= require 'rpg'		-- code related to the RPG itself
local Window 		= require 'window'	-- Window class & system
local theme		= require 'theme'	-- global theme
local yui               = require 'yui.yaoui'   -- graphical library on top of Love2D

-- some GUI buttons whose color will need to be changed at runtime
local attButton		= nil		-- button Roll Attack
local armButton		= nil		-- button Roll Armor
local nextButton	= nil		-- button Next Round
local clnButton		= nil		-- button Cleanup
local thereIsDead	= false		-- is there a dead character in the list ? (if so, cleanup button is clickable)

-- Round information
local roundTimer	= 0
local roundNumber 	= 1			
local newRound	= true

-- flash flag and timer when 'next round' is available
local flashTimer	= 0
local flashSequence	= false

local size = 19 -- base font size

-- draw a small colored circle, at position x,y, with 'id' as text
function drawRound( x, y, kind, id )
        if kind == "target" then love.graphics.setColor(250,80,80,180) end
        if kind == "attacker" then love.graphics.setColor(204,102,0,180) end
        if kind == "danger" then love.graphics.setColor(66,66,238,180) end 
        love.graphics.circle ( "fill", x , y , 15 ) 
        love.graphics.setColor(0,0,0)
        love.graphics.setFont(theme.fontRound)
        love.graphics.print ( id, x - string.len(id)*3 , y - 9 )
        end

--
-- Combat class
-- a Combat is a window which displays PNJ list and buttons 
--
local Combat = Window:new{ class = "combat" , title = "COMBAT TRACKER" , wResizable = true, hResizable = true }

function Combat:getPNJWithFocus() return self.focus end
function Combat:setFocus(i)
    self.lastFocus = self.focus
    self.focus = i
    self.focusAttackers = PNJTable[i].attackers
    self.focusTarget = PNJTable[i].target
    self:updateLineColor(i)
    end

function Combat:new( t ) -- create from w, h, x, y

  local new = t or {}
  setmetatable( new , self )
  self.__index = self

  -- in combat mode, a given PNJ line may have the focus
  new.focus	        = nil   -- Index (in PNJTable) of the current PNJ with focus (or nil if no one)
  new.focusTarget     	= nil   -- unique ID (and not index) of the corresponding target
  new.focusAttackers  	= {}    -- List of unique IDs of the corresponding attackers
  new.lastFocus		= nil	-- store last focus value
  new.nextFlash		= false

  local viewh = new.layout.HC           -- view height
  local vieww = new.layout.W - 260      -- view width

  -- create view structure
  new.view = yui.View(0, 0, vieww, viewh, {
         margin_top = 5,
         margin_left = 5,
         yui.Stack({name="s",
             yui.Flow({name="t",
                 yui.HorizontalSpacing({w=10}),
                 yui.Button({name="nextround", text="  Next Round  ", size=size, black = true,
                         onClick = function(self) if self.button.black then return end
                                                  if rpg.checkForNextRound() then new:nextRound() end end }),
                 yui.Text({text="Round #", size=size, bold=1, center = 1}),
                 yui.Text({name="round", text=tostring(roundNumber), size=32, w = 50, bold=1, color={0,0,0} }),
                 --yui.FlatDropdown({options = opt, size=size-2, onSelect = function(self, option) current_class = option end}),
                 --yui.HorizontalSpacing({w=10}),
                 --yui.Button({text=" Create ", size=size,
                 --        onClick = function(self) return generateNewPNJ(current_class) and sortAndDisplayPNJ() end }),
                 yui.HorizontalSpacing({w=50}),
                 yui.Button({name = "rollatt", text="     Roll Attack     ", size=size, black = true,
                        onClick = function(self) if self.button.black then return end rpg.rollAttack("attack") end }),
                 yui.HorizontalSpacing({w=10}),
                 yui.Button({name = "rollarm", text="     Roll  Armor     ", size=size, black = true,
                        onClick = function(self) if self.button.black then return end rpg.rollAttack("armor") end }),
                 yui.HorizontalSpacing({w=150}),
                 yui.Button({name="cleanup", text="       Cleanup       ", size=size,
                         onClick = function(self) rpg.removeDeadPNJ(); new:sortAndDisplayPNJ(); thereIsDead = false end }),
               }), -- end of Flow
             new:createPNJGUIFrame(),
            }) -- end of Stack
       })
     nextButton = new.view.s.t.nextround
     attButton = new.view.s.t.rollatt
     armButton = new.view.s.t.rollarm
     clnButton = new.view.s.t.cleanup
     nextButton.button.black = true
     attButton.button.black = true
     armButton.button.black = true
     clnButton.button.black = true

  return new
end

-- create and return the PNJ list GUI frame 
-- (with blank values at that time)
function Combat:createPNJGUIFrame()

  local cself = self
  local t = {name="pnjlist"}
  local width = 60;
  t[1] = yui.Flow({ name="headline",
      yui.Text({text="Done", w=40, size=size-2, bold=1, center = 1 }),
      yui.Text({text="ID", w=35, size=size, bold=1, center = 1 }),
      yui.Text({text="CLASS", w=width*2.5, bold=1, size=size, center = 1}),
      yui.Text({text="INIT", w=90, bold=1, size=size, center = 1}),
      yui.Text({text="INT/END/FOR\nDEX/FIGHT/PER", bold=1, w=125, size=size-2, center = 1}),
      yui.Text({text="WEAPON", w=width*2, bold=1, size=size, center = 1 }),
      yui.Text({text="GOAL", w=width, bold=1, size=size, center = 1}),
      yui.Text({text="ROLL", w=width, bold=1, size=size, center = 1}),
      yui.Text({text="DMG", w=width, bold=1, size=size, center = 1}),
      yui.Text({text="DEF", w=75, bold=1, size=size }),
      yui.Text({text="ARM", w=width, bold=1, size=size, center = 1}),
      yui.Text({text="HITS", w=80, bold=1, size=size}),
      yui.HorizontalSpacing({w=30}),
      yui.Text({name="stance", text="STANCE (Agress., Neutre, Def.)", w=220, size=size, center=1}),
      --yui.Text({text="OPPONENTS", w=40, bold=1, size=size}),
    }) 

  for i=1,PNJmax do
    t[i+1] = 
    yui.Flow({ name="PNJ"..i,

        yui.HorizontalSpacing({w=10}),
        yui.Checkbox({name = "done", text = '', w = 30, 
            onClick = function(self) 
              if (PNJTable[i]) then 
                PNJTable[i].done = self.checkbox.checked; 
                cself:updateLineColor(i)
		cself.nextFlash = rpg.checkForNextRound() 
              end  
            end}),

        yui.Text({name="id",text="", w=35, bold=1, size=size, center = 1 }),
        yui.Text({name="class",text="", w=width*2.5, bold=1, size=size, center=false}),
        yui.Text({name="init",text="", w=40, bold=1, size=size, center = 1, color = theme.color.darkblue}),

        yui.Button({name="initm", text = '-', size=size-4,
            onClick = function(self) 
              if (i>#PNJTable) then return end
              if (PNJTable[i].is_dead) then return end
              if (PNJTable[i].PJ) then 
                if (PNJTable[i].final_initiative >= 1) then PNJTable[i].final_initiative = PNJTable[i].final_initiative - 1 end
                self.parent.init.text = PNJTable[i].final_initiative
                PNJTable[i].initTimerLaunched = true 
              end
            end}),

        yui.HorizontalSpacing({w=3}),
        yui.Button({name="initp", text = '+', size=size-4,
            onClick = function(self) 
              if (i>#PNJTable) then return end
              if (PNJTable[i].is_dead) then return end
              if (PNJTable[i].PJ) then 
                PNJTable[i].final_initiative = PNJTable[i].final_initiative + 1
                self.parent.init.text = PNJTable[i].final_initiative
                PNJTable[i].initTimerLaunched = true 
              end
            end}),

        yui.Text({name="endfordexfight", text = "", bold=1, w=width*2, size=size-4, center = 1}),
        yui.Text({name="weapon",text="", w=width*2, bold=1, size=size, center = 1}),
        yui.Text({name="goal",text="", w=width, bold=1, size=size+4, center = 1}),
        yui.Text({name="roll",text="", w=width-20, bold=1, size=size+4, center=1, color = theme.color.darkblue}),
        yui.Text({name="dmg",text="", text2 = "", text3 = "", w=width+25, bold=1, size=size+4, center = 1}),

        yui.Text({name="def", text="", w=40, bold=1, size=size+4, color = theme.color.darkblue , center = 1}),

        yui.Button({name="minusd", text = '-', size=size,
            onClick = function(self) 
              if (i>#PNJTable) then return end
              if (PNJTable[i].is_dead) then return end
              rpg.changeDefense(i,-1,nil)
            end}),

        yui.Text({name="armor",text="", w=width, bold=1, size=size, center = 1}),
        yui.Text({name="hits", text="", w=40, bold=1, size=size+8, color = theme.color.orange, center = 1}),

        yui.Button({name="minus", text = '-1', size=size-2,
            onClick = function(self) 
              if (i>#PNJTable) then return end
              if (PNJTable[i].is_dead) then return end
              PNJTable[i].hits = PNJTable[i].hits - 1
              -- remove DEF if allowed
              if PNJTable[i].acceptDefLoss then
                rpg.changeDefense(i,-1,nil)
                PNJTable[i].lasthit = 0
                PNJTable[i].acceptDefLoss = false
              end
              if (PNJTable[i].hits == 0) then 
                PNJTable[i].is_dead = true; 

		tcpsend( projector, "KILL " .. PNJTable[i].id )

                self.parent.done.checkbox.set = true -- a dead character is done
                PNJTable[i].done = true
                self.parent.stance.text = "--"; 
                self.parent.roll.text = "--"; 
                self.parent.hits.text = "--"; 
                self.parent.goal.text = "--"; 
                self.parent.armor.text = "--"; 
                self.parent.dmg.text = "--"; 
                self.parent.weapon.text = "--"; 
                self.parent.endfordexfight.text = "--"; 
                self.parent.def.text = "--"; 
                self.parent.dmg.text2 = "";
                self.parent.dmg.text3 = "";
		thereIsDead = true
		cself.nextFlash = rpg.checkForNextRound() 
                return
              end

              if (PNJTable[i].hits >0 and PNJTable[i].hits <= 5) then
                PNJTable[i].malus = -12 + (2 * PNJTable[i].hits)
              end
              PNJTable[i].final_goal = PNJTable[i].goal + PNJTable[i].malus + PNJTable[i].goalstancebonus
              self.parent.goal.text = PNJTable[i].final_goal
              self.parent.hits.text = PNJTable[i].hits 
            end}),

        yui.HorizontalSpacing({w=3}),
        yui.Button({name="shot", text = '0', size=size-2,
            onClick = function(self) 
              if (i>#PNJTable) then return end
              if (PNJTable[i].is_dead) then return end
              -- remove DEF if allowed
              if PNJTable[i].acceptDefLoss then
                rpg.changeDefense(i,-1,nil)
                PNJTable[i].lasthit = 0
                PNJTable[i].acceptDefLoss = false
              end
              PNJTable[i].final_goal = PNJTable[i].goal + PNJTable[i].malus + PNJTable[i].goalstancebonus
            end}),

        yui.HorizontalSpacing({w=3}),
        yui.Button({name="kill", text = 'kill', size=size-2, 
            onClick = function(self)
              if (i>#PNJTable) then return end
              if (PNJTable[i].is_dead) then return end
              PNJTable[i].hits = 0
              PNJTable[i].is_dead = true 

	      tcpsend( projector, "KILL " .. PNJTable[i].id )

              self.parent.done.checkbox.set = true -- a dead character is done
              PNJTable[i].done = true
              self.parent.stance.text = "--"; 
              self.parent.hits.text = "--"; 
              self.parent.roll.text = "--";
              self.parent.goal.text = "--"; 
              self.parent.armor.text = "--"; 
              self.parent.dmg.text = "--"; 
              self.parent.weapon.text = "--"; 
              self.parent.endfordexfight.text = "--"; 
              self.parent.def.text = "--"; 
              self.parent.dmg.text2 = "";
              self.parent.dmg.text3 = "";
	      thereIsDead = true
	      cself.nextFlash = rpg.checkForNextRound() 
            end }),

        yui.HorizontalSpacing({w=12}),
        yui.Text({name="stance",text="", w=100, size=size, center = 1}),
        yui.Button({name="agressive", text = 'A', size=size,
            onClick = function(self)
              if (i>#PNJTable) then return end
              if (PNJTable[i].is_dead) then return end
              PNJTable[i].goalstancebonus = 3;
              PNJTable[i].final_goal = PNJTable[i].goal + PNJTable[i].malus + PNJTable[i].goalstancebonus;
              rpg.changeDefense(i,0,-2)
              PNJTable[i].stance = "agress."
              self.parent.stance.text = "agress."; 
              self.parent.def.text = PNJTable[i].final_defense; 
              self.parent.goal.text = PNJTable[i].final_goal; 
              -- if PNJ has not played yet, reroll
              if not PNJTable[i].done then rpg.reroll(i); cself:updateLineColor(i)  end
            end }),

        yui.HorizontalSpacing({w=3}),
        yui.Button({name="neutral", text = 'N', size=size,
            onClick = function(self)
              if (i>#PNJTable) then return end
              if (PNJTable[i].is_dead) then return end
              PNJTable[i].goalstancebonus = 0;
              PNJTable[i].final_goal = PNJTable[i].goal + PNJTable[i].malus + PNJTable[i].goalstancebonus;
              rpg.changeDefense(i,0,0)
              PNJTable[i].stance = "neutral"
              self.parent.stance.text = "neutral" 
              self.parent.def.text = PNJTable[i].final_defense; 
              self.parent.goal.text = PNJTable[i].final_goal; 
              -- if PNJ has not played yet, reroll
              if not PNJTable[i].done then rpg.reroll(i); cself:updateLineColor(i) end
            end }),

        yui.HorizontalSpacing({w=3}),
        yui.Button({name="defense", text = 'D', size=size,
            onClick = function(self)
              if (i>#PNJTable) then return end
              if (PNJTable[i].is_dead) then return end
              PNJTable[i].goalstancebonus = -3;
              PNJTable[i].final_goal = PNJTable[i].goal + PNJTable[i].malus + PNJTable[i].goalstancebonus;
              rpg.changeDefense(i,0,2)
              PNJTable[i].stance = "defense"
              self.parent.stance.text = "defense" 
              self.parent.def.text = PNJTable[i].final_defense; 
              self.parent.goal.text = PNJTable[i].final_goal; 
              -- if PNJ has not played yet, reroll
              if not PNJTable[i].done then rpg.reroll(i); cself:updateLineColor(i) end
            end }),

        yui.HorizontalSpacing({w=10})
        
      })
    PNJtext[i] = t[i+1] 
  end 

  return yui.Stack(t)
end
function Combat:draw()

  local alpha = 80
  local zx,zy = -( self.x * 1/self.mag - self.layout.W / 2), -( self.y * 1/self.mag - self.layout.H / 2)

  -- draw background
  self:drawBack()

  love.graphics.setScissor(zx,zy,self.w/self.mag,self.h/self.mag) 
  self.view:draw()
 

  -- draw FOCUS if applicable
  love.graphics.setColor(0,102,0,alpha)
  if self.focus then love.graphics.rectangle("fill",PNJtext[self.focus].x+2,PNJtext[self.focus].y-5,self.layout.WC - 5,42) end

  -- draw ATTACKERS if applicable
  love.graphics.setColor(174,102,0,alpha)
    if self.focusAttackers then
      for i,v in pairs(self.focusAttackers) do
        if v then
          local index = findPNJ(i)
          if index then 
		  love.graphics.rectangle("fill",PNJtext[index].x+2,PNJtext[index].y-5,self.layout.WC - 5,42) 
		  -- emphasize defense value, but only for PNJ
    		  if not PNJTable[index].PJ then
			  love.graphics.setColor(0,0,0,120)
		  	  love.graphics.rectangle("line",PNJtext[index].x+743,PNJtext[index].y-3, 26,39) 
		  end
		  PNJtext[index].def.color = { unpack(theme.color.white) }
    		  love.graphics.setColor(204,102,0,alpha)
	  end
        end
      end
    end 

    -- draw TARGET if applicable
    love.graphics.setColor(250,60,60,alpha*1.5)
    local index = findPNJ(self.focusTarget)
    if index then love.graphics.rectangle("fill",PNJtext[index].x+2,PNJtext[index].y-5,self.layout.WC - 5,42) end

    -- draw PNJ snapshot if applicable
    for i=1,#PNJTable do
      if PNJTable[i].snapshot then
       	    love.graphics.setColor(255,255,255)
	    local s = PNJTable[i].snapshot
	    local xoffset = s.w * s.snapmag * 0.5 / 2
	    love.graphics.draw( s.im , zx + 210 - xoffset , PNJtext[i].y - 2 , 0 , s.snapmag * 0.5, s.snapmag * 0.5 ) 
      end
    end

  if self.nextFlash then
    -- draw a blinking rectangle until Next button is pressed
    if flashSequence then
      love.graphics.setColor(250,80,80,alpha*1.5)
    else
      love.graphics.setColor(0,0,0,alpha*1.5)
    end
    love.graphics.rectangle("fill",PNJtext[1].x+1010,PNJtext[1].y-5,400,(#PNJTable)*43)
  end
  love.graphics.setScissor() 

  -- print bar
  self:drawBar()
  self:drawResize()

end

function Combat:update(dt)
	
	Window.update(self,dt)

	local W,H=self.layout.W, self.layout.H
  	local zx,zy = -( self.x * 1/self.mag - W / 2), -( self.y * 1/self.mag - H / 2)
	self.view:setElementPosition( self.view.layout[1], zx + 5, zy + 5 )
  	self.view:update(dt)
  	yui.update({self.view})

        -- check PNJ-related timers
        for i=1,#PNJTable do

                -- temporarily change color of DEF (defense) value for each PNJ attacked within the last 3 seconds, 
                if not PNJTable[i].acceptDefLoss then
                        PNJTable[i].lasthit = PNJTable[i].lasthit + dt
                        if (PNJTable[i].lasthit >= 3) then
                                 -- end of timer for this PNJ
                                 PNJTable[i].acceptDefLoss = true
                                 PNJTable[i].lasthit = 0
                         end
                 end

                -- sort and reprint screen after 3 s. an INIT value has been modified
                if PNJTable[i].initTimerLaunched then
                        PNJtext[i].init.color = theme.color.red
                        PNJTable[i].lastinit = PNJTable[i].lastinit + dt
                        if (PNJTable[i].lastinit >= 3) then
                                 -- end of timing for this PNJ
                                 PNJTable[i].initTimerLaunched = false
                                 PNJTable[i].lastinit = 0
                                 PNJtext[i].init.color = theme.color.darkblue
                                 self:sortAndDisplayPNJ()
                        end
                 end
 
                 if (PNJTable[i].acceptDefLoss) then PNJtext[i].def.color = theme.color.darkblue else PNJtext[i].def.color = { 240, 10, 10 } end
 
         end
 
         -- change color of "Round" value after a certain amount of time (5 s.)
         if (newRound) then
                 roundTimer = roundTimer + dt
                 if (roundTimer >= 5) then
                         self.view.s.t.round.color = theme.color.black
                         self.view.s.t.round.text = tostring(roundNumber)
                         newRound = false
                         roundTimer = 0
                 end
         end

        -- the "next round zone" is blinking (with frequency 400 ms) until "Next Round" is pressed
        if (self.nextFlash) then
                 flashTimer = flashTimer + dt
                 if (flashTimer >= 0.4) then
                         flashSequence = not flashSequence
                         flashTimer = 0
                 end     
        else    
                 -- reset flash, someone has pressed the button
                 flashSequence = 0
                 flashTimer = 0
        end  

        -- change some button behaviour when needed
        nextButton.button.black = not self.nextFlash
        if not nextButton.button.black then
                nextButton.button.timer:tween('color', 0.25, nextButton.button, {color = { 80, 110, 180}}, 'linear')
        else
                nextButton.button.timer:tween('color', 0.25, nextButton.button, {color = { 20, 20, 20}}, 'linear')
        end

        if rpg.isAttorArm( self.focus ) then
          attButton.button.black = false
          attButton.button.timer:tween('color', 0.25, attButton.button, {color = { 80, 110, 180}}, 'linear')
          armButton.button.black = false
          armButton.button.timer:tween('color', 0.25, armButton.button, {color = { 80, 110, 180}}, 'linear')
        else
          attButton.button.black = true
          attButton.button.timer:tween('color', 0.25, attButton.button, {color = { 20, 20, 20}}, 'linear')
          armButton.button.black = true
          armButton.button.timer:tween('color', 0.25, armButton.button, {color = { 20, 20, 20}}, 'linear')
        end

        if thereIsDead then
          clnButton.button.black = false
          clnButton.button.timer:tween('color', 0.25, clnButton.button, {color = { 80, 110, 180}}, 'linear')
        else
          clnButton.button.black = true
          clnButton.button.timer:tween('color', 0.25, clnButton.button, {color = { 20, 20, 20}}, 'linear')
   
	end

	end

function Combat:click(x,y)

	local W,H=self.layout.W, self.layout.H
  	local zx,zy = -( self.x * 1/self.mag - W / 2), -( self.y * 1/self.mag - H / 2)

	if (y - zy) >= 40 then -- clicking on buttons does not change focus

  	-- we assume that the mouse was pressed outside PNJ list, this might change below
  	self.lastFocus = self.focus
  	self.focus = nil
  	self.focusTarget = nil
  	self.focusAttackers = nil

  	-- check which PNJ was selected, depending on position on y-axis
  	  for i=1,#PNJTable do
    	  if (y >= PNJtext[i].y -5 and y < PNJtext[i].y + 42 - 5) then
      		PNJTable[i].focus = true
      		self.lastFocus = self.focus
      		self.focus = i
      		self.focusTarget = PNJTable[i].target
      		self.focusAttackers = PNJTable[i].attackers
      		-- this starts the arrow mode or the drag&drop mode, depending on x
	    	local s = PNJTable[i].snapshot
	    	local xoffset = s.w * s.snapmag * 0.5 / 2
		if x >= zx + 210 - xoffset and x <= zx + 210 + xoffset  then
		 dragMove = true
		 dragObject = { originWindow = self, 
				object = { class = "pnjtable", id = PNJTable[i].id },
				snapshot = PNJTable[i].snapshot
				}	
		else
        	 arrowMode = true
        	 arrowStartX = x
        	 arrowStartY = y
        	 arrowStartIndex = i
		end	
    	  else
      		PNJTable[i].focus = false
    	  end

	  end

	end

  	Window.click(self,x,y)		-- the general click function may set mouseMove, but we want
					-- to move only in certain circumstances, so we override this below

	-- resize supersedes focus
	if mouseResize then 
		self.focus = nil 
  		self.focusTarget = nil
  		self.focusAttackers = nil
	end

	if not self.focus and not mouseResize then
		-- want to move window 
		mouseMove = true
		arrowMode = false
		arrowStartX, arrowStartY = x, y
		arrowModeMap = nil
	elseif self.focus and not dragMove then
		mouseMove = false
        	arrowMode = true
	else
		mouseMove = false
        	arrowMode = false
	end
	
	if (y - zy) < 40 then 
        	arrowMode = false
	end

  	end

function Combat:drop( o )

	if o.object.class == "pnj" then
		rpg.generateNewPNJ( o.object.rpgClass.class )
		self:sortAndDisplayPNJ()
	end

	end

-- GUI function: set the color for the ith-line ( = ith PNJ)
function Combat:updateLineColor( i )

  PNJtext[i].init.color                         = theme.color.darkblue
  PNJtext[i].def.color                          = theme.color.darkblue

  if not PNJTable[i].PJ then
    if not PNJTable[i].roll:isSuccess() then
      PNJtext[i].roll.color                     = theme.color.red
      PNJtext[i].dmg.color                      = theme.color.red
    elseif not PNJTable[i].roll:isPassDefense() then
      PNJtext[i].roll.color                     = theme.color.darkgrey
      PNJtext[i].dmg.color                      = theme.color.darkgrey
    else
      PNJtext[i].roll.color                     = theme.color.darkgreen
      PNJtext[i].dmg.color                      = theme.color.darkgreen
    end
  else
    PNJtext[i].roll.color                       = theme.color.purple
    PNJtext[i].dmg.color                        = theme.color.purple
  end

  if (PNJTable[i].done) then
    PNJtext[i].id.color                         = theme.color.masked
    PNJtext[i].class.color                      = theme.color.masked
    PNJtext[i].endfordexfight.color             = theme.color.masked
    PNJtext[i].weapon.color                     = theme.color.masked
    PNJtext[i].goal.color                       = theme.color.masked
    PNJtext[i].armor.color                      = theme.color.masked
    PNJtext[i].roll.color                       = theme.color.masked
    PNJtext[i].dmg.color                        = theme.color.masked
  elseif PNJTable[i].PJ then
    PNJtext[i].id.color                         = theme.color.purple
    PNJtext[i].class.color                      = theme.color.purple
    PNJtext[i].endfordexfight.color             = theme.color.purple
    PNJtext[i].weapon.color                     = theme.color.purple
    PNJtext[i].goal.color                       = theme.color.purple
    PNJtext[i].armor.color                      = theme.color.purple
  else
    PNJtext[i].id.color                         = theme.color.black
    PNJtext[i].class.color                      = theme.color.black
    PNJtext[i].endfordexfight.color             = theme.color.black
    PNJtext[i].weapon.color                     = theme.color.black
    PNJtext[i].goal.color                       = theme.color.black
    PNJtext[i].armor.color                      = theme.color.black
  end
end


-- The PNJ are not displayed in the order they were generated: they are always 
-- sorted first by descending initiative value, then ascending ID value.
-- After a PNJ generation, this function sorts the PNJTable{} properly, then
-- re-print the GUI PNJ list completely.
-- Dead PNJs are not removed, and are still sorted and displayed
-- in the slot they were when alive.
-- returns nothing.
function Combat:sortAndDisplayPNJ()

  -- sort PNJ by descending initiative value, then ascending ID value
  table.sort( PNJTable, 
    function (a,b)
      if (a.final_initiative ~= b.final_initiative) then return (a.final_initiative > b.final_initiative) 
      else return (a.id < b.id) end
    end)

  -- then display PNJ table completely	
  for i=1,PNJmax do  

    if (i>#PNJTable) then

      -- erase unused slots (at the end of the list)
      PNJtext[i].done.checkbox.reset = true
      PNJtext[i].id.text = ""
      PNJtext[i].class.text = ""
      PNJtext[i].init.text = ""
      PNJtext[i].roll.text = "";
      PNJtext[i].dmg.text = "";
      PNJtext[i].armor.text = "";
      PNJtext[i].hits.text = "";
      PNJtext[i].endfordexfight.text = ""
      PNJtext[i].def.text = ""
      PNJtext[i].goal.text = ""
      PNJtext[i].stance.text = ""
      PNJtext[i].weapon.text = ""
      PNJtext[i].dmg.text2 = ""
      PNJtext[i].dmg.text3 = ""

    else

      pnj = PNJTable[i]
      PNJtext[i].class.text = pnj.class;

      -- cosmetic: do not display an init value if equal to previous one
      if (i==1) then PNJtext[i].init.text = math.floor( pnj.final_initiative ); end
      if (i>=2) then
        if ( math.floor( pnj.final_initiative ) ~= math.floor( PNJTable[i-1].final_initiative ) )
        then PNJtext[i].init.text = math.floor( pnj.final_initiative )
        else PNJtext[i].init.text = ""
        end
      end

      if (pnj.is_dead) then
        PNJtext[i].done.checkbox.set = true
        PNJtext[i].id.text = pnj.id
        PNJtext[i].roll.text = "--";
        PNJtext[i].dmg.text = "--";
        PNJtext[i].armor.text = "--";
        PNJtext[i].hits.text = "--";
        PNJtext[i].endfordexfight.text = "--"
        PNJtext[i].def.text = "--"
        PNJtext[i].goal.text = "--"
        PNJtext[i].stance.text = "--"
        PNJtext[i].weapon.text = "--"
        PNJtext[i].dmg.text2 = ""
        PNJtext[i].dmg.text3 = ""
        
      else

        if (PNJTable[i].done) then PNJtext[i].done.checkbox.set = true else PNJtext[i].done.checkbox.reset = true end

        PNJtext[i].id.text = pnj.id
        PNJtext[i].dmg.text = pnj.dmg .. "D";

        -- display roll for PNJ (not for PJ)
        if not pnj.PJ then
          PNJtext[i].roll.text = pnj.roll:getRoll();
          PNJtext[i].dmg.text2 = pnj.roll:getVPText();
          PNJtext[i].dmg.text3 = pnj.roll:getDamageText();
        else
          PNJtext[i].roll.text = ""
          PNJtext[i].dmg.text2 = ""
          PNJtext[i].dmg.text3 = ""
        end

        -- PJ are displayed in a different color
        self:updateLineColor(i)

        if (pnj.armor==0) then PNJtext[i].armor.text = "-" else PNJtext[i].armor.text = pnj.armor .. "D"; end
        PNJtext[i].hits.text = pnj.hits;
        PNJtext[i].endfordexfight.text = pnj.intelligence .." ".. pnj.endurance .." ".. pnj.force .. "\n" .. pnj.dex .." ".. pnj.fight .. " " .. pnj.perception;
        PNJtext[i].def.text = pnj.final_defense;
        PNJtext[i].goal.text = pnj.final_goal;
        PNJtext[i].stance.text = pnj.stance;
        PNJtext[i].weapon.text = pnj.weapon or "";
        
      end
    end

    -- all this resets the current focus
    self.lastFocus 		= self.focus
    self.focus     		= nil
    self.focusTarget   	= nil
    self.focusAttackers  	= {}

  end 

end

-- Increase and display round number, reset all "done" checkboxes (except for
-- dead PNJs which are considered as "done" by default), and reset DEFENSE values. 
-- Returns nothing.
function Combat:nextRound()

    math.randomseed( os.time() )

    -- increase round
    roundNumber = roundNumber + 1
    self.view.s.t.round.text = tostring(roundNumber)
    self.view.s.t.round.color= theme.color.red

    -- set timer
    self.nextFlash = false
    roundTimer = 0
    newRound = true

    -- reset defense & done checkbox
    for i=1,#PNJTable do

      if (not PNJTable[i].is_dead) then

        PNJTable[i].done = false
        PNJtext[i].done.checkbox.reset = true

        PNJTable[i].defmalus = 0
        PNJTable[i].final_defense = PNJTable[i].defense + PNJTable[i].defstancemalus
        PNJtext[i].def.text = PNJTable[i].final_defense;

        if (not PNJTable[i].PJ) then rpg.reroll (i); self:updateLineColor(i) end

      else

        PNJTable[i].done = true 				-- a dead character is done
        PNJtext[i].done.checkbox.set = true

      end

      self:updateLineColor(i)

    end

    end

return Combat

