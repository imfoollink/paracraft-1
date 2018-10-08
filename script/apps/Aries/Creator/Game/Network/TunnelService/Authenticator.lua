--[[
	NPL.load("(gl)script/apps/Aries/Creator/Game/Network/TunnelService/Authenticator.lua");
	local Authenticator = commonlib.gettable("MyCompany.Aries.Game.Network.Authenticator");
]]

local Authenticator = commonlib.inherit(nil, commonlib.gettable("MyCompany.Aries.Game.Network.Authenticator"));


function Authenticator:login(user)
	return true;
end

function Authenticator:connect(src, dest)
	return true
end

