
network = require( "network" )

-- COMMANDs are used to identify messages.
-- Custom commands MUST be numbers between (including) 128 and 255.
-- Make sure these are the same on client and server.
-- Ideally, put them into a seperate file and include it from both client
-- and server. Here, I leave it in the main file for readability.
local COMMAND = {
	CHAT = 128,
	MAP = 129,
}

local chatLines = { "", "", "", "", "", "", "" }
local server = nil
local client = nil

local port = 3411

function love.load( args )

	local startServer = false
	if args[2] ~= "server" and args[2] ~= "client" then
		print("Invalid mode, defaulting to server")
		startServer = true
	elseif args[2] == "server" then
		startServer = true
	end
	if startServer then
		-- Start a server with a maximum of 16 users.
		server = network:startServer( 16, port )
		-- Connect to the server.
		client = network:startClient( 'localhost', "Germanunkol", port )

		-- set server callbacks:
		server.callbacks.received = serverReceived

		-- set client callbacks:
		client.callbacks.received = clientReceived
		client.callbacks.connected = connected
	else
		client = network:startClient( args[3], "Germanunkol", port )

		-- set client callbacks:
		client.callbacks.authorized = authorized
		client.callbacks.connected = connected
		client.callbacks.received = clientReceived
		client.callbacks.disconnected = disconnected
	end
end

function love.update( dt )
	network:update( dt )
end

local text = ""
local chatting = false

function love.keypressed( key )
	if key == "return" then
		if chatting and client then
			client:send( COMMAND.CHAT, text ).
			text = ""
			chatting = false
		else
			chatting = true
		end
	end
end

function love.textinput( letter )
	if chatting then
		text = text .. letter
	end
end

function love.draw()
	love.graphics.setColor( 255,255,255, 255 )
	local users = network:getUsers()
	if users then
		local x, y = 20, 10
		for k, u in pairs( users ) do
			love.graphics.print( u.playerName .. " [" .. u:getPing() .. " ms]", x, y )
			y = y + 20
		end

		y = love.graphics.getHeight() - 10
		for k = 1, #chatLines do
			love.graphics.print( chatLines[k], x, y )
			y = y - 20
		end
		if chatting then
			love.graphics.setColor( 128, 128, 128, 255 )
			love.graphics.print( "Enter text: " .. text, x - 5, y )
			y = y - 20
		end
	end
end

function serverReceived( command, msg, user )
	if command == COMMAND.CHAT then
		-- broadcast chat messages on to all players
		server:send( command, user.playerName .. ": " .. msg )
	end
end

function clientReceived( command, msg )
	if command == COMMAND.CHAT then
		for k = 1, #chatLines-1 do
			chatLines[k] = chatLines[k+1]
		end
		chatLines[#chatLines] = msg
	elseif command == COMMAND.MAP then
		-- Re-add line breaks which were removed for sending purposes:
		local map, count = msg:gsub( "|", "\n" )
		print( "Received map:\n" .. map .. "\nNumber of lines: " .. count .. "\nNumber of characters: " .. #map )
		client:send( 128, msg )
	end
end

function connected()
	print("\tsuccessfully connected.")
end
