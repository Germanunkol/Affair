local BASE = (...):match("(.-)[^%.]+$")

local Server = require( BASE .. "server" )
local Client = require( BASE .. "client" )

local network = {}

local conn = nil
local connectionType = ""
local connected = false

local users = {}

local PORT = 3410

local server = nil
local client = nil

function network:startServer( maxNumberOfPlayers, port )
	server = Server:new( maxNumberOfPlayers, port or PORT )
	return server
end

function network:startClient( address, playername, port )

	if not address or #address == 0 then
		print("[NET] No address found. Using default: 'localhost'")
		address = "localhost"
	end

	print( "[NET] Connecting to:", address )

	client = Client:new( address, port or PORT, playername )
	assert(client, "Could not connect." )
	return client
end

function network:closeConnection()
	print("[NET] Closing all connections.")
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
		end
	end
	if client then
		-- If updating the client returns false, then
		-- the connection has been closed.
		if not client:update( dt ) then
			client = nil
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

--[[function network:send( command, msg )
	if client then
		client:send( command, msg )
	end
end]]

function stringToType( value, goalType )
	if goalType == "number" then
		return tonumber(value)
	elseif goalType == "boolean" then
		return value == "true" and true or false
	end
	-- if it was meant to be a string, return it as such:
	return value
end

return network
