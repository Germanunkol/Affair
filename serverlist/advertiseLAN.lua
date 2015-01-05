-- This script is run on a server, which wants to advertise its IP, port and server info on a LAN.
-- Clients send a broadcast which the servers receive. Once the server receives a broadcast, it
-- answers to the sending client.
local socket = require("socket")

local advertiseLAN = {}

-- Receive the data which should be sent to clients when they request it:
function advertiseLAN:setData( portUDP, port, id, data )
	self.portUDP = portUDP
	self.port = port
	self.id = id
	self.data = data
end

function advertiseLAN:startListening()
	self.udp = socket.udp()
	self.udp:settimeout(0)
	self.udp:setoption("broadcast", true)
	--self.udp:setsockname('*',self.portUDP)
	print("... port", self.portUDP)
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
	print("checking", data, ip, port, id )
	if id and id == self.id then
		self.udp:sendto( "ServerlistReply|" .. self.id .. "|" .. self.port .. "|" .. self.data .. "\n", ip, port )
		print("[ADVERTISE] Received LAN request. Game ID matched. Answered request.")
	end
end

return advertiseLAN
