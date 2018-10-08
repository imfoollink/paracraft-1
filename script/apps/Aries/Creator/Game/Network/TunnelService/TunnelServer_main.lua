--[[
Title: TunnelServerMain shell loop file
Author(s): LiXizhi
Date: 2016/3/4
Desc: use this to start a stand alone tunnel server.
use the lib:
-------------------------------------------------------
NPL.load("(gl)script/apps/Aries/Creator/Game/Network/TunnelService/TunnelServer_main.lua");
local TunnelServerMain = commonlib.gettable("MyCompany.Aries.Game.Network.TunnelServerMain");
TunnelServerMain:Init();

-- or start locally
TunnelServerMain:StartServer();
-------------------------------------------------------
]]
NPL.load("(gl)script/ide/System/System.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Network/TunnelService/TunnelServer.lua");
local TunnelServer = commonlib.gettable("MyCompany.Aries.Game.Network.TunnelServer");


local PacketPbHelper = commonlib.gettable("nplprotobuf.packets.PacketPbHelper");

--load proto
NPL.load("(gl)script/Truck/pb/cs_basic_pb.lua");
NPL.load("(gl)script/TunnelServer/ot_room.proto.lua");
NPL.load("(gl)script/Truck/Network/Packets/cs_basic.proto.lua");

local Config = commonlib.gettable("Mod.Truck.Config");
local TunnelServerMain = commonlib.gettable("MyCompany.Aries.Game.Network.TunnelServerMain");

NPL.load("(gl)script/Truck/Network/NetworkClient.lua");
local NetworkClient = commonlib.gettable("Mod.Truck.Network.NetworkClient");

local serverState  =
{
--offline
	unknown = 0,
	registering = 1,
--online
	registered = 100,
}

-- this is the one time init function. 
-- @param configFile: table of {host, port} or filename, default to TunnelServer.config.xml
function TunnelServerMain:Init()
	-- dev info: version
	NPL.load("(gl)script/Truck/Settings.lua");
	local Settings = commonlib.gettable("Mod.Truck.Settings");
	LOG.std(nil, "info", "develop", "tunnel version: %s", Settings.version);

	self:LoadNetworkSettings();

	-- TODO: start tunner server in multiple threads as defined in xml file. 
	-- TODO: start listen on ip and port
	local server_id = ParaEngine.GetAppCommandLineByParam("server_id", nil);
	local serverconfiggroup = Config.ServerConfig.TunnelServer:get(1).tunnel_node;
	if server_id and serverconfiggroup then
		serverconfig = serverconfiggroup:find(server_id);
		if serverconfig then
			local register = serverconfig.register:get(1);
			local broadcast = serverconfig.broadcast:get(1);
			local listener = serverconfig.listener:get(1);
			if register and broadcast and listener then
				-- allow command line param "port" to override config
				register.port = ParaEngine.GetAppCommandLineByParam("reg_port", register.port);
				broadcast.port = ParaEngine.GetAppCommandLineByParam("brd_port", broadcast.port);
				listener.port = ParaEngine.GetAppCommandLineByParam("lst_port", listener.port);

				self.register = register;
				self.broadcast = broadcast;
				self.listener = listener;

				NPL.StartNetServer(self.listener.ip, self.listener.port);
				NetworkClient.start(self.listener.ip, self.listener.port);
				echo({"WebServer is listening on", self.listener.ip, self.listener.port});
				-- REMOVE this: start a test server.
				self:StartServer();
				LOG.std(nil, "info", "tunnel", "tunnel node %d started", server_id);
			else
				LOG.std(nil, "error", "tunnel", "server_id ok, config found but invalid in ServerConfig.xml");
			end
		else
			LOG.std(nil, "error", "tunnel", "server_id not found in ServerConfig.xml");
		end
	else
		LOG.std(nil, "error", "tunnel", "missing cmdline param 'server_id' or invalid ServerConfig.xml");
	end
end

-- static function
function TunnelServerMain:LoadNetworkSettings()
	NPL.AddPublicFile("script/apps/Aries/Creator/Game/Network/TunnelService/TunnelClient.lua", 202);
	NPL.AddPublicFile("script/apps/Aries/Creator/Game/Network/TunnelService/TunnelServer.lua", 203);

	local att = NPL.GetAttributeObject();
	att:SetField("TCPKeepAlive", true);
	att:SetField("KeepAlive", false);
	att:SetField("IdleTimeout", false);
	att:SetField("IdleTimeoutPeriod", 1200000);
	NPL.SetUseCompression(true, true);
	att:SetField("CompressionLevel", -1);
	att:SetField("CompressionThreshold", 1024*16);
	-- npl message queue size is set to really large
	__rts__:SetMsgQueueSize(5000);
end

function TunnelServerMain:registerTunnelServer(target_ip, target_port)
	target_ip = target_ip or self.target_ip;
	target_port = target_port or self.target_port;
	self.target_ip = target_ip;
	self.target_port = target_port;

	if (self.state == serverState.registering) then
		return;
	end
	if (not target_ip) or (not target_port) then
		LOG.std(nil, "error", "tunnel", "invalid registration ip / port");
		return;
	end
	self.state = serverState.registering;
	NPL.load("(gl)script/ide/timer.lua");
	local timer = commonlib.Timer:new({callbackFunc =
		function (t)
			if self.state < serverState.registered then
				local PacketPbHelper = commonlib.gettable("nplprotobuf.packets.PacketPbHelper");

				local delay_time = 0;
				--local target = Config.ServerConfig.TunnelServer:get(1).connection:get(1)
				if (self.nid) then -- close last connection
					NPL.reject(self.nid);
					delay_time = 5;
				end

				local delayer = commonlib.Timer:new({callbackFunc = 
					function (tt)
						echo({"registering tunnel node: ", target_ip, target_port});
						self.nid = NetworkClient.connect(target_ip, target_port);
						PacketPbHelper.setNid(self.nid);
						PacketPbHelper.sendRegisterTunnelServerReq(
							self.register.ip,
							tonumber(self.register.port),
							function (header)
								self.state = serverState.registered;
								PacketPbHelper.setGatewaySession(header.gateway_session)
								echo({"tunnelserver is successfully registered at", target_ip, target_port});
								echo({"gateway session ", header.gateway_session});
								TunnelServerMain:HeartBeat(5, 3);
								t:Change();
							end,
							function ()
								echo("error: Failed to register server");
							end)
					end})
				delayer:Change(delay_time * 1000, nil);
			else
				--kept for fail safe
				t:Change()
			end
	end})

	timer:Change(0, 1000 * 30);
end

local timeout = 0;
function TunnelServerMain:HeartBeat(timeout_window, tolerance)
	local timer = commonlib.Timer:new( {callbackFunc = function(ttt)
		if timeout > tolerance then
			LOG.std(nil, "info", "tunnel", "heart beat timeout, having lost connection presumed");
			TunnelServerMain:registerTunnelServer();
			ttt:Change();
		elseif timeout > 0 then
			LOG.std(nil, "debug", "tunnel", "heart beat timeout: %s", timeout);
		end
		timeout = timeout+1;
		PacketPbHelper.sendCSPingReq();
	end})
	timer:Change(timeout_window * 1000, timeout_window * 1000);
end

--local counter = 0;
PacketPbHelper.registerFunc("CSPingRsp",
	function ()
		-- timeout test
		-- counter = counter + 1;
		-- if counter < 5 then
		--     echo("----------------------------------timeout cleared----------------------------------");
		--     timeout = 0;
		-- end
		timeout = 0;
end)

-- start a tunnel server in the current thread
function TunnelServerMain:StartServer()
	NPL.load("(gl)script/apps/Aries/Creator/Game/Network/TunnelService/RoomInfo.lua");
	local RoomInfo = commonlib.gettable("MyCompany.Aries.Game.Network.RoomInfo");

	self.rooms = RoomInfo:new();
	if (self.tunnelServer) then 
		-- close all connection before restart
		self.tunnelServer:clear();
	end
	self.tunnelServer = TunnelServer:new():Init(self.rooms);

	local registration = serverconfig.manager:get(1);
	self:registerTunnelServer(registration.ip, registration.port);
end

function TunnelServerMain:StartServer_test()
	NPL.load("(gl)script/apps/Aries/Creator/Game/Network/TunnelService/RoomInfo.lua");
	local RoomInfo = commonlib.gettable("MyCompany.Aries.Game.Network.RoomInfo");

	self.rooms = RoomInfo:new();
	if (self.tunnelServer) then 
		-- close all connection before restart
		self.tunnelServer:clear();
	end
	self.tunnelServer = TunnelServer:new():Init(self.rooms);

	self:registerTunnelServer("10.1.1.119", "20000");
end

local main_state;
local function activate()
	if(not main_state) then
		main_state = "inited";
		TunnelServerMain:Init();
	else
		-- main loop here
	end
end
NPL.this(activate);
