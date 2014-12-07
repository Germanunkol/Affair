local _PATH = (...):match('^(.*)[%.%/][^%.%/]+$') or ''
package.path = package.path .. ";" .. _PATH .. "/?.lua"

local socket = require("socket")

local User = require( "user" )
local CMD = require( "commands" )

local Server = {}
Server.__index = Server

local userList = {}
local numberOfUsers = 0
local userListByName = {}

local partMessage = ""

local MAX_PLAYERS = 16

function Server:new( maxNumberOfPlayers, port )
	local o = {}
	setmetatable( o, self )

	print("Initialising Server...") o.conn = assert(socket.bind("*", port)) o.conn:settimeout(0)
	if o.conn then
		print("\t-> started.")
	end

	o.callbacks = {
		received = nil,
		receivedPlayername = nil,
		disconnectedUser = nil,
		authorize = nil,
		customDataChanged = nil,
		userFullyConnected = nil,
	}

	userList = {}
	userListByName = {}
	numberOfUsers = 0
	partMessage = ""

	MAX_PLAYERS = maxNumberOfPlayers or 16

	return o
end

function Server:update( dt )
	if self.conn then

		local newConnection = self.conn:accept()
		if newConnection then
			newConnection:settimeout(0)

			local id = findFreeID()
			local newUser = User:new( newConnection, "Unknown", id )

			userList[id] = newUser

			numberOfUsers = numberOfUsers + 1

			self:newUser( newUser )

			print( "Client attempting to connect", id )
		end

		for k, user in pairs(userList) do			

			local data, msg, partOfLine = user.connection:receive()
			if data then
				if #partMessage > 0 then
					data = partMessage .. data
					partMessage = ""
				end

				-- First letter stands for the command:
				command, content = string.match(data, "(.)(.*)")
				command = string.byte( command )

				self:received( command, content, user )
				
			else	-- if "data" is nil, then there was an error:
				
				if msg == "timeout" then	-- only part of the message could be received
					if #partOfLine > 0 then
						partMessage = partMessage .. partOfLine
					end
				elseif msg == "closed" then
					--broadcast("CHAT|[STAT]" .. clientList[k].playerName .. " left the game.")
					--if client.character then
						--broadcast("CHARACTERDEL|" .. client.playerName)
					--end
					numberOfUsers = numberOfUsers - 1

					self:disconnectedUser( user )
					
					userList[k] = nil
					if userListByName[ user.playerName ] then
						userListByName[ user.playerName ] = nil
					end
				else
					print("Err Received:", msg, data)
				end
			end
		end

		return true
	else
		return false
	end
end

function Server:received( command, msg, user )
	print( "server received:", command, msg )
	if command == CMD.PLAYERNAME then
		-- Check if there is another user with this name.
		-- If so, increase the number at the end of the name...
		while userListByName[ msg ] do
			-- Get a possible number at the end of the username:
			local base, num = msg:match( "(.+)([%d]+)$" )
			if num then
				num = tonumber(num) + 1
			else
				-- Start with 'name'2:
				base = msg
				num = 2
			end
			msg = base .. num
		end

		user:setPlayerName( msg )
		if self.callbacks.newPlayername then
			self.callbacks.newPlayername( user )
		end
		userListByName[ user.playerName ] = user

		-- Let user know about the (possibly corrected) username and his
		-- client id:
		self:send( CMD.PLAYERNAME, user.id .. "|" .. user.playerName, user )

		-- Let all users know about the new user...
		self:send( CMD.NEW_PLAYER, user.id .. "|" .. user.playerName )

		self:synchronizeUser( user )

	elseif command == CMD.USER_VALUE then
		local keyType, key, valueType, value = string.match( msg, "(.*)|(.*)|(.*)|(.*)" )
		key = stringToType( key, keyType )
		value = stringToType( value, valueType )
		user.customData[key] = value

		-- Let others know about this value:
		self:send( CMD.USER_VALUE, user.id .. "|" .. msg )

		if self.callbacks.customDataChanged then
			self.callback.customDataChanged( user, value, key )
		end

	elseif self.callbacks.received then
		-- If the command is not known, then send it on: 
		self.callbacks.received( command, msg, user )
	end
end

function Server:synchronizeUser( user )

	-- Synchronize: Send all other users to this user:
	for k, u in pairs( userList ) do
		if u.synchronized then
			self:send( CMD.NEW_PLAYER, u.id .. "|" .. u.playerName, user )

			-- Synchronize any custom data of all users:
			for key, value in pairs( u.customData )  do
				local keyType = type( key )
				local valueType = type( value )
				local msg = u.id .. "|" .. keyType .. "|" .. tostring(key) ..
					"|" .. valueType .. "|" .. tostring(value)
				self:send( CMD.USER_VALUE, msg, user )
			end
		end
	end

	-- Send this new user to the user as well (let him know about himself)
	self:send( CMD.NEW_PLAYER, user.id .. "|" .. user.playerName, user )

	if self.callbacks.synchronize then
		self.callbacks.synchronize( user )
	end

	user.synchronized = true

	-- Let the program know that this user is now considered fully synchronized
	if self.callbacks.userFullyConnected then
		self.callbacks.userFullyConnected( user )
	end

end

function Server:send( command, msg, user )
	-- Send to only one user:
	if user then
		user.connection:send( string.char(command) .. (msg or "") .. "\n" )
		return
	end

	-- If no user is given, broadcast to all.
	for k, u in pairs( userList ) do
		if u.connection and u.synchronized then
			u.connection:send( string.char(command) .. (msg or "") .. "\n" )
		end
	end
end

function Server:newUser( user )
	print("New Client! Number of Clients: " .. numberOfUsers )

	local authorized = true
	local reason = ""
	if self.callbacks.authorize then
		authorized, reason = self.callbacks.authorize( user )
	end

	if numberOfUsers > MAX_PLAYERS then
		authorized = false
		reason = "Server full!"
	end

	if authorized then
		self:send( CMD.AUTHORIZED, "true|" .. user.id, user )
		user.authorized = true
	else
		self:send( CMD.AUTHORIZED, "false|" .. reason, user )
		user.connection:shutdown()
	end
end

function Server:disconnectedUser( user )
	print("Client left. Clients: " .. numberOfUsers )

	-- If the other clients already know about this client,
	-- then tell them to delete him.
	if user.synchronized then
		self:send( CMD.PLAYER_LEFT, user.id )
	end
	
	if self.callbacks.disconnectedUser then
		self.callbacks.disconnectedUser( user )
	end
end

-- Find an empty slot in the user list:
function findFreeID()
	for k = 1, numberOfUsers + 1 do
		if not userList[k] then
			return k
		end
	end
end

function Server:getUsers()
	return userList
end
function Server:getNumUsers()
	return numberOfUsers
end

function Server:close()
	if self.conn then
		for k, u in pairs( userList ) do
			u.connection:shutdown()
		end
		self.conn:close()
	end
	self.conn = nil
end

function Server:setUserValue( user, key, value )

	user.customData[key] = value

	-- Broadcast to other users:
	local keyType = type( key )
	local valueType = type( value )
	self:send( CMD.USER_VALUE, user.id .. "|" ..  keyType .. "|" .. tostring(key) ..
			"|" .. valueType .. "|" .. tostring(value) )
end

return Server
