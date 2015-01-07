-- A submodule used for telling clients about a server.

-- Get the path to this script:
local BASE = (...):match("(.-)[^%.]+$")
local BASE_SLASH = BASE:sub(1,#BASE-1) .. "/"

local advertise = {
	portUDP = 3410,
	advertiseOnlineTimer = 0
}

advertise.callbacks = {
	newEntryOnline = nil,
	newEntryLAN = nil,
	fetchedAllOnline = nil,		-- when done
	advertiseWarnings = nil,	-- on error
}

local ADVERTISEMENT_UPDATE_TIME = 60	-- update every 60 seconds.

local advertiseOnlineThread = nil
local advertiseOnlineCin = nil
local advertiseOnlineCout = nil

local requestOnlineThread = nil
local requestOnlineCout = nil

-- A list containing the servers as retreived from the web server:
local listOnline = {}
-- A list containing servers in the local area network:
local listLAN = {}

function advertise:setURL( url )
	self.url = url
end

function advertise:setPortUDP( port )
	assert( port >= 1024 and port <= 65535,
			"Port given to setPortUDP must be between 1024 and 65535." )
	self.portUDP = port
end

function advertise:setID( name )
	-- Only these characters are allowed:
	name = name:gsub("[^a-zA-Z0-9%.,:;/%-%+_%%%(%)%[%]!%?']", "")

	self.ID = name
end

function advertise:setInfo( data )
	-- Only these characters are allowed:
	data = data:gsub("[^a-zA-Z0-9%.,:;/%-%+_%%%(%)%[%]!%?']", "")

	self.serverInfo = data

	if self.advertiseOnline then
		self.advertiseOnlineTimer = 0
	end
end

function advertise:start( server, where )

	assert( self.ID,
			"Give the application an ID using advertise:setID before calling advertise:start!" )
	assert( server,
			"You must pass a valid server to advertise:start!" )

	if string.lower(where) == "lan" then
		self.advertiseLAN = true
		self.advertiseOnline = false
	elseif string.lower(where) == "online" then
		self.advertiseLAN = false
		self.advertiseOnline = true
	elseif string.lower(where) == "both" then
		self.advertiseLAN = true
		self.advertiseOnline = true
	end

	self.port = server.port

	if self.advertiseLAN then
		assert( self.portUDP,
				"Give a Port using advertise:setPortUDP before calling advertise:start" )

		self.advertiseUDP = socket.udp()
		self.advertiseUDP:settimeout(0)
		self.advertiseUDP:setsockname('*', self.portUDP)
		self.advertiseUDP:setoption("broadcast", true)
		print("[ADVERTISE] Advertising server in LAN. UDP Port: " .. self.portUDP)
	end

	if self.advertiseOnline then
		assert( self.url, "Give a URL using advertise:setURL before calling advertise:start" )
		self.advertiseOnlineTimer = 0

		-- If this is run in Löve, rtart a thread to handle the
		-- Otherwise, updates will be started in another process (see sendUpdateOnline)
		if love then
			if advertiseOnlineThread then
				advertiseOnlineCin:push("close|")
				advertiseOnlineThread = nil
			end

			advertiseOnlineThread = love.thread.newThread(
					BASE_SLASH .. "serverlist/advertiseOnlineThreadded.lua" )
			advertiseOnlineCin = love.thread.newChannel()
			advertiseOnlineCout = love.thread.newChannel()

			advertiseOnlineThread:start( advertiseOnlineCin, advertiseOnlineCout )
		end
		print("[ADVERTISE] Advertising server online.")
	end
end

function advertise:stop()

	if self.advertiseLAN or self.advertiseOnline then
		print("[ADVERTISE] Stopped advertising the server.")
	end

	if self.advertiseLAN then
		-- Stop advertising in LAN:
		if self.advertiseUDP then
			self.advertiseUDP:close()
			self.advertiseUDP = nil
		end
		self.advertiseLAN = false
	end

	if self.advertiseOnline then
		-- Stop online:
		if love and advertiseOnlineThread then
			-- Un-Advertise the server:
			advertise:sendUpdateOnline( true )
		end
		self.advertiseOnline = false
	end
end

function advertise:request( where )
	assert( self.ID,
			"Give the application an ID using advertise:setID before calling advertise:start!" )

	if string.lower(where) == "lan" then
		self.requestLAN = true
		self.requestOnline = false
	elseif string.lower(where) == "online" then
		self.requestLAN = false
		self.requestOnline = true
	elseif string.lower(where) == "both" then
		self.requestLAN = true
		self.requestOnline = true
	end

	if self.requestLAN then
		listLAN = {}
		assert( self.portUDP,
				"Give a Port using advertise:setPortUDP before calling advertise:requestLAN" )

		self.requestUDP = socket.udp()
		self.requestUDP:settimeout(0)
		self.requestUDP:setoption('broadcast',true)
		self.requestUDP:sendto( "ServerlistRequest|" .. self.ID .. "\n",
				"255.255.255.255", self.portUDP)
		print( "[REQUEST] Requested LAN servers. UDP Port: " .. self.portUDP )
	end

	if self.requestOnline then
		listOnline = {}
		assert( self.url,
				"Give a URL using advertise:setURL before calling advertise:requestOnline" )

		assert( love,
				"Requesting an online server list only works in Love." )

		requestOnlineThread = love.thread.newThread(
				BASE_SLASH .. "serverlist/requestOnlineThreadded.lua" )
		requestOnlineCout = love.thread.newChannel()

		requestOnlineThread:start( requestOnlineCout, self.url, self.ID )
		print( "[REQUEST] Requested online servers." )
	end
end

function advertise:stopRequesting()
	if self.requestLAN then
		self.requestLAN = false
		if self.requestUDP then
			self.requestUDP:close()
			self.requestUDP = nil
		end
	end

	if self.requestOnline then
		self.requestOnline = false
	end

	if requestOnlineThread then
		requestOnlineThread = nil
	end
end

function advertise:update( dt )
	if self.advertiseLAN then
		if self.advertiseUDP then
			local data, ip, port = self.advertiseUDP:receivefrom()
			if data then
				local id = data:match("ServerlistRequest|(.-)\n?$")
				if id and id == self.ID then
					self.advertiseUDP:sendto( "ServerlistReply|" .. self.ID .. "|" .. self.port ..
							"|" .. self.serverInfo .. "\n", ip, port )
					print("[ADVERTISE] Received LAN request. Game ID matched. Answered request.")
				end
			end
		end
	end

	if self.advertiseOnline then
		if self.advertiseOnlineTimer <= 0 then
			self:sendUpdateOnline()
			self.advertiseOnlineTimer = ADVERTISEMENT_UPDATE_TIME
		end
	end

	if advertiseOnlineThread then
		local msg = advertiseOnlineCout:pop()
		if msg then
			if msg ~= "closed" then
				print("[ADVERTISE] " .. msg)
				if self.callbacks.advertiseWarnings then
					self.callbacks.advertiseWarnings( msg )
				end
			else
				advertiseOnlineThread = nil
			end
		end
		if advertiseOnlineThread then
			local err = advertiseOnlineThread:getError()
			if err then
				print("[ADVERTISE] " .. err)
				advertiseOnlineThread = nil
			end
		end
	end

	if self.requestLAN then
		if self.requestUDP then
			local data, ip, p = self.requestUDP:receivefrom()
			if data then
				advertise:parseLANServerEntry( data, ip )
			end
		end
	end

	if self.requestOnline then
		if requestOnlineThread then
			-- Check for errors:
			local err = requestOnlineThread:getError()
			if err then
				print("THREAD ERROR: " .. err)
				requestOnlineThread = nil
			end
			-- Get any new messages:
			local msg = requestOnlineCout:pop()
			if msg then
				self:parseOnlineServerEntry( msg )
			end
		end
	end
end

function advertise:sendUpdateOnline( unAdvertise )
	if not unAdvertise then
		-- advertise the server, i.e. put it onto the server list.
		if love then
			if advertiseOnlineThread then
				-- If thread exists, channels also exist:
				advertiseOnlineCin:push( "PORT|" .. self.port )
				advertiseOnlineCin:push( "ID|" .. self.ID )
				advertiseOnlineCin:push( "INFO|" .. self.serverInfo )
				advertiseOnlineCin:push( "URL|" .. self.url )
				advertiseOnlineCin:push( "advertise|" )
			end

		else
			os.execute( "lua " .. BASE_SLASH .. "serverlist/advertiseOnline.lua "
			.. self.url .. "/advertise.php "
			.. self.port .. " "
			.. "\"" .. self.ID .. "\" "
			.. "\"" .. self.serverInfo .. "\" &" )
		end
	else

		-- unAdvertise the server, i.e. remove it from the server list:
		if love then
			if advertiseOnlineThread then
				-- If thread exists, channels also exist:
				advertiseOnlineCin:push( "PORT|" .. self.port )
				advertiseOnlineCin:push( "URL|" .. self.url )
				advertiseOnlineCin:push( "unAdvertise|" )
				advertiseOnlineCin:push( "close" )
			end
		else
			os.execute( "lua " .. BASE_SLASH .. "serverlist/unAdvertiseOnline.lua "
			.. self.url .. "/advertise.php "
			.. self.port .. " "
			.. "\"" .. self.ID .. "\" "
			.. "\"" .. self.serverInfo .. "\" &" )
		end
	end
end

function advertise:parseLANServerEntry( data, ip )
	local command, id, port, info = data:match("(.-)|(.-)|(.-)|(.-)\n?$")
	if command and id and info then
		if command == "ServerlistReply" and id == self.ID then
			local e = {
				address = ip,
				port = port,
				info = info,
			}
			table.insert( listLAN, e )
			if self.callbacks.newEntryLAN then
				self.callbacks.newEntryLAN( e )
			end
		end
	end
end

function advertise:parseOnlineServerEntry( msg )
	if msg == "End" then
		requestOnlineThread = nil
		if self.callbacks.fetchedAllOnline then
			self.callbacks.fetchedAllOnline( listOnline )
		end
	else
		local address, port, info = msg:match("%[Entry%] (.-):(%S*)%s(.*)")
		if address and port and info then
			local e = {
				address = address,
				port = port,
				info = info,
			}
			table.insert( listOnline, e )
			if self.callbacks.newEntryOnline then
				self.callbacks.newEntryOnline( e )
			end
		else
			print("[ADVERTISE] Reply:", msg )
		end
	end
end

function advertise:getServerList( where )
	where = where or "both"

	if string.lower( where ) == "both" then
		local t = {}
		for k, v in ipairs( listLAN ) do
			t[k] = v
		end
		for k, v in ipairs( listOnline ) do
			t[k + #listLAN] = v
		end
		return t
	elseif string.lower( where ) == "lan" then
		return listLAN
	elseif string.lower( where ) == "online" then
		return listOnline
	end
end

return advertise
