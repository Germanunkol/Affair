local User = {}
User.__index = User

function User:new( connection, playerName, id )
	local o = {}
	setmetatable( o, self )
	o.connection = connection
	o.playerName = playerName
	o.id = id
	
	return o
end

function User:setPlayerName( name )
	self.playerName = name
end

return User
