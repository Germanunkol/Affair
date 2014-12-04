
local _PATH = (...):match('^(.*[%./])[^%.%/]+$') or ''

local socket = require("socket")

local User = require( "network/user" )
local CMD = require( "network/commands" )

local Client = {}
Client.__index = Client

local userList = {}

local partMessage = ""

function Client:new( address, port, playername )
	local o = {}
	setmetatable( o, self )

	print("Initialising Client...")
	ok, o.conn = pcall(socket.connect, address, port)
	if ok and o.conn then
		print("Client connected", o.conn)
		o.conn:settimeout(0)
		Client.send( o, CMD.PLAYERNAME, playername )
	else
		error("Could not connect.")
		o.conn = nil
	end

	o.callbacks = {
		newUser = nil,
		newMessage = nil,
		receivedPlayername = nil,
		disconnected = nil,
	}

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
			print("d", data, command, content)

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
		print("user:", id, playerName )
		local user = User:new( nil, playerName, id )
		userList[tonumber(id)] = user
	elseif command == CMD.PLAYER_LEFT then
		local id = tonumber(msg)
		userList[id] = nil
	end
end

function Client:send( command, msg )
	self.conn:send( command .. msg .. "\n" )
end

function Client:getUsers()
	return userList
end

return Client
