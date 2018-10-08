--[[
Title: RoomInfo
Author(s): LiXizhi
Date: 2016/3/4
Desc: room contains 
use the lib:
-------------------------------------------------------
NPL.load("(gl)script/apps/Aries/Creator/Game/Network/TunnelService/TRoomInfo.lua");
local RoomInfo = commonlib.gettable("MyCompany.Aries.Game.Network.RoomInfo");
local room_info = RoomInfo:new():init(room_key)
-------------------------------------------------------
]]
NPL.load("(gl)script/apps/Aries/Creator/Game/Network/TunnelService/Authenticator.lua");
local Authenticator = commonlib.gettable("MyCompany.Aries.Game.Network.Authenticator");

local RoomInfo = commonlib.inherit(Authenticator, commonlib.gettable("MyCompany.Aries.Game.Network.RoomInfo"));
local Room = commonlib.gettable("MyCompany.Aries.Game.Network.Room")
function RoomInfo:ctor()
	-- array of all users. 
	self.HostToRoom = {}
	self.KeyToRoom = {}
end

local next_room_key = 0;

-- static function
function RoomInfo.GenerateRoomKey()
	next_room_key = next_room_key + 1;
	return "room"..next_room_key;
end


-- @param room_key: if nil, we will dynamically generate a room key
function RoomInfo:Init(room_key, host)
	self.room_key = room_key or RoomInfo.GenerateRoomKey();
	self.host = hostname;
	self:AddUser(host)
	return self;
end

function RoomInfo:createRoom(room_key, host)
	local room = Room:new(room_key, host);
	self.HostToRoom[host] = room;
	self.KeyToRoom[room_key] = room;
end

function RoomInfo:destroyRoom(room_key)
	local room = self:getRoom(room_key);
	if (not room) then
		return
	end

	self.HostToRoom[room.host] = nil;
	self.KeyToRoom[room_key] = nil;
end

function RoomInfo:getRoom(room_key)
	return self.KeyToRoom[room_key];
end

function RoomInfo:getRoomByHost(host)
	return self.HostToRoom[host];
end

function RoomInfo:login(user)
	--[[
	if isInBanList then 
		return false
	end
	]]
	return true;
end

function RoomInfo:connect(host, guest)
	local room = self:getRoomByHost(host);
	if (room) then
		return room:getUser(guest) ~= nil;
	end
	return false;
end


function Room:new(key, host)
	local room = commonlib.clone(self);
	room.room_key = key;
	room.host = host
	room.users = commonlib.ArrayMap:new();
	return room;
end

function Room:addUser(username)
	self.users:add(username, {username = username, last_tick=0});
end

function Room:getUser(username)
	return self.users:get(username);
end

function Room:removeUser(username)
	self.users:remove(username);
end


