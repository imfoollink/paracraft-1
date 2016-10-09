--[[
Title: SelectModulePage.html code-behind script
Author(s): LiPeng, LiXizhi
Date: 2014/4/1
Desc: select the default global modules for the game, and the modules for every world.
Simply put plugin zip file or mod folder to ./Mod folder. 
The plugin zip file must contain a file called "Mod/[plugin_name]/main.lua" 
in order to be considered as a valid plugin zip file. 

use the lib:
-------------------------------------------------------
NPL.load("(gl)script/apps/Aries/Creator/Game/Login/SelectModulePage.lua");
local SelectModulePage = commonlib.gettable("MyCompany.Aries.Game.MainLogin.SelectModulePage")
local modules = SelectModulePage.SearchAllModules();
echo(modules)
SelectModulePage.AddModule("STLExporter.zip")
SelectModulePage.ShowPage()
-------------------------------------------------------
]]
NPL.load("(gl)script/apps/Aries/Creator/Game/Mod/ModManager.lua");
local ModManager = commonlib.gettable("Mod.ModManager");
local SelectModulePage = commonlib.gettable("MyCompany.Aries.Game.MainLogin.SelectModulePage")

-- the rage value can be 0(for global game) or 1(for one world).
SelectModulePage.range = 0;
SelectModulePage.page = nil;

-- init function. page script fresh is set to false.
function SelectModulePage.OnInit()
end

function SelectModulePage.GetPluginLoader()
	return ModManager:GetLoader();
end

-- get the datasource of the module;
function SelectModulePage.DS_Items(index)
	local ds = SelectModulePage.GetPluginLoader():GetModuleList();
	if(ds) then
		if(index == nil) then
			return #ds;
		else
			return ds[index];
		end
	end
end

-- select the module to decide the module whether loaded
function SelectModulePage.OnSwitchModStatus(bChecked,modName,index)
	SelectModulePage.GetPluginLoader():EnablePlugin(modName, bChecked);
end

-- save config to file
function SelectModulePage.ResetLoadedMods()
	SelectModulePage.GetPluginLoader():SaveModTableToFile();
end

-- show page
function SelectModulePage.ShowPage()
	SelectModulePage.OnInit();
	SelectModulePage.GetPluginLoader():RebuildModuleList();
	if(System.options.IsMobilePlatform) then
		System.App.Commands.Call("File.MCMLWindowFrame", {
			url = "script/apps/Aries/Creator/Game/Login/SelectModulePage.mobile.html", 
			name = "SelectModulePage.ShowMobilePage", 
			isShowTitleBar = false,
			DestroyOnClose = true,
			style = CommonCtrl.WindowFrame.ContainerStyle,
			allowDrag = false,
			bShow = bShow,
			zorder = 5,
			click_through = true, 
			directPosition = true,
				align = "_fi",
				x = 0,
				y = 0,
				width = 0,
				height = 0,
		});
	else
		System.App.Commands.Call("File.MCMLWindowFrame", {
			url = "script/apps/Aries/Creator/Game/Login/SelectModulePage.html", 
			name = "SelectModulePage", 
			isShowTitleBar = false,
			enable_esc_key = true,
			DestroyOnClose = true, -- prevent many ViewProfile pages staying in memory
			style = CommonCtrl.WindowFrame.ContainerStyle,
			zorder = 0,
			allowDrag = false,
			directPosition = true,
				align = "_ct",
				x = -300,
				y = -250,
				width = 600,
				height = 500,
			cancelShowAnimation = true,
		});
	end
end
