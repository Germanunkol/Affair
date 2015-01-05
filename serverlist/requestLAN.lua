-- This script sends a broadcast within the LAN, requesting servers. If any server is currently
-- advertising, it will reply with information about the server.

local socket = require("socket")

local requestLAN = {}

function requestLAN:start( id, port )
	self.id = id
	self.port = port

	self.udp = socket.udp()
	self.udp:settimeout(0)
	print(self.udp:setoption('broadcast',true))
	--print(self.udp:setsockname('*',port))
	assert(self.udp:sendto( "ServerlistRequest|" .. self.id .. "\n", "255.255.255.255", self.port))
	print( "Sent", "ServerlistRequest|" .. self.id .. "\n", self.port)
end

function requestLAN:stop()
	self.udp:close()
	self.udp = nil
end

function requestLAN:update()
	local data, ip, port = self.udp:receivefrom()
	if data then
		print("raw:", data, msg, port)
		local command, id, info = data:match("(.-)|(.-)|(.-)\n?$")
		print("received:", command, id, info)
		if command and id and info then
			if command == "ServerlistReply" and id == self.id then
				return ip, port, info
			end
		end
	end
end

return requestLAN
