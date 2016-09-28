local yui_path = (...):match('(.-)[^%.]+$')
local Object = require(yui_path .. 'UI.classic.classic')
local TextDouble = Object:extend('Text')

function TextDouble:new(yui, settings)
    self.yui = yui
    self.x = settings.x or 0 
    self.y = settings.y or 0
    self.center = settings.center 
    self.name = settings.name
    self.text = settings.text or ''
    self.text2 = settings.text2 or ''
    self.size = settings.size or 20
    self.bold = settings.bold
    self.semibold = settings.semibold
    self.color = settings.color or {222, 222, 222}
    
    if self.bold then self.font = love.graphics.newFont(self.yui.Theme.open_sans_bold, math.floor(self.size*0.7))
    elseif self.semibold then self.font = love.graphics.newFont(self.yui.Theme.open_sans_semibold, math.floor(self.size*0.7))
    else self.font = love.graphics.newFont(self.yui.Theme.open_sans_regular, math.floor(self.size*0.7)) end

    if self.bold then self.font2 = love.graphics.newFont(self.yui.Theme.open_sans_bold, math.floor(self.size*0.4))
    elseif self.semibold then self.font2 = love.graphics.newFont(self.yui.Theme.open_sans_semibold, math.floor(self.size*0.4))
    else self.font2 = love.graphics.newFont(self.yui.Theme.open_sans_regular, math.floor(self.size*0.4)) end

    self.w = settings.w or (self.font:getWidth(self.text) + self.size)
    self.h = self.font:getHeight() + math.floor(self.size*0.7)
end

function TextDouble:update(dt)

end

function TextDouble:draw()
    self.yui.Theme.TextDouble.draw(self)
end

return TextDouble
