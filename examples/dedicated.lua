-- This is a minimal example of how to set up a dedicated server.
-- In this context, dedicated means the server is run
-- a) headless (no Löve dependency)
-- b) in plain Lua.
-- Requirements: Luasocket and Lua must be installed

network = require( "../network" )
local server
local MAX_PLAYERS = 16
local PORT = 3410

-- COMMANDs are used to identify messages.
-- Custom commands MUST be numbers between (including) 128 and 255.
-- Make sure these are the same on client and server.
-- Ideally, put them into a seperate file and include it from both client
-- and server. Here, I leave it in the main file for readability.
local COMMAND = {
	CHAT = 128,
	MAP = 129,
}

local myMapString = ""

function startDedicatedServer()
	local success
	success, server = pcall( function()
		return network:startServer( MAX_PLAYERS, PORT )
	end)

	if success then
		-- set client callbacks:
		setServerCallbacks( server )
	else
		-- If I can't start a server for some reason, let user know and exit:
		print(server)
		os.exit()
	end
end

function connected( user )
	-- Called when new user has fully connected.
	print( user.playerName .. " has joined. (ID: " .. user.id .. ")" )
end
function disconnected( user )
	-- Called when user leaves.
	print( user.playerName .. " has has left. (ID: " .. user.id .. ")" )
end
function synchronize( user )
	-- Careful! The map includes line breaks -> so make sure to replace those!
	-- Remember never to send line breaks using this engine, they're used internally
	-- as delimiters.
	-- The map doesn't contain any pipe symbols, so it's save to replace "\n" with "|":
	local map = myMapString:gsub("\n", "|")
	-- Send the map to the new client
	server:send( COMMAND.MAP, map, user )
	print("sent map")
end
function authorize( user )
	-- Authorize everyone! We're a lövely community, after all, everyone is welcome!
	return true
end
function received( command, msg, user )
	-- If the user sends us some data, then just print it.
	print( user.playerName .. " sent: ", command, msg )

	-- NOTE: Usually, you would compare "command" to all the values in the COMMAND table, and
	-- then act accordingly:
	-- if command == COMMAND.
end

function setServerCallbacks( server )

	-- Called whenever one of the users is trying to connect:
	server.callbacks.authorize = authorized

	-- Called during connection process:
	server.callbacks.synchronize = synchronize

	-- Called when user has connected AND has been synchronized:
	server.callbacks.userFullyConnected = connected

	-- Called whenever one of the users sends data:
	server.callbacks.received = received

	-- Called whenever one of the users is disconnected
	server.callbacks.disconnectedUser = disconnected

end

-- Sleep time in second - use the socket library to make sure the 
-- sleep is a "non busy" sleep, meaning the CPU will NOT be busy during
-- the sleep.
function sleep( sec )
    socket.select(nil, nil, sec)
end

-- Fill the map string with something long for testing purposes:
for y = 1, 15000 do
	for x = 1, 30 do
		if math.random(10) == 1 then
			myMapString = myMapString .. math.random(9)
		else
			myMapString = myMapString .. "-"
		end
	end
	myMapString = myMapString .. "\n"
	if y % 1000 == 0 then
		print(y)
	end
end
print( "Map:\n" .. myMapString .. "\nNumber of characters: " .. #myMapString )

startDedicatedServer()

local time = socket.gettime()
local dt = 0
local t = 0
while true do
	network:update( dt )

	dt = socket.gettime() - time
	time = socket.gettime()

	-- This is important. Play with this value to fit your need.
	-- If you don't use this sleep command, the CPU will be used as much as possible, you'll probably run the game loop WAY more often than on the clients (who also require time to render the picture - something you don't need)
	sleep( 0.05 )
end
