
local _PATH = (...):match('^(.*[%./])[^%.%/]+$') or ''

local socket = require("socket")

local User = require( "user" )
local CMD = require( "commands" )

local Client = {}
Client.__index = Client

local userList = {}

local partMessage = ""

function Client:new( address, port, playerName )
	local o = {}
	setmetatable( o, self )

	print("Initialising Client...")
	ok, o.conn = pcall(socket.connect, address, port)
	if ok and o.conn then
		print("Client connected", o.conn)
		o.conn:settimeout(0)
	else
		error("Could not connect.")
		o.conn = nil
	end

	o.callbacks = {
		newUser = nil,
		received = nil,
		receivedPlayername = nil,
		connected = nil,
		disconnected = nil,
	}

	o.clientID = nil
	o.playerName = playerName

	return o
end

function Client:update( dt )
	if self.conn then
		local data, msg, partOfLine = self.conn:receive()
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
				self.conn:shutdown()
				print("Disconnected.")
				if self.callbacks.disconnected then
					self.callbacks.disconnected()
				end
				self.conn = nil
			else
				print("Err Received:", msg, data)
			end
		end
	end
end

function Client:received( command, msg )
	print("cl received:", command, msg )
	if command == CMD.NEW_PLAYER then
		local id, playerName = string.match( msg, "(.*)|(.*)" )
		local user = User:new( nil, playerName, id )
		userList[tonumber(id)] = user
	elseif command == CMD.PLAYER_LEFT then
		local id = tonumber(msg)
		userList[id] = nil
	elseif command == CMD.AUTHORIZED then
		local authed, reason = string.match( msg, "(.*)|(.*)" )
		if authed == "true" then
			self.authorized = true
		else
			print( "Not authorized to join server. Reason: " .. reason )
		end
		-- When authorized, send player name:
		self:send( CMD.PLAYERNAME, self.playerName )
	elseif command == CMD.PLAYERNAME then
		self.playerName = msg
		-- At this point I am fully connected!
		if self.callbacks.connected then
			self.callbacks.connected()
		end
	elseif self.callbacks.received then
		self.callbacks.received( command, msg )
	end
end

function Client:send( command, msg )
	print("client send:", command, msg)
	self.conn:send( string.char(command) .. msg .. "\n" )
end

function Client:getUsers()
	return userList
end

return Client
