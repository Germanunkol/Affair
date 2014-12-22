
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

local server = nil
local client = nil

local NUMBER_OF_PLAYERS = 16	-- Server should not allow more than 16 connections
local PORT = 3410				-- The port which might need to be forwarded
local PING_UPDATE_TIME = 5		-- Server pings clients every 5 seconds
local ADDRESS = "localhost"		-- Fallback address to connect client to

function love.load( args )

	local startingClient = false
	for k, v in ipairs( args ) do
		if v == "--client" then
			if args[k+1] then
				startingClient = true
				ADDRESS = args[k+1]
			end
		end
		if v == "--server" then
			startingServer = true
		end
		if v == "--help" then
			printHelp()
			love.event.quit()
			return
		end
	end

	if not startingServer and not startingClient then
		printHelp()
		love.event.quit()
		return
	end
	
	if startingServer then
		startServer()
	end
	if startingClient then
		startClient()
	end
end

function printHelp()
	print("Usage:\n\tStart Server:\n\t\tlove . --server\n\tStart Client:\n\t\tlove . --client [ADDRESS]\n\tExample:\n\t\tlove . --client 192.168.0.10")
end

function love.update( dt )
	network:update( dt )
end


function startServer()
	server, err = network:startServer( NUMBER_OF_PLAYERS, PORT, PING_UPDATE_TIME )

	if server then
		setServerCallbacks()
	else
		print("Error starting server:", err)
		love.event.quit()
	end
end

function startClient()
	client, err = network:startClient( ADDRESS, "", PORT )
	
	if client then
		setClientCallbacks()
	else
		print("Error connecting client:", err)
		love.event.quit()
	end
end

function setServerCallbacks()

end

function setClientCallbacks()

end


