
local BASE = (...):match("(.-)[^%.]+$")

local socket = require("socket")

local User = require( BASE .. "user" )
local CMD = require( BASE .. "commands" )

local utility = require( BASE .. "utility" )

local Client = {}
Client.__index = Client

local userList = {}
local numberOfUsers = 0

local partMessage = ""
local messageLength = nil

function Client:new( address, port, playerName, authMsg )
	local o = {}
	setmetatable( o, self )

	authMsg = authMsg or ""

	print("[NET] Initialising Client...")
	o.conn = socket.tcp()
	o.conn:settimeout(5)
	local ok, msg = o.conn:connect( address, port )
	--ok, o.conn = pcall(o.conn.connect, o.conn, address, port)
	if ok and o.conn then
		o.conn:settimeout(0)
		self.send( o, CMD.AUTHORIZATION_REQUREST, authMsg )
		print("[NET] -> Client connected", o.conn)
	else
		o.conn = nil
		return nil
	end

	o.callbacks = {
		authorized = nil,
		received = nil,
		connected = nil,
		disconnected = nil,
		otherUserConnected = nil,
		otherUserDisconnected = nil,
		customDataChanged = nil,
	}

	userList = {}
	partMessage = ""

	o.clientID = nil
	o.playerName = playerName

	numberOfUsers = 0

	-- Filled if user is kicked:
	o.kickMsg = ""

	return o
end

function Client:update( dt )
	if self.conn then
		local data, msg, partOfLine = self.conn:receive( 9999 )
		if data then
			partMessage = partMessage .. data
		else
			if msg == "timeout" then
				if #partOfLine > 0 then
					partMessage = partMessage .. partOfLine
				end
			elseif msg == "closed" then
				--self.conn:shutdown()
				print("[NET] Disconnected.")
				if self.callbacks.disconnected then
					self.callbacks.disconnected( self.kickMsg )
				end
				self.conn = nil
				return false
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

				self:received( command, content )
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

			self:received( command, content )
		else
			if msg == "timeout" then	-- only part of the message could be received
				if #partOfLine > 0 then
					partMessage = partMessage .. partOfLine
				end
			elseif msg == "closed" then
				--self.conn:shutdown()
				print("[NET] Disconnected.")
				if self.callbacks.disconnected then
					self.callbacks.disconnected( self.kickMsg )
				end
				self.conn = nil
				return false
			else
				print("[NET] Err Received:", msg, data)
			end
		end]]
		return true
	else	
		return false
	end
end

function Client:received( command, msg )
	if command == CMD.PING then
		-- Respond to ping:
		self:send( CMD.PONG, "" )
	elseif command == CMD.USER_PINGTIME then
		local id, ping = msg:match("(.-)|(.*)")
		id = tonumber(id)
		if userList[id] then
			userList[id].ping.pingReturnTime = tonumber(ping)
		end
	elseif command == CMD.NEW_PLAYER then
		local id, playerName = string.match( msg, "(.*)|(.*)" )
		id = tonumber(id)
		local user = User:new( nil, playerName, id )
		userList[id] = user
		numberOfUsers = numberOfUsers + 1
		if self.callbacks.newUser then
			self.callbacks.newUser( user )
		end
	elseif command == CMD.PLAYER_LEFT then
		local id = tonumber(msg)
		local u = userList[id]
		userList[id] = nil
		numberOfUsers = numberOfUsers - 1
		if self.callbacks.otherUserDisconnected then
			self.callbacks.otherUserDisconnected( u )
		end
	elseif command == CMD.AUTHORIZED then
		local authed, reason = string.match( msg, "(.*)|(.*)" )
		if authed == "true" then
			self.authorized = true
			print( "[NET] Connection authorized by server." )
			-- When authorized, send player name:
			self:send( CMD.PLAYERNAME, self.playerName )
		else
			print( "[NET] Not authorized to join server. Reason: " .. reason )
		end
		
		if self.callbacks.authorized then
			self.callbacks.authorized( self.authorized, reason )
		end

	elseif command == CMD.PLAYERNAME then
		local id, playerName = string.match( msg, "(.*)|(.*)" )
		self.playerName = playerName
		self.clientID = tonumber(id)
		-- At this point I am fully connected!
		if self.callbacks.connected then
			self.callbacks.connected()
		end
		--self.conn:settimeout(5)
	elseif command == CMD.USER_VALUE then
		local id, keyType, key, valueType, value = string.match( msg, "(.*)|(.*)|(.*)|(.*)|(.*)" )

		key = stringToType( key, keyType )
		value = stringToType( value, valueType )

		id = tonumber( id )

		userList[id].customData[key] = value

		if self.callbacks.customDataChanged then
			self.callback.customDataChanged( user, value, key )
		end
	elseif command == CMD.KICKED then

		self.kickMsg = msg
		print("[NET] Kicked from server: " .. msg )

	elseif self.callbacks.received then
		self.callbacks.received( command, msg )
	end
end

function Client:send( command, msg )

	local fullMsg = string.char(command) .. (msg or "") --.. "\n"

	local len = #fullMsg
	assert( len < 256^4, "Length of packet must not be larger than 4GB" )

	fullMsg = utility:lengthToHeader( len ) .. fullMsg

	local result, err, num = self.conn:send( fullMsg )
	while err == "timeout" do
		fullMsg = fullMsg:sub( num+1, #fullMsg )
		result, err, num = self.conn:send( fullMsg )
	end

	return
end

function Client:getUsers()
	return userList
end
function Client:getNumUsers()
	return numberOfUsers
end

function Client:close()
	if self.conn then
		--self.conn:shutdown()
		self.conn:close()
		print( "[NET] Closed.")
	end
end

function Client:setUserValue( key, value )
	local keyType = type( key )
	local valueType = type( value )
	self:send( CMD.USER_VALUE, keyType .. "|" .. tostring(key) ..
			"|" .. valueType .. "|" .. tostring(value) )
end

function Client:getID()
	return self.clientID
end

function Client:getUserValue( key )
	if not self.clientID then return nil end
	local u = userList[self.clientID]
	if u then
		return u.customData[key]
	end
	return nil
end

function Client:getUserPing( id )
	if users[id] then
		return users[id].ping.pingReturnTime
	end
end

return Client
