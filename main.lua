
network = require( "network/network" )

function love.load( args )

	local server = false
	if args[2] ~= "server" and args[2] ~= "client" then
		print("Invalid mode, defaulting to server")
		server = true
	elseif args[2] == "server" then
		server = true
	end
	if server then
		network:startServer()
		network:startClient( 'localhost', "Germanunkol1" )
	else
		network:startClient( args[3], "Germanunkol2" )
	end
end

function love.update( dt )
	network:update( dt )
end

local text = ""

function love.keypressed( key )
	if key == "return" then
		network:sendtext( text )
		text = ""
	else
		text = text .. key
	end
end

function love.draw()
end
