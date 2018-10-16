--[[
Title: MC Main Login Procedure
Author(s):  LiXizhi
Company: ParaEngine
Date: 2013.10.14
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)script/apps/Aries/Creator/Game/Login/MainLogin.lua");
MyCompany.Aries.Game.MainLogin:start();
------------------------------------------------------------
]]

local GameLogic = commonlib.gettable("MyCompany.Aries.Game.GameLogic")
NPL.call("protocol/pb.cpp", {});
-- create class
local MainLogin = commonlib.gettable("MyCompany.Aries.Game.MainLogin");

function MainLogin:start(init_callback)

    echo("cellfy", "----------------------------------main login start----------------------------------");
	--set title
	ParaEngine.SetWindowText(string.format("哈奇小镇"));
	

	NPL.load("(gl)script/apps/Aries/Creator/Game/mcml/pe_mc_mcml.lua");
	MyCompany.Aries.Game.mcml_controls.register_all();

	NPL.load("(gl)script/apps/Aries/Creator/Game/game_logic.lua");
	init_callback();
	self:LoadBackground3DScene();
  
  self:LoadPackages();

	NPL.load("(gl)script/apps/Aries/Creator/Game/game_logic.lua");
    local GameLogic = commonlib.gettable("MyCompany.Aries.Game.GameLogic")
	GameLogic.InitMod();

	self:checkInstallUrlProtocol();
	self:CheckCommandLine();
	
	--self:LoadLoginPage()
	
end

-- perform next step. 
-- @param state_update: This can be nil, it is a table to modify the current state. such as {IsLocalUserSelected=true}
function MainLogin:next_step(state_update)
	echo("error", state_update)
end


function MainLogin:LoadBackground3DScene()
	-- just in case it is from web browser. inform to switch to 3d display. 
	if(System.options.IsWebBrowser) then
		commonlib.app_ipc.ActivateHostApp("preloader", "", 100, 1);
	end

	-- always disable AA for mc. 
	if(ParaEngine.GetAttributeObject():GetField("MultiSampleType", 0)~=0) then
		ParaEngine.GetAttributeObject():SetField("MultiSampleType", 0);
		LOG.std(nil, "info", "FancyV1", "MultiSampleType must be 0 in order to use deferred shading. We have set it for you. you must restart. ");
		ParaEngine.WriteConfigFile("config/config.txt");
	end

	local FancyV1 = GameLogic.GetShaderManager():GetFancyShader();
	if(false and FancyV1.IsHardwareSupported()) then
		GameLogic.GetShaderManager():SetShaders(2);
		GameLogic.GetShaderManager():SetUse3DGreyBlur(true);
	end


	self:ShowLoginBackgroundPage(true, true, true, true);
	--self:next_step({Loaded3DScene = true});
end

function MainLogin:CheckCommandLine()
	local UrlProtocol = NPL.load("script/Truck/Game/UrlProtocol/UrlProtocol.lua");
	local up = UrlProtocol:new();
	local cmdline = ParaEngine.GetAppCommandLine();
	local urlProtocol = string.match(cmdline or "", "(.+://.+)$");
	
	if urlProtocol and up:parse(urlProtocol) then -- load with url protocol
		local UrlProtocolInterpreter = NPL.load("script/Truck/Game/UrlProtocol/UrlProtocolInterpreter.lua");
		UrlProtocolInterpreter.execute(up);
	else
		NPL.load("(gl)script/Truck/Game/ModuleManager.lua");
		local ModuleManager = commonlib.gettable("Mod.Truck.Game.ModuleManager");
		self:LoadLoginPage(function() ModuleManager.startModule("BigWorldPlay") end)
	end
	
end

function MainLogin:checkInstallUrlProtocol()
	local protocol_name = "truckstar";
	local app_name = "AwesomeTruck.exe"
	NPL.load("(gl)script/apps/Aries/Creator/Game/Login/UrlProtocolHandler.lua");
	local UrlProtocolHandler = commonlib.gettable("MyCompany.Aries.Creator.Game.UrlProtocolHandler");
	if(System.options.mc and System.os.GetPlatform() == "win32" and GameLogic.platformIdentity ~= "paraworld") then
		if(UrlProtocolHandler:HasUrlProtocol(protocol_name, app_name)) then
			return;
		else
			_guihelper.MessageBox(L"安装URL Protocol, 可用浏览器打开3D世界, 是否现在安装？(可能需要管理员权限)", function(res)
				if(res and res == _guihelper.DialogResult.Yes) then
					UrlProtocolHandler:RegisterUrlProtocol(protocol_name, app_name);
				end
			end, _guihelper.MessageBoxButtons.YesNo);
		end	
	end
end

-- load predefined mod packages if any
function MainLogin:LoadPackages()
    NPL.load("(gl)script/apps/Aries/Creator/Game/Login/BuildinMod.lua");
    local BuildinMod = commonlib.gettable("MyCompany.Aries.Game.MainLogin.BuildinMod");
    BuildinMod.AddBuildinMods();
    self:next_step({IsPackagesLoaded = true});
end

function MainLogin:ShowLoginModePage()
	NPL.load("(gl)script/Truck/WelcomePage.lua");
	local WelcomePage = commonlib.gettable("Mod.Truck.UI.WelcomePage");
	WelcomePage.ShowPage();
end
function MainLogin:LoadLoginPage(callback)
	NPL.load("(gl)script/Truck/Game/ModuleManager.lua");
	local ModuleManager = commonlib.gettable("Mod.Truck.Game.ModuleManager");

	ModuleManager.startModule("Login",{loginCallback = callback})
end

function MainLogin:ShowLoginBackgroundPage(bShow, bShowCopyRight, bShowLogo, bShowBg)

	echo("cellfy", "----------------------------------main login show bg----------------------------------");

	--to be dealt with later
	local url = "script/apps/Aries/Creator/Game/Login/LoginBackgroundPageVoid.html"
	System.App.Commands.Call("File.MCMLWindowFrame", {
		url = url, 
		name = "LoginBGPage", 
		isShowTitleBar = false,
		DestroyOnClose = true, -- prevent many ViewProfile pages staying in memory
		style = CommonCtrl.WindowFrame.ContainerStyle,
		allowDrag = false,
		zorder = -2,
		bShow = bShow,
		directPosition = true,
			align = "_fi",
			x = 0,
			y = 0,
			width = 0,
			height = 0,
		cancelShowAnimation = true,
	});
end
