LoveNetworkSkeleton
===================

A basic skeleton aimed at the awesome Löve engine (love2d.org).

Features:
- Synchronizing of Userlist (including IDs and Usernames) is done by library.
- Callbacks for important events (new user, disconnected etc.) can be defined.
- Server is independent of Love and could be running using plain Lua.
Make sure LuaSocket is installed in this case.

- TCP (reliable connection) only.

Stuff:
------------------

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

Default port is 3410

