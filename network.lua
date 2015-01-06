local BASE = (...):match("(.-)[^%.]+$")
local BASE_SLASH = BASE:sub(1,#BASE-1) .. "/"

local Server = require( BASE .. "server" )
local Client = require( BASE .. "client" )

-- Load advertising (serverlist) submodule
local advertise = require( BASE .. "advertise" )

local network = {}

network.advertise = advertise

local conn = nil
local connectionType = ""
local connected = false

local users = {}

local PORT = 3410	-- port used to send data (TCP)

local server = nil
local client = nil

function network:startServer( maxNumberOfPlayers, port, pingTime )
	local createServer = function()
			return Server:new( maxNumberOfPlayers, port or PORT, pingTime, UDP_BROADCAST_PORT )
	end

	success, server = pcall( createServer )
	local err = ""
	if not success then
		err = server
		server = nil
	end
	return server, err
end

function network:startClient( address, playername, port, authMsg )

	if not address or #address == 0 then
		print("[NET] No address found. Using default: 'localhost'")
		address = "localhost"
	end

	print( "[NET] Connecting to:", address, port, authMsg)

	local createClient = function()
		return Client:new( address, port or PORT, playername, authMsg )
	end

	success, client = pcall( createClient )
	local err = ""
	if not success then
		err = client
		client = nil
	end
	assert(client, "Could not connect." )
	return client, err
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

	advertise:update( dt )
end

function network:getUsers()
	if server then
		return server:getUsers(), server:getNumUsers()
	end
	if client then
		return client:getUsers(), client:getNumUsers()
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
