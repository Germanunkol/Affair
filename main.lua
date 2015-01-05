
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
local PORT = 3412				-- The port which might need to be forwarded
local ADDRESS = "localhost"		-- Fallback address to connect client to

local MAIN_SERVER_ADDRESS = "http://germanunkol.de/test/Affair/"

local buttons = {}

local TITLE = "Love Affair"
local ERROR_MSG = ""
local ERROR_TIMER = 0

function love.load( args )

	local startingClient = false
	local startingServer = false
	local addressFound = false
	local serverlist = false
	for k, v in ipairs( args ) do
		if v == "--client" then
			startingClient = true
			if args[k+1] then
				addressFound = true
				ADDRESS = args[k+1]
			else
				serverlist = true
			end
		end
		if v == "--server" then
			startingServer = true
		end
		if v == "--list" then
			serverlist = true
		end
		if v == "--help" then
			printHelp()
			love.event.quit()
			return
		end
	end

	if not startingServer and not startingClient and not serverlist then
		printHelp()
		love.event.quit()
		return
	end
	
	if startingServer then
		addressFound = true
		ADDRESS = 'localhost'
		startServer()
	end
	if startingClient and addressFound then
		startClient()
	end

	if serverlist and not addressFound then
		TITLE = "Server List"
		requestServerLists()
	end
end

function requestServerLists()
	-- reset any already loaded lists:
	buttons = {}

	-- Set callbacks for remote server list:
	network.callbacks.newServerEntryRemote = newServerEntryRemote
	network.callbacks.finishedServerlistRemote = finishedServerlistRemote

	-- Set callback for LAN server list:
	network.callbacks.newServerEntryLocal = newServerEntryLocal

	-- Request server lists ("ExampleServer is the name of the game used on the server
	-- for advertising):
	network:requestServerList( "ExampleServer", MAIN_SERVER_ADDRESS )
	network:requestServerListLAN( "ExampleServer" )
end

function love.quit()
	print("Closing")
	if client then
		client:close()
	end
	if server then
		server:close()
	end
end

function printHelp()
	print("Usage:\n\tStart Server:\n\t\tlove . --server\n\n\tStart Client:\n\t\tlove . --client [ADDRESS]\n\t\t(Omit ADDRESS to load list of servers)\n")
end

function love.update( dt )
	network:update( dt )
	ERROR_TIMER = ERROR_TIMER - dt
end

function startServer()
	server, err = network:startServer( NUMBER_OF_PLAYERS, PORT )

	if server then
		setServerCallbacks()
		server:advertise( "Players:0", "ExampleServer", MAIN_SERVER_ADDRESS )
		TITLE = "Server @ Port " .. PORT
	else
		print("Error starting server:", err)
		love.event.quit()
	end

end

function startClient()
	client, err = network:startClient( ADDRESS, "Anonymous", PORT )
	
	if client then
		setClientCallbacks()
		if server then
			TITLE = "Server + Client: Connected to " .. ADDRESS .. ", Port: " .. PORT
		else
			TITLE = "Client: Connected to " .. ADDRESS .. ": Port: " .. PORT
		end
	else
		print("Error connecting client:", err)
		love.event.quit()
	end
end

function setServerCallbacks()
	server.callbacks.userFullyConnected = connected
	server.callbacks.disconnectedUser = disconnected
	server.callbacks.advertisement = advertisementCallback
end

function setClientCallbacks()

end

function connected()
	local players,numPlayers = network:getUsers()
	-- Only update the data field in the advertisement, leave the id and URL the same:
	server:advertise( "Players:" .. numPlayers )
	print("Connected.", players, numPlayers)
end
function disconnected()
	local players,numPlayers = network:getUsers()
	-- Only update the data field in the advertisement, leave the id and URL the same:
	server:advertise( "Players:" .. #players - 1 )
end


function newServerEntryRemote( entry )
	print("Server found at:\n" ..
		"\tAddress: " .. entry.address .. "\n" ..
		"\tPort: " .. entry.port .. "\n" ..
		"\tInfo: " .. entry.info)

	local list = network:getServerListRemote()

	-- Create new button:
	local b = {
		x = 50, y = 62 + 20*(#list - 1),
		w = love.graphics.getWidth() - 100,
		h = 18,
		text = entry.address .. "\t" .. entry.port .. "\t" .. entry.info,
		event = function() chooseServer( entry ) end
	}
	table.insert( buttons, b )
end

function newServerEntryLocal( entry )
	print("Server found at (LAN):\n" ..
		"\tAddress: " .. entry.address .. "\n" ..
		"\tPort: " .. entry.port .. "\n" ..
		"\tInfo: " .. entry.info)

	local list = network:getServerListLocal()

	-- Create new button:
	local b = {
		x = 50, y = love.graphics.getHeight()/2 + 52 + 20*(#list - 1),
		w = love.graphics.getWidth() - 100,
		h = 18,
		text = entry.address .. "\t" .. entry.port .. "\t" .. entry.info,
		event = function() chooseServer( entry ) end
	}
	table.insert( buttons, b )
end


function chooseServer( serverEntry )
	for k, v in pairs(serverEntry) do
		print(k,v)
	end
	ADDRESS = serverEntry.address
	PORT = serverEntry.port
	startClient()
	if client then	-- success?
		buttons = {}
	end
end

function finishedServerlistRemote( list )
	print("Finished retreiving servers. Servers found:", #list )
end

function advertisementCallback( err )
	ERROR_MSG = err
	ERROR_TIMER = 10
end

function drawServerList()
	love.graphics.setColor( 255,255,255,50 )
	love.graphics.rectangle( "fill", 50, 40, love.graphics.getWidth() - 100, 20 )
	love.graphics.setColor( 255,255,255,255 )
	love.graphics.print( "Servers:", 55, 43 )

	love.graphics.setColor( 255,255,255,50 )
	love.graphics.rectangle( "fill", 50, love.graphics.getHeight()/2 + 30,
			love.graphics.getWidth() - 100, 20 )
	love.graphics.setColor( 255,255,255,255 )
	love.graphics.print( "Servers (LAN):", 55, love.graphics.getHeight()/2 + 33 )

	for k, b in pairs(buttons) do
		love.graphics.setColor( 255,255,255,25 )
		love.graphics.rectangle( "fill", b.x, b.y, b.w, b.h )
		love.graphics.setColor( 255,255,255,255 )
		love.graphics.print( b.text, b.x + 5, b.y + 3 )
	end
end

function drawPlayerList()

	love.graphics.setColor( 255,255,255,50 )
	love.graphics.rectangle( "fill", 50, 40, 250, 18 )
	love.graphics.setColor( 255,255,255,255 )
	love.graphics.print( "Players:", 55, 43 )

	local players = network:getUsers()

	if players then
		local y = 60
		for k, p in pairs( players ) do
			love.graphics.setColor( 255,255,255,25 )
			love.graphics.rectangle( "fill", 50, y, 250, 18 )
			love.graphics.setColor( 255,255,255,255 )
			love.graphics.print( p.id .. " " .. p.playerName .. " [" .. p.ping.pingReturnTime .. "ms]", 55, y + 3 )
			y = y + 20
		end
	end
end

function drawTitle()
	love.graphics.setColor( 255,128,64,100 )
	love.graphics.rectangle( "fill", 3, 3, love.graphics.getWidth()-6, 25 )
	love.graphics.setColor( 255,255,255,255 )
	love.graphics.printf( TITLE, 3, 10, love.graphics.getWidth()-6, "center" )

	if ERROR_TIMER > 0 then
		love.graphics.setColor( 255,64,32,100 )
		love.graphics.rectangle( "fill", 3, love.graphics.getHeight() - 28,
		love.graphics.getWidth()-6, 25 )
		love.graphics.setColor( 255,255,255,255 )
		love.graphics.printf( ERROR_MSG, 3, love.graphics.getHeight() - 21, love.graphics.getWidth()-6, "center" )
	end
end

function love.draw()
	if not client and not server then
		drawServerList()
	elseif client or server then
		drawPlayerList()
	end

	drawTitle()
end

function love.mousepressed( x, y, button )
	if not client and not server then
		for k, b in pairs( buttons ) do
			if b.x < x and b.y < y and b.x+b.w > x and b.y+b.h > y then
				b.event()
			end
		end
	end
end

function love.keypressed( key )
	if key == "f5" then
		if not client and not server then
			requestServerLists()
		end
	end
end
