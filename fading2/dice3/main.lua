dbg={}

require"base"
require"loveplus"
require"vector"

require"render"
require"stars"
require"geometry"
require"view"
require"light"

require "default/config"

dice= {}
--[[
--  {
--    die=clone(d8,{material=light.metal,color={250,235,20},text={0,0,0},shadow={0,0,0,240}}),
--    star=newD8star():set({0,0,10},{-4,-2,0},{1,1,2})
--  },
  {
    star=newD6star(1.5):set({3,0,1},{ 2,0,8},{0,3,2}),
    die=clone(d6,{material=light.plastic,color={200,0,20,150},text={255,255,255},shadow={20,0,0,150}})
  },
  {
    star=newD6star(1.5):set({5,5,1},{ 1,1,8},{-3,3,2}),
    die=clone(d6,{material=light.plastic,color={200,0,20,150},text={255,255,255},shadow={20,0,0,150}})
  },
  {
    star=newD6star(1.5):set({0,2,1},{ 1,8,1},{3,3,2}),
    die=clone(d6,{material=light.plastic,color={200,0,20,150},text={255,255,255},shadow={20,0,0,150}})
  },
  {
    star=newD6star(1.5):set({5,10,2},{ 4,-20,8},{3,3,2}),
    die=clone(d6,{material=light.plastic,color={200,0,20,150},text={255,255,255},shadow={20,0,0,150}})
  },
  {
    star=newD6star(1.5):set({5,10,5},{ 14,-2,18},{1,3,2}),
    die=clone(d6,{material=light.plastic,color={200,0,20,150},text={255,255,255},shadow={20,0,0,150}})
  },
  {
    star=newD6star(1.5):set({5,4,0},{ 7,-2,8},{3,1,2}),
    die=clone(d6,{material=light.plastic,color={200,0,20,150},text={255,255,255},shadow={20,0,0,150}})
  },
  {
    star=newD6star(1.5):set({5,5,0},{ 9,4,8},{3,3,2}),
    die=clone(d6,{material=light.plastic,color={200,0,20,150},text={255,255,255},shadow={20,0,0,150}})
  },
  {
    star=newD6star(1.5):set({1,0,0},{ -9,-2,18},{3,3,2}),
    die=clone(d6,{material=light.plastic,color={200,0,20,150},text={255,255,255},shadow={20,0,0,150}})
  },
  {
    star=newD6star(1.5):set({5,6,1},{ -4,-2,8},{3,3,2}),
    die=clone(d6,{material=light.plastic,color={200,0,20,150},text={255,255,255},shadow={20,0,0,150}})
  },
  {
    star=newD6star(1.5):set({2,2,0},{ -1,-1,-1},{2,3,2}),
    die=clone(d6,{material=light.plastic,color={200,0,20,150},text={255,255,255},shadow={20,0,0,150}})
  },
  {
    star=newD6star(1.5):set({5,7,0},{ 0,-2,1},{4,3,2}),
    die=clone(d6,{material=light.plastic,color={200,0,20,150},text={255,255,255},shadow={20,0,0,150}})
  },
  {
    star=newD6star(1.5):set({0,10,0},{ 14,-2,5},{4,3,1}),
    die=clone(d6,{material=light.plastic,color={200,0,20,150},text={255,255,255},shadow={20,0,0,150}})
  },
  {
    star=newD6star(1.5):set({0,0,10},{ 4,7,-10},{1,1,2}),
    die=clone(d6,{material=light.plastic,color={200,0,20,150},text={255,255,255},shadow={20,0,0,150}})
  },
--  {
--    star=newD4star():set({0,0,10},{ 4,-2,0},{1,1,2}),
--    die=clone(d4,{material=light.plastic,color={0,0,250},text={255,255,255},shadow={0,0,0,240}})
--  }
}
--]]

function love.load()
  --feed the simulation
  box:set(10,10,10,10,0.7,0.7,0.01)
  ---round(0.2,dice[2].die,dice[2].star)

  math.randomseed( os.time() )

  for i=1,22 do
   table.insert(dice,{ star=newD6star(1.5):set({math.random(0,10),math.random(0,10),math.random(0,10)},{ math.random(0,10),math.random(0,10),math.random(0,10)},
			{math.random(0,5),math.random(0,5),math.random(0,5)}),
    		die=clone(d6,{material=light.plastic,color={200,0,20,150},text={255,255,255},shadow={20,0,0,150}}) })
  end

  for i=1,#dice do box[i]=dice[i].star end
end


function love.mousepressed(x,y,b)
  if b==1 and focused then 
    local impulse=focused.star.position-{view.get()}
    impulse[3]=0
    impulse=impulse:norm()*7
    focused.star:push(impulse,vector{0,0,1})
  end
  if b=='wu' then view.move(1.1) end
  if b=='wd' then view.move(0.91) end
end

function love.update(dt)
  dbg.fps=(dbg.fps or 100)*99/100 +0.01/dt
  local dx,dy=love.mouse.delta()
  if love.mouse.isDown(3) then 
    view.raise(dy/100)
    view.turn(dx/100)
  end
  
  if convert then 
    
    --get the dice
    local d={}
    for i=1,#dice do table.insert(d,{dice[i], view.project(unpack(dice[i].star.position))}) end
    table.sort(d,function(a,b) return a[4]>b[4] end)
    
    --get the one under focus
    local x,y=convert(love.mouse.getPosition())
    focused=false
    for i=1,#d do
      local dx,dy=x-d[i][2],y-d[i][3]
      local size=d[i][5]
      if math.abs(dx)<size and math.abs(dy)<size then
        focused=d[i][1]
        break
      end
    end
    light.follow(focused and focused.star,dt)
  end
  
  box:update(dt)
end


function love.draw()
  --use a coordinate system with 0,0 at the center
  --and an approximate width and height of 10
  local cx,cy=love.graphics.getWidth()/2,love.graphics.getHeight()/2
  local scale=cx/4
  
  love.graphics.push()
  love.graphics.translate(cx,cy)
  love.graphics.scale(scale)
  --convert=function(x,y) return (x-cx)/scale, (y-cy)/scale end --tarnslate mouse clicks into this world 
  
  --board
  --render.board(config.boardimage,config.boardlight)
  
  --shadows
  --for i=1,#dice do render.shadow(function(z,f) f() end, dice[i].die, dice[i].star) end
  --render.edgeboard()
  
  --dice
  render.clear()
  --render.bulb(render.zbuffer) --light source
  for i=1,#dice do render.die(render.zbuffer, dice[i].die, dice[i].star) end
  render.paint()

  love.graphics.pop()
  love.graphics.dbg()
end
