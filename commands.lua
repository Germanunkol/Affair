
-- List of all possible internal commands.
-- EVERY message is lead by a command byte from to following list.
-- If it's not on this list then it's considered a user command and will be
-- send to the client:receive and server:receive callbacks.
local CMD =
{
	-- Connection process:
	PLAYERNAME = 1,
	PLAYER_AUTHORIZED = 2,
	NEW_PLAYER = 3,
	AUTHORIZED = 4,

	-- Other
	USER_VALUE = 5,
	PLAYER_LEFT = 6,

	KICKED = 7,

	AUTHORIZATION_REQUREST = 8,

	PING = 9,
	PONG = 11,
	USER_PINGTIME = 12,
}

return CMD
