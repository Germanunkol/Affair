# Affair - Löve Networking Library #

A networking library aimed at the awesome Löve engine (love2d.org).
This library aims to take care of the enourmous overhead of connecting, authorizing, passwords, synchronizing game states, usernames, userlist etc. involved when creating a network game.
The goal is to make the networking very simple.

Features:
- Synchronizing of userlist (including IDs and Playernames) is done by library.
- Callbacks for important events (new user, disconnected etc.) can be defined.
- Server is independent of and can be run as a dedicated, headless, plain-Lua server (example included).
- Automatic handling of usernames. If a name appears multiple times, the library automatically appends numbers and increments them.
- Automatically synched user values - want to synch the colour of your player with other servers, and let newly joining clients also know about it? Simply call client:setUserValue( "red", 255 ) and let the library handle synchronization.
- TCP (reliable connection) only.
- Online serverlist - see [Germanunkol/AffairMainServer](https://github.com/Germanunkol/AffairMainServer)
- [TODO] LAN serverlist (UDP-Broadcast)

## Example: ##

The lib comes with an example (main.lua).
Run a server using:
```bash
love . --server
```
Connect a user by calling:
```bash
love . --client ADDRESS
```
ADDRESS is the IP address. Defaults to 'localhost'.

Default port is 3410.

You can also create a server _and_ connect a client to it at the same time:
```bash
love . --server --client localhost
```

Another included example is the dedicated server, which runs in plain Lua (Luasocket must be installed. If you have Löve installed, then this is usually the case.)
Run:
```bash
lua examples/dedicated.lua
```
Then connect a client to it by running the client example above.

## Server: ##

A server is started using the **network:startServer** function:

```
server, err = network:startServer( numberOfPlayers, port, pingUpdate )
```
- **numberOfPlayers** is the maximum number of clients that may connect to the server (default 16).
- **port** is the port number (Servers will need to port-forward this port if they're behind a router. Use a value between 1025 and 65535, default is 3410)
- **pingUpdate** specifies how often the server should ping clients. (To check for timeouts, for example. Value in seconds, default is 5 seconds.)
Upon success, this function returns a server object which can be used to control the server (send stuff, kick clients, close connections, get list of clients, get number of clients etc.)
If the function fails, it returns nil and an err will be filled with the error message.

### Callbacks: ###

Once you have created a server object, you can define the server's callbacks. If, for example, "authorize" and "serverReceive" are functions with the correct parameters, then you can define the callbacks like this:

```lua
server, err = network:startServer( ... )
if server then
	server.callbacks.received = serverReceive
	server.callbacks.authorize = authorize
end
```

**server.callbacks.received( command, msg, user )**: Called whenever the server receives a message from a user (which is not an engine-internal message). So whenever you call client:send( command, msg ) on a client, this event will fire on the server.

**server.callbacks.userFullyConnected( user )**: Called when a user has connected AND has been synchronized. "user" is the newly connected user, which has a player name and id set already. Ideally, you should never interact with a user before this callback has fired. Important: before this callback has fired, any broadcasts will _not_ be forwarded to this user.

**server.callbacks.synchronize( user )**: This callback is called during the connection process of a new user. If there are vital objects/information which the client needs before joining the game (for example, the current map or the other clients' player entities) then it should be sent to the client here.
Note: At this point, the new client knows about all other clients, so it's okay to send client-specific data - like the player entities - which might require knowledge about the other players.
Note: At this point, the new client also knows the current status of all of the other users' customData (userValues) which have previously been set.
Note: If you use server:send(...) in this function to send values to the new user, make sure to give the third parameter to the function (the "user" value). Otherwise, server:send broadcasts this info to all synchronized clients - and the others usually already have the data.
Note: Do not user server:setUserCallback here (it will throw an error), because the user must be fully synchronized before setUserValue works. If you need to set custom user data, use server:setUserCallback in the userFullyConnected

**server.callbacks.authorize( user, authMsg )**: Called when a new user is trying to connect. Use this event to let the engine know whether or not a new user may connect at the moment. This event should return either true or false followed by an error message. If this event is not specified, it 
Example usage: The authorize event could return _true_ while the server is in a lobby, but as soon as the actual game is started, it returns: _false_, "Game already started!". The client will then be disconnected and userFullyConnected and synchronize (above) will never be called for this client.
Note: You don't need to worry about the maximum number of players here - if the server is already full, then the engine will not authorize the player and won't even call this event.
_authMsg_ is the string which the client used when calling network:startClient. This way, you can check if the client is using the same game version as you, or entered the correct password.

**server.callbacks.customDataChanged( user, value, key )**: Called whenever a client changes their customUserData. The userdata is already synched with other clients, but if you want to do something when user data changes (example: start game when sets his "ready" value to true), then this is the place
.

**server.callbacks.disconnectedUser( user )**: Called when a user has disconnected. Note: after this call, the "user" table will be invalid. Don't attempt to use it again - but you're allowed to access it to print the user name of the client who left and similar:
```lua
function disconnected( user )
	print( user.playername .. " has has left. (ID: " .. user.id .. ")" )
end
```

## Client: ##

A client is started (and connected to an already running server) by calling **network:startClient**.

```
client, err = network:startClient( address, playername, port, authMsg )
```
- **address**: The IP v4 Address to connect to (example: "192.168.0.10", default: "localhost").
- **playername**: The player name to use as the client. This _may_ be changed by the server if a player with the same name already exists.
- **port**: The port the server is running on. Make sure this is the same as the server's port setting! (default: 3410)
- **authMsg**: The authorization message which the server will use to check if the client may connect. This can be a version string or a password (or both, just concatenate them). The message will be sent to the server where the server.callbacks.authorize function will be called (if set). The server can then use the authMsg string to determine whether this client will be allowed to connect or not.
The call returns a client object if successful (which can be used to send data, set user values, and disconnect the client again) or nil followed by an error message.

### Callbacks: ###

Once you have created a client object, you can define the client's callbacks. If, for example, "connect" and "clientReceive" are functions with the correct parameters, then you can define the callbacks like this:

```lua
client, err = network:startClient( ... )
if client then
	client.callbacks.connected = connect
	client.callbacks.received = clientReceive
end
```

**client.callbacks.authorized( auth, reason ):** This is called when the server responds to the authorization request by the client (which the client will always to automatically when connecting). The 'auth' paramter will be _true_ or _false_ depending on whether the client has been authorized. The "reason" parameter will hold a message in case the client has not been authorized, telling it, why.

**client.callbacks.connected():** Called on the client when the connection process has finished (similar to the server.callbacks.userFullyConnected callback called on the server) and the client is synchronized. At this point, the client is 'equal' to all other clients who have previously connected and has their user values, names and IDs.

**client.callbacks.received( command, msg ):** Called when the client gets a message from the server (i.e. when server:send( command, msg ) has been called on the server.

**client.callbacks.disconnected():** Called when the client has been disconnected for some reason.

**client.callbacks.newUser( user ):** Called on all clients when a new user has been synchronized.
Note: This is not called on the client who is joining (i.e. the one who has just been synchronized).
Note: You do not need to keep a list of all users. Use client:getUsers() to get an up-to-date list of all currently connected users.

## Remarks: ##

**Never** send the newline character "\n"! It is used internally by the engine.

If you want to send multiple lines in one message, consider replacing all "\n" characters by a character which you're sure is not in the message, say, \t (the tabulator character):

```lua
string.gsub( str, "\n", "\t" )	-- replace all \n by \t
```

On the other side, put it back together by using:
```lua
string.gsub( str, "\t", "\n" )	-- replace all \t by \n
```

## Server lists: ##
### Online: ###
For the online server list to work, you will need to install some sort of web-server (a simple Apache server will do, you need php support) and put the files from the [AffairMainServer](https://github.com/Germanunkol/AffairMainServer) into some folder on that main server (The only requirement is that the folder is visible to anyone).
On your game's server, call the following function (after having created a server using network:startServer):

**server:advertise( data, id, url )**

- data: A string with any info about the server which you want the clients to get, before joining. This may contain a name, a password, the number of players, the map name etc.
- id: A name which identifies the game
- the URL to the **folder** where the scripts are on your main server. For example, if you have the advertise.php in a path like this: _~/web/public/AffairMainServer/advertise.php_, then the URL given here should be _~/web/public/AffairMainServer_.

**Careful!** The data and id strings may not contain the following characters: " & $ | and any whitespace (space, tab, newline). Usually, you're best off by using a comma-seperated list.
The function will start sending updates about your server every minute or so, to tell the web server that your server is still alive, and will stop sending updates when your server goes offline.
You can change the server's data, by calling the function again with only the data parameter - for example when you want to change the map or the number of players.
If you want to stop advertising the server, call (for example because a round has started and you want no more players to join):
**server:unAdvertise()**

**Example:**
```lua
function startServer()
	-- Attempt to create a server:
	server, err = network:startServer( NUMBER_OF_PLAYERS, PORT, PING_UPDATE_TIME )

	if server then
		-- These callbacks are called when a new user connects or a user disconnected:
		server.callbacks.userFullyConnected = connected
		server.callbacks.disconnectedUser = disconnected
		-- Start advertising this server, so others can join:
		server:advertise( "Players:0", "ExampleServer", MAIN_SERVER_ADDRESS )
	else
		print("Error starting server:", err)
		love.event.quit()
	end
end

-- Update number of players on the serverlist:
function connected()
	local players = network:getUsers()
	-- Only update the data field in the advertisement, leave the id and URL the same:
	server:advertise( "Players:" .. #players )
end
function disconnected()
	local players = network:getUsers()
	-- Only update the data field in the advertisement, leave the id and URL the same:
	server:advertise( "Players:" .. #players - 1 )
end

### LAN: ###

LAN server lists are not done implemented yet.
