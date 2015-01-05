local BASE = (...):match("(.-)[^%.]+$")

local Server = require( BASE .. "server" )
local Client = require( BASE .. "client" )

local requestLAN = require( BASE .. "serverlist/requestLAN" )

local network = {}
network.callbacks = {
	newServerEntryRemote = nil,
	finishedServerlistRemote = nil,
	newServerEntryLocal = nil,
}

-- A list containing the servers as retreived from the web server:
network.serverlistRemote = {
	thread = nil,
	entries = {},
}
-- A list containing servers in the local area network:
network.serverlistLocal = {
	thread = nil,
	entries = {},
}

local conn = nil
local connectionType = ""
local connected = false

local users = {}

local PORT = 3410	-- port used to send data (TCP)
local UDP_BROADCAST_PORT = 3410	-- port used to build up LAN sever list (UDP)

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

	-- Check for new incoming messages from the serverlist threads:
	if self.serverlistRemote.thread then
		-- Check for errors:
		local err = self.serverlistRemote.thread:getError()
		if err then
			print("THREAD ERROR: " .. err)
			self.serverlistRemote.thread = nil
		end
		-- Get any new messages:
		local msg = self.serverlistRemote.cout:pop()
		if msg then
			self:newServerListEntryRemote( msg )
		end
	end
	if self.serverlistLocal.receiving then
		self.serverlistLocal.receiving = true
		local ip, port, info = requestLAN:update( dt )
		if ip and port and info then
			self:newServerListEntryLocal( ip, port, info )
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

-- Start requesting the serverlist from a remote URL (a 'main server').
-- The main server must have the AffairMainServer scripts at path given by the URL.
-- This can also be called again to refresh the list. In this case, no id or url must be given.
function network:requestServerList( id, url )

	assert( self.serverlistRemote.id or id, "When calling requestServerList for the first time, a game-ID (Name of your game) must be given" )

	assert( self.serverlistRemote.url or url, "When calling requestServerList for the first time, a URL must be given" )
	
	if self.serverlistRemote.thread then
		self.serverlistRemote.thread = nil
	end
	if id then
		self.serverlistRemote.id = id
	end
	if url then
		url = url:match("(.-)/?$")
		self.serverlistRemote.url = url .. "/getList.php"
	end
	
	local t = love.thread.newThread( BASE .. "serverlist/getList.lua" )
	local cin = love.thread.newChannel()
	local cout = love.thread.newChannel()

	self.serverlistRemote.thread = t
	self.serverlistRemote.cout = cout
	self.serverlistRemote.entries = {}

	t:start( cout, self.serverlistRemote.url, self.serverlistRemote.id )
end

function network:requestServerListLAN( id, portUDP )
	assert( self.serverlistLocal.id or id, "When calling requestServerListLAN for the first time, a game-ID (Name of your game) must be given" )

	if id then
		self.serverlistLocal.id = id
	end

	self.serverlistLocal.entries = {}

	requestLAN:start( self.serverlistLocal.id, portUDP or UDP_BROADCAST_PORT )
	self.serverlistLocal.receiving = true
end

function network:stopRequestServerListLAN()
	requestLAN:stop()
	self.serverlistLocal.receiving = false
end

function network:newServerListEntryRemote( msg )
	if msg == "End" then
		self.serverlistRemote.thread = nil
		if self.callbacks.finishedServerlistRemote then
			self.callbacks.finishedServerlistRemote( self.serverlistRemote.entries )
		end
	else
		local address, port, info = msg:match("(.*):(%S*)%s(.*)")
		if address and port and info then
			print("Server found at:\n" ..
				"\tAddress: " .. address .. "\n" ..
				"\tPort: " .. port .. "\n" ..
				"\tInfo: " .. info)

			local e = {
				address = address,
				port = port,
				info = info,
			}
			table.insert( self.serverlistRemote.entries, e )
			if self.callbacks.newServerEntryRemote then
				self.callbacks.newServerEntryRemote( e )
			end
		end
	end
end

function network:getServerListRemote()
	return self.serverlistRemote.entries
end

function network:newServerListEntryLocal( ip, port, info )
	local e = {
		address = ip,
		port = tonumber(port),
		info = info,
	}
	table.insert( self.serverlistLocal.entries, e )
	if self.callbacks.newServerEntryLocal then
		self.callbacks.newServerEntryLocal( e )
	end
end

function network:getServerListLocal()
	return self.serverlistLocal.entries
end

return network
