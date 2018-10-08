--[[
Title: TunnelServer
Author(s): LiXizhi
Date: 2016/3/4
Desc: A tunnel server, receives relays message from one tunnel client to another tunnel client. 
All tunnel client must provide a valid room_key and username. 

use the lib:
-------------------------------------------------------
NPL.load("(gl)script/apps/Aries/Creator/Game/Network/TunnelService/TunnelServer.lua");
local TunnelServer = commonlib.gettable("MyCompany.Aries.Game.Network.TunnelServer");
-------------------------------------------------------
]]

local TunnelServer = commonlib.inherit(commonlib.gettable("System.Core.ToolBase"), commonlib.gettable("MyCompany.Aries.Game.Network.TunnelServer"));

local s_singletonServer;

local User = 
{

	connections = {}, 
	alive = false,
	name = nil,
	nid = nil,

	disconnect = function (self, username)
		if username then
			local user = self.connections[username];
			if user then
				NPL.activate(self:getAddress(), {type="tunnel_disconnect",target = username,})
				NPL.activate(user:getAddress(), {type="tunnel_disconnect",target = self.name,})

				self.connections[username] = nil;
			end	
		else
			for k,v in pairs(self.connections) do
				v:disconnect(self.name);
			end
			self.alive = false;
			NPL.reject(self.nid)
			LOG.std(nil, "info", "TunnelServer", " %s logout ", self.name);
		end
	end,
	new = function (self, nid, name)
		local user = commonlib.copy(self);
		user.nid = nid;
		user.name = name;
		user.alive = true;

		return user;
	end,

	getAddress = function (self)
		return format("%s:%s", self.nid, "script/apps/Aries/Creator/Game/Network/TunnelService/TunnelClient.lua");
	end,

	connect = function (self, target)
		self.connections[target.name] = target;
		target.connections[self.name] = self;
	end,

	send = function(self, msg)
		if not self.alive then
			return false
		end
		if NPL.activate(self:getAddress(), msg) ~= 0 then
			self:disconnect();
			return false;
		end
		return true;
	end,

	timeout = function (self)
		for k,v in pairs(self.connections) do
			v:send({type="tunnel_timeout",target = self.name,})
		end
		--self.alive = false;
	end
}


function TunnelServer:ctor()
	s_singletonServer = self;
	-- mapping from room_key to room_table
	self.nidToUser = {};
	self.users = {};
end

function TunnelServer:Init(auth)
	self.auth = auth;
	LOG.std(nil, "info", "TunnelServer", "tunnel server is started");

	NPL.load("(gl)script/ide/timer.lua");
	self.timer = commonlib.Timer:new({callbackFunc = 
	function ()
		self:keepAlive();
	end})
	self.timer:Change(0,5000);

	return self;
end

function TunnelServer:clear()
	local k,v  ;
	for k,v in pairs(self.users) do
		v:disconnect();
	end
end

function TunnelServer:GetUserFromNid(nid)
	return self.nidToUser[nid];
end

function TunnelServer:login(nid, username)
	local ret = self.auth:login(username);
	if (not ret) then
		LOG.std(nil, "info", "TunnelServer", " failed to authenticate %s(%s)  ", username, nid);
		return 
	end

	self.users[username] = User:new(nid, username);
	local user = self.users[username]
	user.alive = true;
	user.ping = 0;
	self.nidToUser[nid] = user;

	LOG.std(nil, "info", "TunnelServer", " %s(%s) login ", username, nid);
	-- send reply
	user:send({type="tunnel_login", result = ret})
end

function TunnelServer:logout(username)
	self.users[username]:disconnect();
	self.users[username] = nil;
end

function TunnelServer:handleReceive(msg)
	local msg_type = msg.type;
	local nid = msg.nid or msg.tid;
	
	if(msg.dest) then
		-- relay message from source to destination on behalf of source user
		local dest = self.users[msg.dest];
		if(not dest) then
			return;
		end
		dest:send({from = self.nidToUser[nid].name, msg=msg.msg, })
	end
end

function TunnelServer:handleCmdMsg(msg)
	local msg_type = msg.type;
	local nid = msg.nid or msg.tid;

	if(msg_type == "tunnel_login") then
		self:login(nid, msg.username);
	elseif(msg_type == "tunnel_connect") then
		local client = self:GetUserFromNid(nid);
		local hostname = msg.host
		local host = self.users[hostname];
		if not client then
			return 
		end
	
		if client.name == hostname or
			not self.auth:connect( hostname,client.name) or
			not host or
			not host.alive or 
			not client.alive then
			client:send({type="tunnel_connect" , result = false})
			LOG.std(nil, "info", "TunnelServer", "%s is not allowed to connect to %s", client.name, hostname);
			return
		end


		host:connect(client);

		client:send({type="tunnel_connect" , result = true})

	elseif (msg_type == "tunnel_logout") then
		local user = self:GetUserFromNid(nid);
		if user then
			self:logout(user.name)
		end
	elseif msg_type == "tunnel_ping" then
		local user = self.users[msg.username];
		if user then
			user.ping = 0;
			user.alive = true;
		end
	end
end

function TunnelServer:keepAlive()

	for k,v in pairs(self.users) do
		echo(v)
		if v.alive then
			if v.ping > 5 then
				v:disconnect();
			elseif v.ping > 1 then
				v:timeout();
				LOG.std(nil, "info", "TunnelServer", "%s may not alive", k);
			end
			v.ping = v.ping + 1;
			v:send({type = "tunnel_ping"});
		end
	end

end

local function activate()
	local msg = msg;
	if(s_singletonServer and msg) then
		if (msg.type) then
		--echo({"TunnelServer:receive--------->", msg})
			s_singletonServer:handleCmdMsg(msg)
		else
			s_singletonServer:handleReceive(msg)
		end
	end
end
NPL.this(activate);
