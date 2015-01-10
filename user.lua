local User = {}
User.__index = User

function User:new( connection, playerName, id )
	local o = {}
	setmetatable( o, self )
	o.connection = connection
	o.incoming = {
		part = "",		-- store partly received messages here
		length = nil	-- store length of incoming message here
	}

	o.playerName = playerName
	o.id = id
	o.authorized = false
	o.synchronized = false

	o.ping = {
		timer = 0,
		waitingForPong = false,
		pingReturnTime = 0,
		}

	o.customData = {}
	
	return o
end

function User:setPlayerName( name )
	self.playerName = name
	self.receivedPlayername = true
end

function User:getPing()
	return self.ping.pingReturnTime
end

return User
