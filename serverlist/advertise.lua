-- This is part of the "Affair" library.
-- This file handles sending a server's data to the main server list.
-- Luasockets must be installed for this to work. If you have Löve installed, this is already the case.

local http = require("socket.http")


local URL = arg[1] or ""
local PORT = arg[2] or ""
local ID = arg[3] or ""
local INFO = arg[4] or ""

--print( "[ADVERTISE] Contacting: " .. URL )

local body = ""
body = body .. "port=" .. PORT.. "&"
body = body .. "id=" .. ID .. "&"
body = body .. "info=" .. INFO .. "&"

http.request( URL, body )
print( "[ADVERTISE] Advertisement sent:", PORT, ID, INFO )

-- Close this process:
os.exit()
