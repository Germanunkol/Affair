local BASE = (...):match("(.-)[^%.]+$")

local Server = require( BASE .. "server" )
local Client = require( BASE .. "client" )

local network = {}
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

local PORT = 3410

local server = nil
local client = nil

function network:startServer( maxNumberOfPlayers, port, pingTime )
	local createServer = function()
			return Server:new( maxNumberOfPlayers, port or PORT, pingTime )
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

	print( "[NET] Connecting to:", address, authMsg)

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
	if self.serverlistRemote.thread then
		local err = self.serverlistRemote.thread:getError()
		if err then
			print("THREAD ERROR: " .. err)
			self.serverlistRemote.thread = nil
		end
		local msg = self.serverlistRemote.cout:pop()
		if msg then
			if msg == "End" then
				self.serverlistLocal.thread = nil
			else
				local address, port, info = msg:match("(.*):(%S*)%s(.*)")
				print("Server found at:\n" ..
					"\tAddress: " .. address .. "\n" ..
					"\tPort: " .. port .. "\n" ..
					"\tInfo: " .. info)
			end

		end
	end
	if self.serverlistLocal.thread then
		local err = self.serverlistLocal.thread:getError()
		if err then
			print("THREAD ERROR: " .. err)
			self.serverlistLocal.thread = nil
		end
		local msg = self.serverlistLocal.cout:pop()
		if msg then
			if msg == "End" then
				self.serverlistLocal.thread = nil
			else
				local address, port, info = msg:match("(.*):(%S*)%s(.*)")
				print("Server found at:\n",
					"\tAddress: " .. address .. "\n" ..
					"\tPort: " .. port .. "\n" ..
					"\tInfo: " .. info)
			end

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
		url = url:match("(.*)/*")
		self.serverlistRemote.url = url .. "/getList.php"
		print("getting from url:", self.serverlistRemote.url)
	end
	
	local t = love.thread.newThread( BASE .. "serverlist/getList.lua" )
	local cin = love.thread.newChannel()
	local cout = love.thread.newChannel()

	self.serverlistRemote.thread = t
	self.serverlistRemote.cout = cout

	t:start( cout, self.serverlistRemote.url, self.serverlistRemote.id )
end

function network:requestServerListLAN()
	
end

return network
