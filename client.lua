
local BASE = (...):match("(.-)[^%.]+$")

local socket = require("socket")

local User = require( BASE .. "user" )
local CMD = require( BASE .. "commands" )

local Client = {}
Client.__index = Client

local userList = {}
local numberOfUsers = 0

local partMessage = ""
local piecesOfLargeMessage = {}

function Client:new( address, port, playerName )
	local o = {}
	setmetatable( o, self )

	print("Initialising Client...")
	o.conn = socket.tcp()
	o.conn:settimeout(1)
	local ok, msg = o.conn:connect( address, port )
	--ok, o.conn = pcall(o.conn.connect, o.conn, address, port)
	if ok and o.conn then
		o.conn:settimeout(0)
		print("Client connected", o.conn)
	else
		o.conn = nil
		return nil
	end

	o.callbacks = {
		authorized = nil,
		newUser = nil,
		received = nil,
		receivedPlayername = nil,
		connected = nil,
		disconnected = nil,
		customDataChanged = nil,
	}

	userList = {}
	partMessage = ""

	o.clientID = nil
	o.playerName = playerName

	numberOfUsers = 0

	return o
end

function Client:update( dt )
	if self.conn then
		local data, msg, partOfLine = self.conn:receive()
		if msg ~= "timeout" then
			print("\n(", data, msg, partOfLine, ")\n")
		end
		if data then
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
				print("Disconnected.")
				if self.callbacks.disconnected then
					self.callbacks.disconnected()
				end
				self.conn = nil
				return false
			else
				print("Err Received:", msg, data)
			end
		end
		return true
	else	
		return false
	end
end

function Client:received( command, msg )
	print("cl received:", command, msg:sub(1, 50), #msg )
	if command == CMD.NEW_PLAYER then
		local id, playerName = string.match( msg, "(.*)|(.*)" )
		id = tonumber(id)
		local user = User:new( nil, playerName, id )
		userList[id] = user
		numberOfUsers = numberOfUsers + 1
	elseif command == CMD.PLAYER_LEFT then
		local id = tonumber(msg)
		userList[id] = nil
		numberOfUsers = numberOfUsers - 1
	elseif command == CMD.AUTHORIZED then
		local authed, reason = string.match( msg, "(.*)|(.*)" )
		if authed == "true" then
			self.authorized = true
			print( "Connection authorized by server." )
			-- When authorized, send player name:
			self:send( CMD.PLAYERNAME, self.playerName )
		else
			print( "Not authorized to join server. Reason: " .. reason )
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
		print( "new playername",  msg )
		--self.conn:settimeout(5)
		--print("changed timeout.")
	elseif command == CMD.USER_VALUE then
		local id, keyType, key, valueType, value = string.match( msg, "(.*)|(.*)|(.*)|(.*)|(.*)" )

		key = stringToType( key, keyType )
		value = stringToType( value, valueType )

		id = tonumber( id )

		userList[id].customData[key] = value

		if self.callbacks.customDataChanged then
			self.callback.customDataChanged( user, value, key )
		end

	elseif self.callbacks.received then
		self.callbacks.received( command, msg )
	end
end

function Client:send( command, msg )

	print("client send:", command, msg)
	--self.conn:send( string.char(command) .. (msg or "") .. "\n" )

	local fullMsg = string.char(command) .. (msg or "") .. "\n"

	local result, err, num = self.conn:send( fullMsg )
	while result == nil do
		if err == "closed" then break end
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
		print( "closed.")
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

return Client
