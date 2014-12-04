
require( "lib/class" )
require( "lib/LUBE" )

local numConnected = 0
local server = 0

function connected()
	numConnected = numConnected + 1
	print("Connected:", numConnected)
end
function disconnected()
	numConnected = numConnected - 1
	print("Connected:", numConnected)
end

function love.load( args )
	if args[2] == "client" then
		server = false
		table.remove(args, 2)
	else
		if args[2] == "server" then
			table.remove(args, 2)
		else
			print("Invalid mode, defaulting to server")
		end
		server = true
	end
	if server then
		conn = lube.tcpServer()
		conn.handshake = "handshake"
		conn:setPing(true, 16, "ping?\n")
		conn:listen(3410)
		conn.callbacks.recv = serverRecv
		conn.callbacks.connect = connected
		conn.callbacks.disconnect = disconnected
	else
		local host = args[2]
		if not host then
			print("Invalid host, defaulting to localhost")
			host = "localhost"
		end
		conn = lube.tcpClient()
		conn.handshake = "handshake"
		conn:setPing(true, 2, "ping?\n")
		assert(conn:connect(host, 3410, true))
		conn.callbacks.recv = clientRecv
	end
end

function love.update( dt )
	conn:update( dt )
end

function serverRecv( msg )
	print("Received:\n\t", msg)
end
function clientRecv( msg )
	print("Received:\n\t", msg)
end

function love.keypressed( key )
	conn:send( "Pressed: " .. key )
end
