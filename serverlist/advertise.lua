-- This is part of the "Affair" library.
-- This file handles sending a server's data to the main server list.
-- Luasockets must be installed for this to work. If you have Löve installed, this is already the case.

local http = require("socket.http")

print( "[ADVERTISE] Attempting to connect" )

local PORT = arg[2] or ""
local INFO = arg[3] or ""

local body = ""
body = body .. "port=" .. PORT.. "&"
body = body .. "info=" .. INFO .. "&"

print( http.request( arg[1], body ) )

-- Close this process:
os.exit()