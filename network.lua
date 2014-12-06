local _PATH = (...):match('^(.*)[%.%/][^%.%/]+$') or ''
package.path = package.path .. ";" .. _PATH .. "/?.lua"

_PATH = _PATH

local Server = require( "server" )
local Client = require( "client" )

local network = {}

local conn = nil
local connectionType = ""
local connected = false

local users = {}

local PORT = 3410

local server = nil
local client = nil

function network:startServer( maxNumberOfPlayers, port )
	server = Server:new( port or PORT, maxNumberOfPlayers )
	return server
end

function network:startClient( address, playername, port )

	if not address or #address == 0 then
		print("No address found. Using default: 'localhost'")
		address = "localhost"
	end

	print( "Connecting to:", address )

	client = Client:new( address, port or PORT, playername )
	return client
end

function network:closeConnection()
	print("Closing all connections.")
	if client then
		client:close()
	end
	if server then
		server:close()
	end
end

function network:update( dt )
	if server then
		-- If updating the server returns false, then
		-- the connection has been closed.
		if not server:update( dt ) then
			server = nil
			print( "CLOSED SERVER" )
		end
	end
	if client then
		-- If updating the client returns false, then
		-- the connection has been closed.
		if not client:update( dt ) then
			client = nil
			print( "CLOSED CLIENT" )
		end
	end
end

function network:getUsers()
	if client then
		return client:getUsers(), client:getNumUsers()
	end
	if server then
		return server:getUsers(), server:getNumUsers()
	end
end

function network:send( command, msg )
	if client then
		client:send( command, msg )
	end
end

return network
