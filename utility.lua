local BASE = (...):match("(.-)[^%.]+$")

local utility = {}

local b1 = 256^3
local b2 = 256^2
local b3 = 256

function utility:lengthToHeader( len )
	-- Short message:
	if len < 255 then
		return string.char(len)
	end

	-- Long message ('255' followed by 4 bytes of length)
	local h1 = math.floor(len/b1)
	len = len - h1*b1
	local h2 = math.floor(len/b2)
	len = len - h2*b2
	local h3 = math.floor(len/b3)
	len = len - h3*b3
	--print("\t",255, h1, h2, h3, len)
	return string.char(255,h1,h2,h3,len)
end

function utility:headerToLength( header )
	local byte1 = string.byte( header:sub(1,1) )
	if byte1 <= 254 then
		return byte1, 1
	else
		if #header == 5 then
			local v1 = string.byte(header:sub(2,2))*b1
			local v2 = string.byte(header:sub(3,3))*b2
			local v3 = string.byte(header:sub(4,4))*b3
			local v4 = string.byte(header:sub(5,5))
			return v1 + v2 + v3 + v4, 5
		end
	end
	-- If the length is larger than 254, but no 5 bytes have arrived yet...
	return nil
end

return utility
