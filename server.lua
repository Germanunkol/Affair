local BASE = (...):match("(.-)[^%.]+$")
local BASE_SLASH = BASE:sub(1,#BASE-1) .. "/"

local socket = require("socket")

local User = require( BASE .. "user" )
local CMD = require( BASE .. "commands" )

--local advertiseLAN = require( BASE_SLASH .. "serverlist/advertiseLAN" )

local utility = require( BASE .. "utility" )

local ADVERTISEMENT_UPDATE_TIME = 60

local Server = {}
Server.__index = Server

local userList = {}
local numberOfUsers = 0
local userListByName = {}
local authorizationTimeout = {}

local partMessage = ""
local messageLength = nil

local MAX_PLAYERS = 16

local AUTHORIZATION_TIMEOUT = 2

local PINGTIME = 5
local SYNCH_PINGS = true

function Server:new( maxNumberOfPlayers, port, pingTime, portUDP )
	local o = {}
	setmetatable( o, self )

	print("[NET] Initialising Server...")
	o.conn = assert(socket.bind("*", port))
	o.conn:settimeout(0)
	if o.conn then
		print("[NET]\t-> started.")
	end

	o.callbacks = {
		received = nil,
		disconnectedUser = nil,
		disconnectedUnsynchedUser = nil,
		authorize = nil,
		customDataChanged = nil,
		userFullyConnected = nil,
	}

	userList = {}
	userListByName = {}
	numberOfUsers = 0
	partMessage = ""
	PINGTIME = pingTime or 5

	MAX_PLAYERS = maxNumberOfPlayers or 16

	o.port = port
	o.portUDP = portUDP
	o.advertisement = {}

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

			print( "[NET] Client attempting to connect (" .. id .. ")" )
		end

		for k, user in pairs(userList) do			

			local data, msg, partOfLine = user.connection:receive( 9999 )
			if data then
				partMessage = partMessage .. data
			else

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
					print("[NET] Err Received:", msg, data)
				end
			end

			if not messageLength then
				if #partMessage >= 1 then
					local headerLength = nil
					messageLength, headerLength = utility:headerToLength( partMessage:sub(1,5) )
					if messageLength and headerLength then
						partMessage = partMessage:sub(headerLength + 1, #partMessage )
					end
				end
			end

			-- if I already know how long the message should be:
			if messageLength then
				if #partMessage >= messageLength then
					-- Get actual message:
					local currentMsg = partMessage:sub(1, messageLength)

					-- Remember rest of already received messages:
					partMessage = partMessage:sub( messageLength + 1, #partMessage )

					command, content = string.match( currentMsg, "(.)(.*)")
					command = string.byte( command )

					self:received( command, content, user )
					messageLength = nil

				end
			end



			--[[if data then
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
					print("[NET] Err Received:", msg, data)
				end
			end]]

			-- Fallback for backwards compability with clients which don't send an authorization
			-- request:
			if not user.authorized then
				user.authorizationTimeout = user.authorizationTimeout - dt
				-- Force authorization test now, with empty auth message:
				if user.authorizationTimeout < 0 then
					self:authorize( user, "" )
				end
			end

			-- Every PINGTIME seconds, ping the user and wait for a pong.
			-- Check if we already pinged and if not, send a ping:
			if not user.ping.waitingForPong then
				if user.ping.timer > PINGTIME then
					self:send( CMD.PING, "" )
					user.ping.timer = 0
					user.ping.waitingForPong = true

				end
			else	-- Otherwise, wait for pong. If it doesn't come, kick user.
				if user.ping.timer > 3*PINGTIME then
					self:kickUser( user, "Timeout. Didn't respond to ping." )
				end
			end
			user.ping.timer = user.ping.timer + dt
		end

		return true
	else
		return false
	end
end

function Server:received( command, msg, user )
	if command == CMD.PONG then
		if user.ping.waitingForPong then
			user.ping.pingReturnTime = math.floor(1000*user.ping.timer+0.5)
			user.ping.timer = 0
			user.ping.waitingForPong = false
			-- let all users know about this user's pingtime:
			if SYNCH_PINGS then
				self:send( CMD.USER_PINGTIME, user.id .. "|" .. user.ping.pingReturnTime )
			end
		end
	elseif command == CMD.PLAYERNAME then
		
		local name, authRequest = msg:match("(.-)|(.*)")
		if not name or not authRequest then
			name = msg
		end

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

	elseif command == CMD.AUTHORIZATION_REQUREST then
		if not user.authorized then
			self:authorize( user, msg )
		end
	elseif command == CMD.USER_VALUE then
		local keyType, key, valueType, value = string.match( msg, "(.*)|(.*)|(.*)|(.*)" )
		key = stringToType( key, keyType )
		value = stringToType( value, valueType )

		-- Remember what the value used to be:
		local prevValue = user.customData[key]
		-- Set new value:
		user.customData[key] = value

		-- Let others know about this value:
		self:send( CMD.USER_VALUE, user.id .. "|" .. msg )

		if self.callbacks.customDataChanged then
			self.callbacks.customDataChanged( user, value, key, prevValue )
		end

	elseif self.callbacks.received then
		-- If the command is not known by the engine, then send it on to the above layer:
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

	print("[NET] New Client! (" .. numberOfUsers .. ")" )
end


function Server:send( command, msg, user )
	-- Send to only one user:
	if user then
		local fullMsg = string.char(command) .. (msg or "") --.. "\n"

		local len = #fullMsg
		assert( len < 256^4, "Length of packet must not be larger than 4GB" )

		fullMsg = utility:lengthToHeader( len ) .. fullMsg

		--user.connection:send( string.char(command) .. (msg or "") .. "\n" )
		local result, err, num = user.connection:send( fullMsg )
		while err == "timeout" do
			fullMsg = fullMsg:sub( num+1, #fullMsg )
			result, err, num = user.connection:send( fullMsg )
		end

		return
	end

	-- If no user is given, broadcast to all.
	for k, u in pairs( userList ) do
		if u.connection and u.synchronized then
			self:send( command, msg, u )
		end
	end
end

function Server:newUser( user )
	-- Wait for AUTHORIZATION_TIMEOUT seconds before forcing authorization process:
	user.authorizationTimeout = AUTHORIZATION_TIMEOUT
end

function Server:authorize( user, authMsg )
	local authorized = true
	local reason = ""

	if numberOfUsers > MAX_PLAYERS then
		authorized = false
		reason = "Server full!"
	end

	if authorized then
		if self.callbacks.authorize then
			authorized, reason = self.callbacks.authorize( user, authMsg )
		end
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

	-- If the other clients already know about this client,
	-- then tell them to delete him.
	if user.synchronized then
		print("[NET] Client left (" .. user.id .. ")" )
		self:send( CMD.PLAYER_LEFT, tostring(user.id) )

		if self.callbacks.disconnectedUser then
			self.callbacks.disconnectedUser( user )
		end
	else
		print("[NET] Client left before synchronizing (" .. user.id .. ")" )
		if self.callbacks.disconnectedUnsynchedUser then
			self.callbacks.disconnectedUnsynchedUser( user )
		end
	end
end

-- Find an empty slot in the user list:
function findFreeID()
	for k = 1, numberOfUsers + 100 do
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

function Server:kickUser( user, msg )
	self:send( CMD.KICKED, msg, user )
	user.connection:shutdown()
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

	assert( user.synchronized, "Do not use server:setUserValue() before synchronization is done." )

	user.customData[key] = value

	-- Broadcast to other users:
	local keyType = type( key )
	local valueType = type( value )
	self:send( CMD.USER_VALUE, user.id .. "|" ..  keyType .. "|" .. tostring(key) ..
			"|" .. valueType .. "|" .. tostring(value) )
end

return Server
