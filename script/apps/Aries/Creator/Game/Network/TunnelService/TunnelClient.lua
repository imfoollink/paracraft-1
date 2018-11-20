--[[
Title: TunnelClient
Author(s): LiXizhi
Date: 2016/3/4
Desc: all TunnelClient
use the lib:
-------------------------------------------------------
NPL.load("(gl)script/apps/Aries/Creator/Game/Network/TunnelService/TunnelClient.lua");
local TunnelClient = commonlib.gettable("MyCompany.Aries.Game.Network.TunnelClient");
-------------------------------------------------------
]]
NPL.load("(gl)script/apps/Aries/Creator/Game/Network/ConnectionBase.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Network/TunnelService/RoomInfo.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Network/ServerListener.lua");
local ConnectionBase = commonlib.gettable("MyCompany.Aries.Game.Network.ConnectionBase");
local ServerListener = commonlib.gettable("MyCompany.Aries.Game.Network.ServerListener");
local RoomInfo = commonlib.gettable("MyCompany.Aries.Game.Network.RoomInfo");

local TunnelClient = commonlib.inherit(commonlib.gettable("System.Core.ToolBase"), commonlib.gettable("MyCompany.Aries.Game.Network.TunnelClient"));

TunnelClient:Property({"Connected", false, "IsConnected", "SetConnected", auto=true})
TunnelClient:Property({"bAuthenticated", false, "IsAuthenticated", "SetAuthenticated", auto=true})

TunnelClient:Signal("server_connected")

local clients = {};

function TunnelClient:ctor()
	self.virtualConns = {};
	self.callback = nil
	-- TODO: reuse connection to the same server
	local conn = ConnectionBase:new();
	conn:SetDefaultNeuronFile("script/apps/Aries/Creator/Game/Network/TunnelService/TunnelServer.lua");
	self.conn = conn;
end

function TunnelClient:SetErrorCallback(cb)
	if (self.conn) then
		local tunnel = self
		self.conn:SetNetHandler(
			{
				handleErrorMessage = 
					function(self, msg)
						while true do
							local nid = next(tunnel.virtualConns);
							if not nid then
								break;
							end

							tunnel:RemoveVirtualConnection(nid);
						end
						cb(msg);
					end
			})
	else
		self.errorCallback = cb;
	end
end

-- @param ip, port: IP address of tunnel server
-- @param username: unique user name
-- @param password: optional password
-- @param callbackFunc: function(bSuccess) end
function TunnelClient:ConnectServer(ip, port, username, password, callbackFunc)
	self.callback = callbackFunc;
	local nid = ip .. port
	clients[nid] = self;
	
	LOG.std(nil, "info", "TunnelClient", {"connecting to", ip, port});
	self.username = username;
	self.password = password;
	
	local params = {host = tostring(ip), port = tostring(port), nid = tostring(nid)};
	NPL.AddNPLRuntimeAddress(params);

	local conn = self.conn;
	conn:SetNid(nid);

	conn:SetNetHandler(
	{
		handleErrorMessage = 
			function(con, msg)
				while true do
					local nid = next(self.virtualConns);
					if not nid then
						break;
					end

					self:RemoveVirtualConnection(nid);
				end
				callbackFunc({type="tunnel_lost"});
			end
	})

	conn:Connect(5, function(bSuccess)
		self:SetConnected(bSuccess);
		if(bSuccess) then
			LOG.std(nil, "info", "TunnelClient", "successfully connected to tunnel server");
			self:LoginTunnel()
		else
			LOG.std(nil, "info", "TunnelClient", "failed to connect to tunnel server: %s :%s ", params.host, params.port);
			self.callback({type = "tunnel_login", result = false});
		end
	end)
	
end

function TunnelClient:setHostName(host)
	self.hostname = host;
end

function TunnelClient:getHostName()
	return self.hostname;
end

-- get virtual nid: use username directly as nid. it must be unique within the same room.
function TunnelClient:GetVirtualNid(username)
	return username or "admin";
end

function TunnelClient:Disconnect()
	if(self.conn) then
		self.conn:Send({type="tunnel_logout",  username=self.username}, nil)
		self.conn:SetNetHandler(nil);
		self.conn:CloseConnection();
	end
	self.conn = nil;
end

-- manage virtual connections
function TunnelClient:AddVirtualConnection(nid, tcpConnection)
	self.virtualConns[nid] = tcpConnection;
end

function TunnelClient:RemoveVirtualConnection(nid)
	conn = self.virtualConns[nid];
	if (conn) then
		if conn.net_handler.handleErrorMessage then
			conn.net_handler:handleErrorMessage("onConnectionLost")
		end
		conn.connectionClosed= true;
	end
	self.virtualConns[nid] = nil;
	LOG.std(nil, "info", "TunnelClient", "%s disconnected",  nid);
	
end


-- send message via tunnel server to another tunnel client
-- @param nid: virtual nid of the target stunnel client. usually the user name
-- @param msg: the raw message table {id=packet_id, .. }. 
-- @param neuronfile: should be nil. By default, it is ConnectionBase. 
function TunnelClient:Send(nid, msg, neuronfile)
	-- TODO; check msg, and route via tunnel server
	if(self.conn) then
		self.conn:Send({dest=nid, msg=msg}, nil)
	end
end

-- login with current user name
function TunnelClient:LoginTunnel()
	-- send a tunnel login message
	if(self.conn) then
		self.conn:Send({type="tunnel_login",  username=self.username}, nil)
	end
end

function TunnelClient:LogoutTunnel()
	if (self.conn) then
		self.conn:Send({type="tunnel_logout" }, nil)
	end
end

function TunnelClient:ConnectHost()
	if (self.conn and self.hostname) then
		self.conn:Send({type="tunnel_connect", host = self.hostname}, nil)
	end
end

function TunnelClient:handleRelayMsg(msg)
	-- forward message
	if(msg) then
		if self.proxy and self.proxy:pickMessage(msg) then
			return 
		end

		local conn = self.virtualConns[msg.nid];
		if(not conn) then
			-- accept connections if any
			msg.tid = msg.nid;
			ServerListener:OnAcceptIncomingConnection(msg, self);
			conn = self.virtualConns[msg.nid];
		end

		if(conn) then
			conn:OnNetReceive(msg);
		end
	end
end

function TunnelClient:handleCmdMsg(msg)
	local type = msg.type;
	if(type == "tunnel_login") then
		self:SetAuthenticated(msg.result == true);
		LOG.std(nil, "info", "TunnelClient", "tunnel client `%s` is authenticated : %s", self.username , msg.result);
	elseif (type == "tunnel_connect") then
		LOG.std(nil, "info", "TunnelClient", "host %s is connected: %s", self.hostname, msg.result);

	elseif (msg.type=="tunnel_disconnect") then
		conn = self.virtualConns[msg.target];
		if (conn) then
			if conn.net_handler.handleErrorMessage then
				conn.net_handler:handleErrorMessage("onConnectionLost")
			end
			conn.connectionClosed= true;
		end
		self.virtualConns[msg.target] = nil;
		LOG.std(nil, "info", "TunnelClient", "%s disconnected", msg.target);
	elseif msg.type== "tunnel_ping" then
		if (self.conn) then
			self.conn:Send({type="tunnel_ping", username=self.username}, nil)
		end
	end

	self.callback(msg);
	
end
	

-- msg = { from=username, msg=orignal raw message}
local function activate()
	-- echo({"TunnelClient:receive--------->", msg})
	local msg = msg;
	local nid = msg.nid;
	tunnelClient = clients[nid];
	if(tunnelClient) then
		if(msg.type) then
			tunnelClient:handleCmdMsg(msg);
		else
			msg.msg.nid = msg.from;
			tunnelClient:handleRelayMsg(msg.msg);
		end
	end
end
NPL.this(activate);