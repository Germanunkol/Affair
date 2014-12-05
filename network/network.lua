
local _PATH = (...):match('^(.*[%./])[^%.%/]+$') or ''

local Server = require( "network/server" )
local Client = require( "network/client" )

local network = {}

local conn = nil
local connectionType = ""
local connected = false

local users = {}

local PORT = 3410

local server = nil
local client = nil

function network:startServer( maxNumberOfPlayers )
	server = Server:new( PORT, maxNumberOfPlayers )
	return server
end

function network:startClient( address, playername )

	if not address then
		print("No address found. Using default: 'localhost'")
		address = "localhost"
	end

	print( "Connecting to:", address )

	client = Client:new( address, PORT, playername )
	return client
end

function network:update( dt )
	if server then server:update( dt ) end
	if client then client:update( dt ) end
end

function network:getUsers()
	if client then
		return client:getUsers()
	end
	if server then
		return server:getUsers()
	end
end

function network:send( command, msg )
	if client then
		client:send( command, msg )
	end
end

return network
