local _PATH = (...):match('^(.*[%./])[^%.%/]+$') or ''

local socket = require("socket")

local User = require( "network/user" )
local CMD = require( "network/commands" )

local Server = {}
Server.__index = Server

local userList = {}
local numberOfUsers = 0

local partMessage = ""

function Server:new( port )
	local o = {}
	setmetatable( o, self )

	print("Initialising Server...")
	o.conn = assert(socket.bind("*", port))
	o.conn:settimeout(0)
	if o.conn then
		print("\t-> started.")
	end

	o.callbacks = {
		newUser = nil,
		newMessage = nil,
		receivedPlayername = nil,
		disconnectedUser = nil,
	}

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
					self:disconnectedUser( user )

					numberOfUsers = numberOfUsers - 1
					
					userList[k] = nil
				else
					print("Err Received:", msg, data)
				end
			end
		end
	end
end

function Server:received( command, msg, user )
	if command == CMD.PLAYERNAME then
		user:setPlayerName( msg )
		if self.callbacks.newPlayername then
			self.callbacks.newPlayername( user )
		end
		self:send( CMD.NEW_PLAYER, user.id .. "|" .. user.playerName )
	end
end

function Server:send( command, msg, user )
	if user then
		user.connection:send( command .. msg .. "\n" )
		return
	end
	for k, u in pairs( userList ) do
		if u.connection then
			u.connection:send( command .. msg .. "\n" )
		end
	end
end

function Server:newUser( user )
	print("New Client! Number of Clients: " .. numberOfUsers )

	-- Synchronize: Send all other users to this user:
	for k, u in pairs( userList ) do
		self:send( CMD.NEW_PLAYER, u.id .. "|" .. u.playerName, user )
	end

	if self.callbacks.newUser then
		self.callbacks.newUser( user )
	end
end

function Server:disconnectedUser( user )
	print("Client left. Clients: " .. numberOfUsers )
	user.connection:shutdown()
	
	for k, u in pairs( userList ) do
		self:send( CMD.PLAYER_LEFT, user.id )
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

return Server
