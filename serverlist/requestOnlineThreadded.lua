-- This script is run in a seperate Löve thread to make sure the main script is not blocked:
-- It will get a list of internet servers from a "main server (given by the URL)", if possible.
local http = require("socket.http")

local arg = {...}

-- The channel to use when printing out server files:
local channel = arg[1]

-- The url:
local URL = arg[2]

-- The game name/id:
local ID = arg[3]

local body = ""
body = body .. "id=" .. ID .. "&"

local result, err, errMsg, status = http.request( URL .."/getList.php", body )

if errCode and errCode ~= 200 then
	error( errCode .. " " .. (status or "Unknown Error") )
end

-- If successful, send back the lines one by one:
for line in result:gmatch("([^\n]*)\n")do
	if #line > 0 then
		channel:push(line)
	end
end

channel:push("End")
return
