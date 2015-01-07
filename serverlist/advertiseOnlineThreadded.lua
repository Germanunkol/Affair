-- This is part of the "Affair" library.
-- This file handles sending a server's data to clients via UDP, should they request it.
-- Luasockets must be installed for this to work. If you have Löve installed, this is already the case.

local http = require("socket.http")

arg = {...}
local cin = arg[1]
local cout = arg[2]

while true do
	local msg = cin:demand()
	local command, content = msg:match( "(.-)|(.*)" )
	if command == "PORT" then
		PORT = content
	elseif command == "ID" then
		ID = content
	elseif command == "INFO" then
		INFO = content
	elseif command == "URL" then
		URL = content
	elseif command == "advertise" then
		local body = ""
		body = body .. "port=" .. PORT.. "&"
		body = body .. "id=" .. ID .. "&"
		body = body .. "info=" .. INFO .. "&"
		local result, errCode, errorMsg, status  = http.request( URL .. "/advertise.php", body )
		local err = result:match( "%[Warning:%](.-)\n" )
		if err then
			cout:push( "Warning:" .. err)
			cout:push("closed")
		elseif errCode then		-- don't send two warnings
			local msg = "Warning: Could not advertise: \"" .. tostring(status) .. "\""
			if errCode == 404 then
				msg = msg .. "\n\tWrong URL? (" .. URL .. "/advertise.php)"
			end
			cout:push( msg )
			cout:push("closed")
		end
	elseif command == "unAdvertise" then
		local body = ""
		body = body .. "port=" .. PORT.. "&"
		local result, errCode, errorMsg, status = http.request( URL .. "/unAdvertise.php", body )
		if errCode then
			local msg = "Warning: Could not unAdvertise: \"" .. tostring(status) .. "\""
			if errCode == 404 then
				msg = msg .. "\n\tWrong URL? (" .. URL .. "/advertise.php)"
			end
			cout:push( msg )
		end
		cout:push("closed")
		return
	elseif command == "close" then
		cout:push("closed")
		return
	end
end
