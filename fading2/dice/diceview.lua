
diceview={
  --yaw=1.2,
  --pitch=1.2,
  yaw=0,
  pitch=0,
  distance=20,
  focus=5

}
diceview.cos_pitch, diceview.sin_pitch=math.cos(diceview.pitch), math.sin(diceview.pitch)
diceview.cos_yaw, diceview.sin_yaw=math.cos(diceview.yaw), math.sin(diceview.yaw)

function diceview.raise(delta)
  diceview.pitch=math.bound(diceview.pitch-delta,0.1,1.5)
  diceview.cos_pitch,diceview.sin_pitch=math.cos(diceview.pitch), math.sin(diceview.pitch)
end
function diceview.turn(delta)
  diceview.yaw=diceview.yaw-delta
  diceview.cos_yaw,diceview.sin_yaw=math.cos(diceview.yaw), math.sin(diceview.yaw)
end
function diceview.move(delta)
  diceview.distance=math.bound(diceview.distance*delta,20,100)
end

function diceview.project(x,y,z)
  local v=diceview
  x,y= v.cos_yaw*x-v.sin_yaw*y, v.sin_yaw*x+v.cos_yaw*y
  y,z = v.cos_pitch*y-v.sin_pitch*z, v.sin_pitch*y+v.cos_pitch*z
  z = diceview.distance-z
  local p=diceview.focus/z
  if p<0 then p=1000 end
  return x*p, y*p, -z, p
end

function diceview.get()
  local v,x,y,z=diceview,0,0,diceview.distance
  y,z = v.cos_pitch*y+v.sin_pitch*z, -v.sin_pitch*y+v.cos_pitch*z
  x,y= v.cos_yaw*x+v.sin_yaw*y, -v.sin_yaw*x+v.cos_yaw*y
  return x,y,z
end
