## LoveNetworkSkeleton ##

A basic skeleton aimed at the awesome Löve engine (love2d.org).

Features:
- Synchronizing of Userlist (including IDs and Usernames) is done by library.
- Callbacks for important events (new user, disconnected etc.) can be defined.
- Server is independent of and can be run as a dedicated, headless, plain-Lua server (example included). Make sure Luasocket is installed if you use the server without Löve.
- Automatic handling of usernames. If a name appears multiple times, the library automatically appends numbers and increments them.
- Automatically synched user values - want to synch the colour of your player with other servers, and let newly joining clients also know about it? Simply call client:setUserValue( "red", 255 ) and let the library handle synchronization.
- TCP (reliable connection) only.

### Stuff: ###

The lib comes with an example (main.lua).
Run a server using (this will also create a client and connect to itself):
```bash
love .
```
Connect a user by calling:

```bash
love . client ADDRESS
```
ADDRESS is the IP address. Defaults to 'localhost'.

To demonstrate sending and receiving of data, a chat is implemented in the example. Press enter to type text.

Default port is 3410.

Never send the newline character "\n"!
It is used internally by the engine.

### Callbacks: ###

##### Server: #####

**server.callbacks.received( command, msg, user )**: Called whenever the server receives a message from a user (which is not an engine-internal message). So whenever you call client:send( command, msg ) on a client, this event will fire on the server.

**server.callbacks.userFullyConnected( user )**: Called when a user has connected AND has been synchronized. "user" is the newly connected user, which has a player name and id set already. Ideally, you should never interact with a user before this callback has fired. Important: before this callback has fired, any broadcasts will _not_ be forwarded to this user.

**server.callbacks.synchronize( user )**: This callback is called during the connection process of a new user. If there are vital objects/information which the client needs before joining the game (for example, the current map or the other clients' player entities) then it should be sent to the client here.
Note: At this point, the new client knows about all other clients, so it's okay to send client-specific data - like the player entities - which might require knowledge about the other players.
Note: At this point, the new client also knows the current status of all of the other users' customData (userValues) which have previously been set.
Note: If you use server:send(...) in this function to send values to the new user, make sure to give the third parameter to the function (the "user" value). Otherwise, server:send broadcasts this info to all synchronized clients - and the others usually already have the data.
Note: Do not user server:setUserCallback here (it will throw an error), because the user must be fully synchronized before setUserValue works. If you need to set custom user data, use server:setUserCallback in the userFullyConnected

**server.callbacks.authorize( user )**: Called when a new user is trying to connect. Use this event to let the engine know whether or not a new user may connect at the moment. This event should return either true or false followed by an error message. If this event is not specified, it 
Example usage: The authorize event could return _true_ while the server is in a lobby, but as soon as the actual game is started, it returns: _false_, "Game already started!". The client will then be disconnected and userFullyConnected and synchronize (above) will never be called for this client.
Note: You don't need to worry about the maximum number of players here - if the server is already full, then the engine will not authorize the player and won't even call this event.

**server.callbacks.customDataChanged( user, value, key )**: Called whenever a client changes their customUserData. The userdata is already synched with other clients, but if you want to do something when user data changes (example: start game when sets his "ready" value to true), then this is the place
.

**server.callbacks.disconnectedUser( user )**: Called when a user has disconnected. Note: after this call, the "user" table will be invalid. Don't attempt to use it again - but you're allowed to access it to print the user name of the client who left and similar:
```lua
function disconnected( user )
	print( user.playername .. " has has left. (ID: " .. user.id .. ")" )
end
```

##### Client: #####

**client.callbacks.authorized( auth, reason ):** This is called when the server responds to the authorization request by the client (which the client will always to automatically when connecting). The 'auth' paramter will be _true_ or _false_ depending on whether the client has been authorized. The "reason" parameter will hold a message in case the client has not been authorized, telling it, why.

**client.callbacks.connected():** Called on the client when the connection process has finished (similar to the server.callbacks.userFullyConnected callback called on the server) and the client is synchronized. At this point, the client is 'equal' to all other clients who have previously connected and has their user values, names and IDs.

**client.callbacks.received( command, msg ):** Called when the client gets a message from the server (i.e. when server:send( command, msg ) has been called on the server.

**client.callbacks.disconnected():** Called when the client has been disconnected for some reason.

**client.callbacks.newUser( user ):** Called on all clients when a new user has been synchronized.
Note: This is not called on the client who is joining (i.e. the one who has just been synchronized).
Note: You do not need to keep a list of all users. Use client:getUsers() to get an up-to-date list of all currently connected users.


