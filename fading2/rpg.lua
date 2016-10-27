
--
-- code related to the RPG itself (here, Fading Suns)
-- how do we roll dices, how to we inflict damages, etc.
--

local yui       = require 'yui.yaoui'   -- graphical library on top of Love2D

-- array of PNJ templates (loaded from data file)
templateArray   = {}

-- load PNJ templates from data file, return a list of class names (to be used in dropdown listbox)
function loadTemplates()
	local i = 1
	local opt = {}

	Class = function( t )
  		if not t.class then error("need a class attribute (string value) for each class entry") end
  		templateArray[t.class] = t
  		if not t.PJ then          -- only display PNJ classes in Dropdown list, not PJ
    		opt[i] = t.class ;
    		i = i  + 1
  		end
		end

	dofile "fading2/data"

	return opt
	end

-- for a given PNJ at index i, return true if Attack or Armor button should be clickable
-- false otherwise
function isAttorArm( i )
         if not i then return false end
         if not PNJTable[ i ] then return false end
         -- when a PJ is selected, we do not roll for him but for it's enemy, provided
         -- there is one and only one
         if (PNJTable[ i ].PJ) then
                 local count = 0
                 local oneid = nil
                 for k,v in pairs(PNJTable[i].attackers) do
                         if v then oneid = k; count = count + 1 end
                 end
                 if (count ~= 1) or (not oneid) then return false end
         end
         -- if it's a PNJ, return true
         return true
 end

  -- Compute dices to roll when "roll attack" or "roll armor" is pressed
 -- Roll is made for the character with current focus, provided it is a PNJ and not a PJ
 -- If it is a PJ, the roll is made not for him, but for it's opponent, provided there is
 -- one and only one (otherwise, do nothing)
 -- Return nothing, but activate the corresponding draw flag and timer so it is used in
 -- draw()
 function rollAttack( rollType )

         if not focus then return end -- no one with focus, cannot roll

         local index = focus

         -- when a PJ is selected, we do not roll for him but for it's enemy, provided there is only one
         if (PNJTable[ index ].PJ) then
                 local count = 0
                 local oneid = nil
                 for k,v in pairs(PNJTable[index].attackers) do
                         if v then oneid = k; count = count + 1 end
                 end
                 if (count ~= 1) or (not oneid) then return end
                 index = findPNJ(oneid)
                 -- index now points to the line we want
         end

         -- set global variable so we know if we must draw white or black dices
         diceKind = rollType

         -- how many of them ?
         local num
         if rollType == "attack" then
                 num = PNJTable[ index ].roll:getDamage()
         elseif rollType == "armor" then
                 num = PNJTable[ index ].armor
         end

         if num == 0 then return end

         math.randomseed( os.time() )

         -- prepare the dice box simulation
         box:set(10,10,5,20,0.8,2,0.01)

         dice = {}
         for i=1,num do
                 table.insert(dice,
                 { star=newD6star(1.5):set({math.random(10),math.random(10),math.random(10)}, -- position
                                           {-math.random(8,40),-math.random(8,40),-10}, -- velocity
                                           {math.random(10),math.random(10),math.random(10)}), -- angular mvmt
                   die=clone(d6,{material=light.plastic,color={81,0,255,255},text={255,255,255},shadow={20,0,0,190}}) })
         end

         for i=1,#dice do box[i]=dice[i].star end
         for i=#dice+1,40 do box[i]=nil end -- FIXME, hardcoded, ugly...
         box.n = #dice

         -- give go to draw them
         drawDicesTimer = 0
         drawDices = true
         drawDicesResult = false
         lastDiceSum = 0
         diceStableTimer = 0

         end

	 
--[[ d20 Roll object --]]
Roll = {}
Roll.__index = Roll
function Roll:getRoll() return self.roll; end
function Roll:isSuccess() return self.success; end
function Roll:isPassDefense() return self.passDefense; end
function Roll:getVP() return self.VP; end
function Roll:getDamage() return self.damage; end
function Roll.new(goal,defense,basedmg) 
  
  local new = {}
  setmetatable(new,Roll)
  
  new.goal = goal
  new.defense = defense
  new.basedmg = basedmg
  new.VP        = 0
  new.damage    = 0
  new.success   = false
  new.passDefense = false

  new.roll = math.random(1,20)
  
  -- 20 always a failure (or fumble)
  if (new.roll == 20) then 
    new.success = false;
    return new;
  end
  
  -- must roll below the goal, but 1 is always a sucess so we let it pass the test
  if (new.roll > goal and new.roll ~= 1) then 
    new.success = false;
    return new;
  end

  -- base success (we determine PV without taking into account the defense of the target)
  new.VP = math.ceil((new.roll-1)/2)

  -- is it a critical roll?
  if (new.roll == goal) then 
    local newRoll = Roll.new( goal, defense, basedmg )
    if newRoll:isSuccess() then new.VP = new.VP + newRoll:getVP() end
  end

  local success = new.VP

  if defense then
    -- we know the target's defense (not always the case)
    -- reduce PV accordingly
    success = success - defense

    -- sometimes does not pass the defense...
    if success < 0 then 
      new.success = true
      new.passDefense = false 
    else
      new.success = true
      new.passDefense = true
      new.damage = success + basedmg
    end
    
  else -- don't know who is the target...

      new.success = true
      new.passDefense = false -- we don't know
    
  end
  
  return new
  
end
  
function Roll:getVPText()
  if self.roll == 20 then return "(F.)" end
  if not self.success then return "( X )" end
  return "(" .. self.VP .. " VP)" 
  end

function Roll:getDamageText()
  if not self.success then return "( X )" end
  if self.defense then
    if not self.passDefense then return "( X )" end
    return "(".. self.damage .. " D)" 
  else
    return "( ? )"
  end
  end

function Roll:changeDefense( newDefense )
  
  if not self.success then return end -- was not a success anyway, do nothing...
  
  self.defense = newDefense
  
  if not newDefense then
    -- VP does not change
    self.passDefense = false
    self.damage = 0
  else
    local success = self.VP
    success = success - newDefense
    if success < 0 then
      self.passDefense = false
      self.damage = 0
    else
      self.passDefense = true
      self.damage = self.basedmg + success
    end
    
  end
end

-- return a new PNJ object, based on a given template. 
-- Give him a new unique ID 
function PNJConstructor( template ) 

  aNewPNJ = {}

  aNewPNJ.id 		  = generateUID() 		-- unique id
  aNewPNJ.PJ 		  = template.PJ or false	-- is it a PJ or PNJ ?
  aNewPNJ.done		  = false 			-- has played this round ?
  aNewPNJ.is_dead         = false  			-- so far 
  aNewPNJ.snapshot	  = nil				-- image (and some other information) for the PJ
  aNewPNJ.sizefactor	  = template.size or 1.0

  aNewPNJ.ip	  	  = nil				-- for PJ only: ip, if the player is using udp remote communication 
  aNewPNJ.port	  	  = nil				-- for PJ only: port, if the player is using udp remote communication 

  -- GRAPHICAL INTERFACE (focus, timers...)
  aNewPNJ.focus	  	  = false			-- has the focus currently ?

  aNewPNJ.lasthit	  = 0			        -- time when last attacked or lost hit points. This starts a timer of 3 seconds during which
							-- the character cannot loose DEFense value again
  aNewPNJ.acceptDefLoss   = true			-- linked to the timer above: In general a character should accept to loose DEFense
							-- at anytime (acceptDefLoss = true), except that each time DEF is lost, we must wait 3 seconds
							-- before another DEF point can be lost again (and during that time, acceptDefLoss = false) 

  aNewPNJ.initTimerLaunched = false
  aNewPNJ.lastinit	  = 0				-- time when initiative last changed. This starts a timer before the PNJ list is sorted and 
							-- printed to screen again

  -- BASE CHARACTERISTICS
  aNewPNJ.class	      	= template.class or ""
  aNewPNJ.intelligence 	= template.intelligence or 3
  aNewPNJ.perception   	= template.perception or 3
  aNewPNJ.endurance    	= template.endurance or 5    
  aNewPNJ.force        	= template.force or 5        
  aNewPNJ.dex          	= template.dex or 5     	-- Characteristic DEXTERITY

  aNewPNJ.fight        	= template.fight or 5        
  	-- 'fight' is a generic skill that represents all melee/missile capabilities at the same time
  	-- here we avoid managing separate and detailed skills depending on each weapon...

  aNewPNJ.weapon    	= template.weapon or ""
  aNewPNJ.defense      	= template.defense or 1 
  aNewPNJ.dmg          	= template.dmg or 2		-- default damage is 2 (handfight)
  aNewPNJ.armor        	= template.armor or 1      	-- number of dices (eg 1 means 1D armor)

  -- OPPONENTS
  aNewPNJ.target   	= nil 				-- ID of its current target, or nil if not attacking anyone
  aNewPNJ.attackers    	= {}				-- list of IDs of all opponents attacking him 

  -- DERIVED CHARACTERISTICS
  aNewPNJ.initiative    	= aNewPNJ.intelligence + aNewPNJ.dex -- Base initiative. for PNJ, a d6 is added during combat 
  aNewPNJ.final_initiative 	= 0  -- for the moment, will be fixed later

  -- We apply some basic maluses for PNJ (not for PJ for whom we take literal values)
  if not aNewPNJ.PJ then
    -- damage bonus (we apply it without consideration of melee or missile weapon)
    if (aNewPNJ.force >= 9) then aNewPNJ.dmg = aNewPNJ.dmg + 2 elseif (aNewPNJ.force >= 6) then aNewPNJ.dmg = aNewPNJ.dmg + 1 end

    -- maluses due to armor
    -- we apply very simple rules, as follows
    -- Armor >= 2, malus -1 to INIT
    -- Armor >= 3, malus -1 to INIT and DEX
    -- Armor >= 4, malus -3 to INIT, and -1 to DEX and FOR 
    if (aNewPNJ.armor >= 4) then aNewPNJ.initiative = aNewPNJ.initiative -3; aNewPNJ.dex = aNewPNJ.dex - 1; aNewPNJ.force = aNewPNJ.force -1
    elseif (aNewPNJ.armor >= 3) then  aNewPNJ.initiative = aNewPNJ.initiative - 1; aNewPNJ.dex = aNewPNJ.dex - 1 
    elseif (aNewPNJ.armor >= 2) then aNewPNJ.initiative = aNewPNJ.initiative -1;  end
  end

  aNewPNJ.hits        	= aNewPNJ.endurance + aNewPNJ.force + 5
  aNewPNJ.goal         	= aNewPNJ.dex + aNewPNJ.fight
  aNewPNJ.malus	        = 0
	-- generic malus due to low hits (-2 to -10)

  aNewPNJ.defmalus       = 0
	-- malus to defense for the current round, due to attacks
	-- this malus is reinitialized each round

  aNewPNJ.stance         = "neutral" -- by default
  aNewPNJ.defstancemalus = 0
	-- malus to defense due to stance (-2 to +2) 

  aNewPNJ.goalstancebonus= 0
	-- bonus (or malus) to goal due to stance (-3 to +3) 

  aNewPNJ.final_defense = aNewPNJ.defense
  aNewPNJ.final_goal    = aNewPNJ.goal

  -- roll a D20
  aNewPNJ.roll	= Roll.new(
    aNewPNJ.final_goal,   -- current goal
    nil, 		  -- no target yet, so no defense to pass
    aNewPNJ.dmg 	  -- weapon's damage
    )			  -- dice roll for this round

  return aNewPNJ
  
  end 

-- GUI function: set the color for the ith-line ( = ith PNJ)
function updateLineColor( i )

  PNJtext[i].init.color 			= color.darkblue
  PNJtext[i].def.color 				= color.darkblue

  if not PNJTable[i].PJ then
    if not PNJTable[i].roll:isSuccess() then 
      PNJtext[i].roll.color 			= color.red
      PNJtext[i].dmg.color 			= color.red
    elseif not PNJTable[i].roll:isPassDefense() then
      PNJtext[i].roll.color 			= color.orange
      PNJtext[i].dmg.color 			= color.orange
    else 
      PNJtext[i].roll.color 			= color.darkgreen
      PNJtext[i].dmg.color 			= color.darkgreen
    end
  else
    PNJtext[i].roll.color 			= color.purple
    PNJtext[i].dmg.color 			= color.purple
  end

  if (PNJTable[i].done) then
    PNJtext[i].id.color 			= color.masked
    PNJtext[i].class.color 			= color.masked
    PNJtext[i].endfordexfight.color 		= color.masked
    PNJtext[i].weapon.color 			= color.masked
    PNJtext[i].goal.color 			= color.masked
    PNJtext[i].armor.color 			= color.masked
    PNJtext[i].roll.color 			= color.masked
    PNJtext[i].dmg.color 			= color.masked
  elseif PNJTable[i].PJ then
    PNJtext[i].id.color 			= color.purple
    PNJtext[i].class.color 			= color.purple
    PNJtext[i].endfordexfight.color 		= color.purple
    PNJtext[i].weapon.color 			= color.purple
    PNJtext[i].goal.color 			= color.purple
    PNJtext[i].armor.color 			= color.purple
  else
    PNJtext[i].id.color 			= color.black
    PNJtext[i].class.color 			= color.black
    PNJtext[i].endfordexfight.color 		= color.black
    PNJtext[i].weapon.color 			= color.black
    PNJtext[i].goal.color 			= color.black
    PNJtext[i].armor.color 			= color.black
  end
end


-- set the target of i to j (i attacks j)
-- then update roll results accordingly (but does not reroll)
function updateTargetByArrow( i, j )

  -- set new target value
  if PNJTable[i].target == PNJTable[j].id then return end -- no change in target, do nothing
  
  -- set new target
  PNJTable[i].target = PNJTable[j].id
  
  -- remove i as attacker of anybody else
  PNJTable[j].attackers[ PNJTable[i].id ] = true
  for k=1,PNJnum-1 do
    if k ~= j then PNJTable[k].attackers[ PNJTable[i].id ] = false end
  end
  
  -- determine new success & damage
  -- only needed if:
  -- a) the character is a PNJ (we do not roll for PJ)
  -- b) his target was modified actually...
    local defense =  PNJTable[ j ].final_defense
    
    PNJTable[i].roll:changeDefense( defense )
    
    -- display, with proper color	
    PNJtext[i].roll.text 		= PNJTable[i].roll:getRoll()
    PNJtext[i].dmg.text2 		= PNJTable[i].roll:getVPText()
    PNJtext[i].dmg.text3 		= PNJTable[i].roll:getDamageText()

    updateLineColor(i)

    lastFocus = focus
    focus = i
    focusAttackers = PNJTable[i].attackers
    focusTarget = PNJTable[i].target
    
end


-- For an opponent (at index k) attacking a PJ (at index i), return
-- an "average touch" value ( a number of hits ) which is an average
-- number of damage points weighted with an average probability to hit
-- in this round
function averageTouch( i, k )
  if PNJTable[k].PJ then return 0 end -- we compute only for PNJ
  local dicemin = PNJTable[i].final_defense*2 - 1
  if dicemin < 0 then dicemin = 0 end
  local dicemax = PNJTable[k].final_goal
  local diceinterval = dicemax - dicemin
  if diceinterval < 0 then diceinterval = 0 end
  local chanceToTouch = diceinterval / 20 
  local damage = PNJTable[k].dmg + (diceinterval / 2)
  return chanceToTouch * (damage - PNJTable[i].armor) * (2/3)
  end

-- the dangerosity, for a PJ at index i, is an average calculation
-- based on its current hits and values of its opponents, which
-- represents an estimated (and averaged) number of rounds before dying.
-- Return the dangerosity value (an integer), or -1 if cannot be computed 
-- (eg. no opponent )
function computeDangerosity( i )
  local potentialTouch = 0
  for k,v in pairs(PNJTable[i].attackers) do
    if v then
      local index = findPNJ( k )
      if index then potentialTouch = potentialTouch + averageTouch( i , index ) end
    end
  end
  if potentialTouch ~= 0 then return math.ceil( PNJTable[i].hits / potentialTouch ) else return -1 end
  end

-- compute dangerosity for the whole group
function computeGlobalDangerosity()
  local potentialTouch = 0
  local hits = 0
  for i=1,PNJnum-1 do
   if PNJTable[i].PJ then
    hits = hits + PNJTable[i].hits
    for k,v in pairs(PNJTable[i].attackers) do
     if v then
      local index = findPNJ( k )
      if index then potentialTouch = potentialTouch + averageTouch( i , index ) end
     end
    end
   end
  end
  if potentialTouch ~= 0 then return math.ceil( hits / potentialTouch ) else return -1 end
  end

-- add n to the current defense malus of the i-th character (n can be positive or negative)
-- set to m the defense stance malus of the i-th character. If m is nil, does not alter the current stance malus
-- This will result in 2 effects:
-- a) alter the current total DEFENSE of the character
-- b) if another character is targeting this one, then modify damage roll result accordingly
function changeDefense( i, n, m )

  -- lower defense
  PNJTable[i].defmalus = PNJTable[i].defmalus + n
  if m then PNJTable[i].defstancemalus = m end
  PNJTable[i].final_defense = PNJTable[i].defense + PNJTable[i].defmalus + PNJTable[i].defstancemalus;
  PNJtext[i].def.text = PNJTable[i].final_defense; 

  -- check for potential attacking characters, who have not played yet in the round   
  for j=1,PNJnum-1 do

    if not PNJTable[j].done then

      if PNJTable[j].target == PNJTable[i].id then

        -- determine new success & damage
        
        PNJTable[j].roll:changeDefense( PNJTable[i].final_defense )
        
        -- display, with proper color	
        PNJtext[j].roll.text 		= PNJTable[j].roll:getRoll()
        PNJtext[j].dmg.text2 		= PNJTable[j].roll:getVPText()
        PNJtext[j].dmg.text3 		= PNJTable[j].roll:getDamageText()

        updateLineColor(j)

      end
    end

  end

end

-- create and return the PNJ list GUI frame 
-- (with blank values at that time)
function createPNJGUIFrame()

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
      yui.Text({text="OPPONENTS", w=40, bold=1, size=size}),
    }) 

  for i=1,PNJmax do
    t[i+1] = 
    yui.Flow({ name="PNJ"..i,

        yui.HorizontalSpacing({w=10}),
        yui.Checkbox({name = "done", text = '', w = 30, 
            onClick = function(self) 
              if (PNJTable[i]) then 
                PNJTable[i].done = self.checkbox.checked; 
                updateLineColor(i)
                checkForNextRound() 
              end  
            end}),

        yui.Text({name="id",text="", w=35, bold=1, size=size, center = 1 }),
        yui.Text({name="class",text="", w=width*2.5, bold=1, size=size, center=false}),
        yui.Text({name="init",text="", w=40, bold=1, size=size, center = 1, color = color.darkblue}),

        yui.Button({name="initm", text = '-', size=size-4,
            onClick = function(self) 
              if (i>=PNJnum) then return end
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
              if (i>=PNJnum) then return end
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
        yui.Text({name="roll",text="", w=width-20, bold=1, size=size+4, center=1, color = color.darkblue}),
        yui.Text({name="dmg",text="", text2 = "", text3 = "", w=width+25, bold=1, size=size+4, center = 1}),

        yui.Text({name="def", text="", w=40, bold=1, size=size+4, color = color.darkblue , center = 1}),

        yui.Button({name="minusd", text = '-', size=size,
            onClick = function(self) 
              if (i>=PNJnum) then return end
              if (PNJTable[i].is_dead) then return end
              changeDefense(i,-1,nil)
            end}),

        yui.Text({name="armor",text="", w=width, bold=1, size=size, center = 1}),
        yui.Text({name="hits", text="", w=40, bold=1, size=size+8, color = color.red, center = 1}),

        yui.Button({name="minus", text = '-1', size=size-2,
            onClick = function(self) 
              if (i>=PNJnum) then return end
              if (PNJTable[i].is_dead) then return end
              PNJTable[i].hits = PNJTable[i].hits - 1
              -- remove DEF if allowed
              if PNJTable[i].acceptDefLoss then
                changeDefense(i,-1,nil)
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
                checkForNextRound()
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
              if (i>=PNJnum) then return end
              if (PNJTable[i].is_dead) then return end
              -- remove DEF if allowed
              if PNJTable[i].acceptDefLoss then
                changeDefense(i,-1,nil)
                PNJTable[i].lasthit = 0
                PNJTable[i].acceptDefLoss = false
              end
              PNJTable[i].final_goal = PNJTable[i].goal + PNJTable[i].malus + PNJTable[i].goalstancebonus
            end}),

        yui.HorizontalSpacing({w=3}),
        yui.Button({name="kill", text = 'kill', size=size-2, 
            onClick = function(self)
              if (i>=PNJnum) then return end
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
              checkForNextRound()
            end }),

        yui.HorizontalSpacing({w=12}),
        yui.Text({name="stance",text="", w=100, size=size, center = 1}),
        yui.Button({name="agressive", text = 'A', size=size,
            onClick = function(self)
              if (i>=PNJnum) then return end
              if (PNJTable[i].is_dead) then return end
              PNJTable[i].goalstancebonus = 3;
              PNJTable[i].final_goal = PNJTable[i].goal + PNJTable[i].malus + PNJTable[i].goalstancebonus;
              changeDefense(i,0,-2)
              PNJTable[i].stance = "agress."
              self.parent.stance.text = "agress."; 
              self.parent.def.text = PNJTable[i].final_defense; 
              self.parent.goal.text = PNJTable[i].final_goal; 
              -- if PNJ has not played yet, reroll
              if not PNJTable[i].done then reroll(i) end
            end }),

        yui.HorizontalSpacing({w=3}),
        yui.Button({name="neutral", text = 'N', size=size,
            onClick = function(self)
              if (i>=PNJnum) then return end
              if (PNJTable[i].is_dead) then return end
              PNJTable[i].goalstancebonus = 0;
              PNJTable[i].final_goal = PNJTable[i].goal + PNJTable[i].malus + PNJTable[i].goalstancebonus;
              changeDefense(i,0,0)
              PNJTable[i].stance = "neutral"
              self.parent.stance.text = "neutral" 
              self.parent.def.text = PNJTable[i].final_defense; 
              self.parent.goal.text = PNJTable[i].final_goal; 
              -- if PNJ has not played yet, reroll
              if not PNJTable[i].done then reroll(i) end
            end }),

        yui.HorizontalSpacing({w=3}),
        yui.Button({name="defense", text = 'D', size=size,
            onClick = function(self)
              if (i>=PNJnum) then return end
              if (PNJTable[i].is_dead) then return end
              PNJTable[i].goalstancebonus = -3;
              PNJTable[i].final_goal = PNJTable[i].goal + PNJTable[i].malus + PNJTable[i].goalstancebonus;
              changeDefense(i,0,2)
              PNJTable[i].stance = "defense"
              self.parent.stance.text = "defense" 
              self.parent.def.text = PNJTable[i].final_defense; 
              self.parent.goal.text = PNJTable[i].final_goal; 
              -- if PNJ has not played yet, reroll
              if not PNJTable[i].done then reroll(i) end
            end }),

        yui.HorizontalSpacing({w=10})
        
      })
    PNJtext[i] = t[i+1] 
  end 

  return yui.Stack(t)
end

-- return an iterator which generates new unique ID, 
-- from "A", "B" ... thru "Z", then "AA", "AB" etc.
function UIDiterator() 
  local UID = ""
  local incrementAlphaID = function ()
    if UID == "" then UID = "A" return UID end
    local head=UID:sub( 1, UID:len() - 1)
    local tail=UID:byte( UID:len() )
    local id
    if (tail == 90) then 
	local u = UIDiterator()
	id = u(head) .. "A" 
    else 
	id = head .. string.char(tail+1) 
    end
    UID = id
    return UID
    end
  return incrementAlphaID 
  end

-- create and store a new PNJ in PNJTable{}, based on a given class,
-- return true if a new PNJ was actually generated, 
-- false otherwise (because limit is reached).
--
-- If a PNJ with same class was already generated before, then keeps
-- the same INITIATIVE value (so all PNJs with same class are sorted
-- together)
--
-- The newly created PNJ is stored at the end of the PNJTable{} for
-- the moment
function generateNewPNJ(current_class)

  -- cannot generate too many PNJ...
  if (PNJnum > PNJmax) then return false end

  -- generate a new one, at current index, with new ID
  PNJTable[PNJnum] = PNJConstructor( templateArray[current_class] )

  -- display it's class and INIT value (rest will be displayed when start button is pressed)
  local pnj = PNJTable[PNJnum]
  PNJtext[PNJnum].class.text = current_class;

  if (pnj.PJ) then

    pnj.final_initiative = pnj.initiative;
    PNJtext[PNJnum].init.text  = pnj.final_initiative;

  else

    -- set a default image
    pnj.snapshot = defaultPawnSnapshot

    -- check if same class has already been generated before. If so, take same initiative value
    -- otherwise, assign a new value (common to the whole class)
    -- the new value is INITIATIVE + 1D6
    local found = false
    for i=1,PNJnum-1 do
      if (PNJTable[i].class == current_class) then 
        found = true; 
        PNJtext[PNJnum].init.text = PNJtext[i].init.text; 
        pnj.final_initiative = PNJTable[i].final_initiative
      end
    end
    if not found then
      math.randomseed( os.time() )
      -- small trick: we do not add 1d6, but 1d6 plus a fraction between 0-1
      -- and we always remove this fraction (math.floor) when we display the value
      -- In this way, 2 different classes with same (apparent) initiative are sorted nicely, and not mixed
      pnj.final_initiative = math.random(pnj.initiative + 1, pnj.initiative + 6) + math.random()
      PNJtext[PNJnum].init.text = math.floor( pnj.final_initiative )
    end
  end

  -- shift to next slot
  PNJnum = PNJnum + 1

  return true
end


-- The PNJ are not displayed in the order they were generated: they are always 
-- sorted first by descending initiative value, then ascending ID value.
-- After a PNJ generation, this function sorts the PNJTable{} properly, then
-- re-print the GUI PNJ list completely.
-- Dead PNJs are not removed, and are still sorted and displayed
-- in the slot they were when alive.
-- returns nothing.
function sortAndDisplayPNJ()

  -- sort PNJ by descending initiative value, then ascending ID value
  table.sort( PNJTable, 
    function (a,b)
      if (a.final_initiative ~= b.final_initiative) then return (a.final_initiative > b.final_initiative) 
      else return (a.id < b.id) end
    end)

  -- then display PNJ table completely	
  for i=1,PNJmax do  

    if (i>=PNJnum) then

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
        updateLineColor(i)

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
    lastFocus 		= focus
    focus     		= nil
    focusTarget   	= nil
    focusAttackers  	= {}

  end 

end

-- remove dead PNJs from the PNJTable{}, but keeps all other PNJs
-- in the same order. Reduces PNJnum index value accordingly.
-- return true if a dead PNJ was actually removed, false if none was found.
-- Does not re-print the PNJ list on the screen. 
function removeDeadPNJ()

  local has_removed =  false
  local a_change_occured = true -- a priori

  while (a_change_occured) do
    a_change_occured = false -- might change below
    local i = 1
    while (PNJTable[i]) do
      if PNJTable[i].is_dead then
        
        -- we are about to remove a PNJ. If this PNJ is currently a target, or attacking someone,
        -- cleanup these tables first
        -- FIXME
        
        a_change_occured = true
        has_removed = true
        local j=i+1
        while PNJTable[j] do
          -- erase PNJ with the next one in the list
          PNJTable[j-1] = PNJTable[j]
          j = j + 1
        end
        PNJnum = PNJnum - 1
        PNJTable[PNJnum] = nil
      end
      i = i + 1
    end
  end
  thereIsDead = false
  return has_removed
end

-- Check if all PNJs have played (the "done" checkbox is checked for all, 
-- including dead PNJs as well)
-- If so, calls the nextRound() function.
-- Return true or false depending on what was done 
function checkForNextRound()
  	local goNextRound = true -- a priori, might change below
  	for i=1,PNJnum-1 do if not PNJTable[i].done then goNextRound = false end end
  	nextFlash = goNextRound
  	return goNextRound
	end

-- roll a d20 dice for the ith-PNJ and display the result in the grid
function reroll(i)

    -- do not roll for PJs....
    if PNJTable[i].PJ then 
    PNJtext[i].roll.text 	= ""
    PNJtext[i].dmg.text2 	= ""
    PNJtext[i].dmg.text3 	= ""
    updateLineColor(i)
    return 
    end

    -- get defense of the target, if a target was selected
    local defense = nil
    local index = findPNJ( PNJTable[i].target )
    if index then defense = PNJTable[ index ].final_defense end

    -- roll D20
    PNJTable[i].roll = Roll.new( PNJTable[i].final_goal, defense, PNJTable[i].dmg )
    
    -- display it, with proper color	
    PNJtext[i].roll.text 		= PNJTable[i].roll:getRoll()
    PNJtext[i].dmg.text2 		= PNJTable[i].roll:getVPText()
    PNJtext[i].dmg.text3 		= PNJTable[i].roll:getDamageText()
    updateLineColor(i)
  
    end


-- Increase and display round number, reset all "done" checkboxes (except for
-- dead PNJs which are considered as "done" by default), and reset DEFENSE values. 
-- Returns nothing.
function nextRound()

    math.randomseed( os.time() )

    -- increase round
    roundNumber = roundNumber + 1
    view.s.t.round.text = tostring(roundNumber)
    view.s.t.round.color= color.red

    -- set timer
    nextFlash = false
    roundTimer = 0
    newRound = true

    -- reset defense & done checkbox
    for i=1,PNJnum-1 do

      if (not PNJTable[i].is_dead) then

        PNJTable[i].done = false
        PNJtext[i].done.checkbox.reset = true

        PNJTable[i].defmalus = 0
        PNJTable[i].final_defense = PNJTable[i].defense + PNJTable[i].defstancemalus
        PNJtext[i].def.text = PNJTable[i].final_defense;

        if (not PNJTable[i].PJ) then reroll (i) end

      else

        PNJTable[i].done = true 				-- a dead character is done
        PNJtext[i].done.checkbox.set = true

      end

      updateLineColor(i)

    end

    end

-- create one instance of each PJ
function createPJ()

    for classname,t in pairs(templateArray) do
      if t.PJ then generateNewPNJ(classname) end
    end

    sortAndDisplayPNJ()

    end

