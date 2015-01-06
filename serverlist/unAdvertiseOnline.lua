-- This is part of the "Affair" library.
-- This file handles sending a server's data to the main server list.
-- Luasockets must be installed for this to work. If you have Löve installed, this is already the case.

local http = require("socket.http")

print( "[UNADVERTISE] Attempting to connect" )

local URL = arg[1] or ""
local PORT = arg[2] or ""

print( "[ADVERTISE] Contacting: " .. URL )

local body = ""
body = body .. "port=" .. PORT.. "&"

local result, errCode, errorMsg, status = http.request( URL, body )
if errCode and errCode ~= 200 then
	print("[ADVERTISE] Could not un-advertise: " .. errCode, status, "Correct URL?", URL )
end

-- Close this process:
os.exit()
