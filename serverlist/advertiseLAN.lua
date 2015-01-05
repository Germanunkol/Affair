-- This script is run on a server, which wants to advertise its IP, port and server info on a LAN.
-- Clients send a broadcast which the servers receive. Once the server receives a broadcast, it
-- answers to the sending client.
local socket = require("socket")

local advertiseLAN = {}

-- Receive the data which should be sent to clients when they request it:
function advertiseLAN:setData( port, id, data )
	self.port = port
	self.id = id
	self.data = data
end

function advertiseLAN:startListening()
	self.udp = socket.udp()
	self.udp:settimeout(0)
	print(self.udp:setoption("broadcast", true))
	print(self.udp:setsockname('*',self.port))
end

function advertiseLAN:stopListening()
	self.udp:close()
	self.udp = nil
end

-- This must only be called AFTER calling startBroadcast!
function advertiseLAN:update( dt )
	local data, ip, port = self.udp:receivefrom()
	if data then
		print("raw:", data, ip, port)
		self:receive( data, ip, port )
	end
end

function advertiseLAN:receive( data, ip, port )
	local id = data:match("ServerlistRequest|(.-)\n?$")
	if id and id == self.id then
		print("answering:", ip, port, self.data)
		self.udp:sendto( "ServerlistReply|" .. self.id .. "|" .. self.port .. "|" .. self.data .. "\n", ip, port )
	end
end

return advertiseLAN
