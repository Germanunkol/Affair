local menu = {}

function menu:init()
	local scr = ui.newScreen( "Lobby" )
	ui.setActiveScreen( "Lobby" )

	scr:addPanel( "menu panel"
end

function menu:update( dt )
end

function menu:draw()
end

function menu:keypressed( key )
end

function menu:mousepressed( button, x, y )
end

return menu
