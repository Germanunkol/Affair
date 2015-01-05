-- This script sends a broadcast within the LAN, requesting servers. If any server is currently
-- advertising, it will reply with information about the server.

local socket = require("socket")

local requestLAN = {}

function requestLAN:start( id, portUDP )
	self.id = id
	self.portUDP = portUDP

	self.udp = socket.udp()
	self.udp:settimeout(0)
	self.udp:setoption('broadcast',true)
	--print(self.udp:setsockname('*',portUDP))
	assert(self.udp:sendto( "ServerlistRequest|" .. self.id .. "\n", "255.255.255.255", self.portUDP))
	print("... port", self.portUDP)
end

function requestLAN:stop()
	self.udp:close()
	self.udp = nil
end

function requestLAN:update()
	local data, ip, p = self.udp:receivefrom()
	if data then
		print("raw:", data, ip, p)
		local command, id, port, info = data:match("(.-)|(.-)|(.-)|(.-)\n?$")
		print("received:", command, id, port, info)
		if command and id and info then
			if command == "ServerlistReply" and id == self.id then
				return ip, port, info
			end
		end
	end
end

return requestLAN
