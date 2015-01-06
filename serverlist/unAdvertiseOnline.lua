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

print( http.request( URL, body ) )

-- Close this process:
os.exit()
