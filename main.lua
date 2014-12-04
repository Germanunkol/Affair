
network = require( "network/network" )

local CMD = {
	CHAT = 128,
}

local chatLines = { "", "", "", "", "", "", "" }
local server = nil
local client = nil

function love.load( args )

	local startServer = false
	if args[2] ~= "server" and args[2] ~= "client" then
		print("Invalid mode, defaulting to server")
		startServer = true
	elseif args[2] == "server" then
		startServer = true
	end
	if startServer then
		server = network:startServer()
		client = network:startClient( 'localhost', "Germanunkol1" )

		-- set server callbacks:
		server.callbacks.received = serverReceived
		-- set client callbacks:
		client.callbacks.received = clientReceived
	else
		client = network:startClient( args[3], "Germanunkol2" )

		-- set client callbacks:
		client.callbacks.received = clientReceived
	end
end

function love.update( dt )
	network:update( dt )
end

local text = ""

function love.keypressed( key )
	if key == "return" then
		network:send( CMD.CHAT, text )
		text = ""
	else
		text = text .. key
	end
end

function love.draw()
	local users = network:getUsers()
	local x, y = 10, 10
	for k, u in pairs( users ) do
		love.graphics.print( u.playerName, x, y )
		y = y + 20
	end

	y = love.graphics.getHeight() - 10
	for k = 1, #chatLines do
		love.graphics.print( chatLines[k], x, y )
		y = y - 20
	end
end

function serverReceived( command, msg, user )
	if command == CMD.CHAT then
		-- broadcast chat messages on to all players
		server:send( command, user.playerName .. ": " .. msg )
	end
end

function clientReceived( command, msg )
	if command == CMD.CHAT then
		for k = 1, #chatLines-1 do
			chatLines[k] = chatLines[k+1]
		end
		chatLines[#chatLines] = msg
	end
end
