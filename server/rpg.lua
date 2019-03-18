
local theme = require 'theme'

--
-- code related to the RPG itself (here, Fading Suns)
-- how do we roll dices, how to we inflict damages, etc.
--

-- 
-- required interface to be exposed : 
--
-- 	rpg.getNextUID()		returns string, unique ID for each new PJ or PNJ or monster...

 

-- array of PNJ templates (loaded from data file)
templateArray   = {}

local rpg = {}

-- unique ID for characters. Use getNextUID() to generate the next one
local UID = ""

-- load PNJ templates from data file, return an array of classes
-- argument is a table (list) of paths to try
function rpg.loadClasses( paths )

   local array = {}
   Class = function( t )
                if not t.class then error("need a class attribute (string value) for each class entry") end
                local already_exist = false
                if templateArray[t.class] then already_exist = true end
                templateArray[t.class] = t
                if not already_exist then
                        table.insert( array, t )
                end
                end

   -- try all files
   for x=1,#paths do
        local f = loadfile( paths[x] )
        if f then f() end
   end

   return array
   end

 -- Compute dices to roll when "roll attack" or "roll armor" is pressed
 -- Roll is made for the character with current focus, provided it is a PNJ and not a PJ
 -- If it is a PJ, the roll is made not for him, but for it's opponent, provided there is
 -- one and only one (otherwise, do nothing)
 -- Return nothing, but activate the corresponding draw flag and timer so it is used in
 -- draw()
 -- return the number of dices actually sent (may be zero)
 -- 
 function rpg.rollAttack( rollType )

	 local focus = layout.combatWindow.focus

         if not focus then return 0 end -- no one with focus, cannot roll

         local index = focus

         -- when a PJ is selected, we do not roll for him but for it's enemy, provided there is only one
         if (PNJTable[ index ].PJ) then
                 local count = 0
                 local oneid = nil
                 for k,v in pairs(PNJTable[index].attackers) do
                         if v then oneid = k; count = count + 1 end
                 end
                 if (count ~= 1) or (not oneid) then return 0 end
                 index = findPNJ(oneid)
                 -- index now points to the line we want
         end

         -- set global variable so we know if we must draw white or black dices
         diceKind = rollType

         -- how many of them ?
         local num
         if rollType == "attack" then
                 num = PNJTable[ index ].roll:getDamage()
	 	 drawDicesKind =  "d6"
         elseif rollType == "armor" then
                 num = PNJTable[ index ].armor
	 	 drawDicesKind =  "D6"
         end

         if num == 0 then return 0 end

	 launchDices(drawDicesKind,num)

	 return num

	 end

function launchDices( kind, num )

         math.randomseed( os.time() )

         -- prepare the dice box simulation
	if kind == "d6" or kind == "D6" then
		--box:set(10,10,5,20,0.8,2,0.01)
		box:set(10,10,5,300,0.8,2,0.01)
	elseif kind == "d20" then
		--box:set(10,10,4,100,0.8,2,0.01)
		box:set(10,10,4,500,0.9,2,0.001)
	end

         dice = {}
         for i=1,num do
		if kind == "d6" then
                 	table.insert(dice,
                 		{ star=newD6star(1.5):set({math.random(10),math.random(10),math.random(10)}, -- position
                                           {-math.random(8,40),-math.random(8,40),-10}, -- velocity
                                           {math.random(10),math.random(10),math.random(10)}), -- angular mvmt
                   	die=clone(d6,{material=light.plastic,color={81,0,255,255},text={255,255,255},shadow={20,0,0,190}}) })
		elseif kind == "D6" then
                 	table.insert(dice,
                 		{ star=newD6star(1.5):set({math.random(10),math.random(10),math.random(10)}, -- position
                                           {-math.random(8,40),-math.random(8,40),-10}, -- velocity
                                           {math.random(10),math.random(10),math.random(10)}), -- angular mvmt
                   	die=clone(d6,{material=light.plastic,color={55,55,255,255},text={255,255,255},shadow={20,0,0,190}}) })
		elseif kind == "d20" then
                 	table.insert(dice,
                 		{ star=newD20star(4):set({math.random(10),math.random(10),math.random(1)}, -- position
                                           {-math.random(30,60),-math.random(30,60),-10}, -- velocity
                                           {math.random(10),math.random(10),math.random(10)}), -- angular mvmt
                   	die=clone(d20,{material=light.plastic,color={81,0,255,255},text={255,255,255},shadow={20,0,0,190}}) })
		end
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
local Roll = {}
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

function rpg.getNextUID()
  function nextUID(uid) 

    if not uid or uid == "" then return "A" end

    local allZ = true -- to check below 
    local temp = ""
    for i=1,uid:len() do
	if uid:sub(i,i) ~= "Z" then allZ = false; break; else temp = temp .. "A" end  
    end
    if allZ then return "A" .. temp end

    local head=uid:sub( 1, uid:len() - 1)
    local tail=uid:byte( uid:len() )
    if tail == 90  then 
	-- last char is Z... need to propagate the increase
	return nextUID(head) .. "A"
    else 
	return head .. string.char(tail+1) 
    end

  end
  UID = nextUID(UID)
  return UID
end

-- return a new PNJ object, based on a given template. 
-- Give him a new unique ID 
local function PNJConstructor( template ) 

  aNewPNJ = {}

  aNewPNJ.id 		  = rpg.getNextUID()		-- unique id
  aNewPNJ.PJ 		  = template.PJ or false	-- is it a PJ or PNJ ?
  aNewPNJ.done		  = false 			-- has played this round ?
  aNewPNJ.onMap		  = false			-- is this character present as a Pawn on a map ? No a priori, may change later on
  aNewPNJ.is_dead         = false  			-- so far 
  aNewPNJ.snapshot	  = template.snapshot		-- image (and some other information) for the character 
  aNewPNJ.sizefactor	  = template.size or 1.0
  aNewPNJ.actions	  = 0

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

-- set the target of i to j (i attacks j)
-- then update roll results accordingly (but does not reroll)
function rpg.updateTargetByArrow( i, j )

  -- check that the characters have not been removed from the list at some point in time...
  if (not PNJTable[i]) or (not PNJTable[j]) then return end

  -- set new target value
  if PNJTable[i].target == PNJTable[j].id then return end -- no change in target, do nothing
  
  -- set new target
  PNJTable[i].target = PNJTable[j].id
  
  -- remove i as attacker of anybody else
  PNJTable[j].attackers[ PNJTable[i].id ] = true
  for k=1,#PNJTable do
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

    --updateLineColor(i)
    --[[
    lastFocus = focus
    focus = i
    focusAttackers = PNJTable[i].attackers
    focusTarget = PNJTable[i].target
    --]] 
end


-- For an opponent (at index k) attacking a PJ (at index i), return
-- an "average touch" value ( a number of hits ) which is an average
-- number of damage points weighted with an average probability to hit
-- in this round
function rpg.averageTouch( i, k )
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
function rpg.computeDangerosity( i )
  local potentialTouch = 0
  for k,v in pairs(PNJTable[i].attackers) do
    if v then
      local index = findPNJ( k )
      if index then potentialTouch = potentialTouch + rpg.averageTouch( i , index ) end
    end
  end
  if potentialTouch ~= 0 then return math.ceil( PNJTable[i].hits / potentialTouch ) else return -1 end
  end

-- compute dangerosity for the whole group
function rpg.computeGlobalDangerosity()
  local potentialTouch = 0
  local hits = 0
  for i=1,#PNJTable do
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
function rpg.changeDefense( i, n, m )

  -- lower defense
  PNJTable[i].defmalus = PNJTable[i].defmalus + n
  if m then PNJTable[i].defstancemalus = m end
  PNJTable[i].final_defense = PNJTable[i].defense + PNJTable[i].defmalus + PNJTable[i].defstancemalus;
  PNJtext[i].def.text = PNJTable[i].final_defense; 

  -- check for potential attacking characters, who have not played yet in the round   
  for j=1,#PNJTable do

    if not PNJTable[j].done then

      if PNJTable[j].target == PNJTable[i].id then

        -- determine new success & damage
        
        PNJTable[j].roll:changeDefense( PNJTable[i].final_defense )
        
        -- display, with proper color	
        PNJtext[j].roll.text 		= PNJTable[j].roll:getRoll()
        PNJtext[j].dmg.text2 		= PNJTable[j].roll:getVPText()
        PNJtext[j].dmg.text3 		= PNJTable[j].roll:getDamageText()

        layout.combatWindow:updateLineColor(j)

      end
    end

  end

end

-- create and store a new PNJ in PNJTable{}, based on a given class,
-- return the id of the new PNJ generated, nil otherwise (because limit is reached).
--
-- If a PNJ with same class was already generated before, then keeps
-- the same INITIATIVE value (so all PNJs with same class are sorted
-- together)
--
-- The newly created PNJ is stored at the end of the PNJTable{} for
-- the moment
function rpg.generateNewPNJ(current_class)

 io.write("generating " .. current_class .. "\n");

  -- cannot generate too many PNJ...
  if (#PNJTable >= PNJmax) then return nil end

  -- if PJ and exists already, do nothing
  if templateArray[current_class].PJ then
    for i=1,#PNJTable do
	if PNJTable[i].class == current_class then 
 		io.write(current_class .. " already exists\n");
		return 
	end
    end 
  end

  -- generate a new one, at current index, with new ID
  PNJTable[#PNJTable+1] = PNJConstructor( templateArray[current_class] )

  -- display it's class and INIT value (rest will be displayed when start button is pressed)
  local pnj = PNJTable[#PNJTable]
  PNJtext[#PNJTable].class.text = current_class;

  -- set a default image if needed
  if not pnj.snapshot then pnj.snapshot = defaultPawnSnapshot end

  if (pnj.PJ) then

    pnj.final_initiative = pnj.initiative;
    PNJtext[#PNJTable].init.text  = pnj.final_initiative;

  else

    -- check if same class has already been generated before. If so, take same initiative value
    -- otherwise, assign a new value (common to the whole class)
    -- the new value is INITIATIVE + 1D6
    local found = false
    for i=1,#PNJTable - 1 do
      if (PNJTable[i].class == current_class) then 
        found = true; 
        PNJtext[#PNJTable].init.text = PNJtext[i].init.text; 
        pnj.final_initiative = PNJTable[i].final_initiative
      end
    end
    if not found then
      math.randomseed( os.time() )
      -- small trick: we do not add 1d6, but 1d6 plus a fraction between 0-1
      -- and we always remove this fraction (math.floor) when we display the value
      -- In this way, 2 different classes with same (apparent) initiative are sorted nicely, and not mixed
      pnj.final_initiative = math.random(pnj.initiative + 1, pnj.initiative + 6) + math.random()
      PNJtext[#PNJTable].init.text = math.floor( pnj.final_initiative )
    end
  end

  layout.combatWindow:sortAndDisplayPNJ()

  return pnj.id 
end


-- remove dead PNJs from the PNJTable{}, but keeps all other PNJs
-- in the same order. 
-- return true if a dead PNJ was actually removed, false if none was found.
-- Does not re-print the PNJ list on the screen. 
function rpg.removeDeadPNJ()

  local has_removed =  false
  local initialSize = #PNJTable
  local new = {}
  for i=1,#PNJTable do if not PNJTable[i].is_dead then table.insert( new, PNJTable[i] ) end end
  PNJTable = new
  --thereIsDead = false
  return initialSize ~= #PNJTable 
end

-- Check if all PNJs have played (the "done" checkbox is checked for all, 
-- including dead PNJs as well)
-- If so, calls the nextRound() function.
-- Return true or false depending on what was done 
function rpg.checkForNextRound()
  	local goNextRound = true -- a priori, might change below
  	for i=1,#PNJTable do if not PNJTable[i].done then goNextRound = false end end
  	return goNextRound
	end

-- roll a d20 dice for the ith-PNJ and display the result in the grid
function rpg.reroll(i)

    -- do not roll for PJs....
    if PNJTable[i].PJ then 
    PNJtext[i].roll.text 	= ""
    PNJtext[i].dmg.text2 	= ""
    PNJtext[i].dmg.text3 	= ""
    --updateLineColor(i)
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
    --updateLineColor(i)
  
    end


-- create one instance of each PJ
function rpg.createPJ()

    --for classname,t in pairs(templateArray) do
    --  if t.PJ then rpg.generateNewPNJ(classname) end
    --end

    end

-- Hit the PNJ at index i
-- return a boolean true if dead...
function rpg.hitPNJ( i )
         if not i then return false end
         if not PNJTable[ i ] then return false end
         PNJTable[ i ].hits = PNJTable[ i ].hits - 1
	 --PNJtext[ i ].hits.text = PNJTable[ i ].hits
         if (PNJTable[ i ].hits <= 0) then
                PNJTable[ i ].is_dead = true
                PNJTable[ i ].hits = 0
	 	--PNJtext[ i ].hits.text = 0
		layout.combatWindow:sortAndDisplayPNJ()
                return true
         end
	 layout.combatWindow:sortAndDisplayPNJ()
         return false
 end

return rpg

