--[[
Title:  
Author(s): leio
Date: 2011/12/08
Desc:  
Use Lib:
-------------------------------------------------------
NPL.load("(gl)script/apps/Aries/BBSChat/ChatSystem/SmileyPage.lua");
local SmileyPage = commonlib.gettable("MyCompany.Aries.ChatSystem.SmileyPage");
SmileyPage.ShowPage();
-------------------------------------------------------
]]
NPL.load("(gl)script/apps/Aries/Desktop/GenericTooltip.lua");
NPL.load("(gl)script/apps/Aries/BBSChat/ChatSystem/ChatChannel.lua");
local ChatChannel = commonlib.gettable("MyCompany.Aries.ChatSystem.ChatChannel");
NPL.load("(gl)script/apps/Aries/BBSChat/ChatSystem/ChatEdit.lua");
local ChatEdit = commonlib.gettable("MyCompany.Aries.ChatSystem.ChatEdit");
-- local SmileyPage = commonlib.gettable("MyCompany.Aries.ChatSystem.SmileyPage");
local ItemManager = commonlib.gettable("Map3DSystem.Item.ItemManager");

local symbols = {}
local gsid_map = {};

NPL.load("(gl)script/ide/AudioEngine/AudioEngine.lua");
local AudioEngine = commonlib.gettable("AudioEngine");

NPL.load("(gl)script/Truck/Game/ModuleManager.lua");
local ModuleManager = commonlib.gettable("Mod.Truck.Game.ModuleManager");

local UIManager = commonlib.gettable("Mod.Truck.Game.UI.UIManager");

local UIBase = commonlib.gettable("Mod.Truck.Game.UI.UIBase");
local SmileyPage = commonlib.inherit(UIBase,commonlib.gettable("MyCompany.Aries.ChatSystem.SmileyPage"));

UIManager.registerUI("SmileyPage", SmileyPage,"script/apps/Aries/BBSChat/ChatSystem/SmileyPage.teen.html",
{
	allowDrag = true,
	directPosition = true,
	align = "_lt",
	x = 0,
	y = 180,
	width = 260,
	height = 200,
});
local paras
function SmileyPage:onCreate(p)
	paras = p
	if paras and paras.x and paras.y then
		self:setPosition(paras.x,paras.y)
	end
	self:InitSmileyConfig()
	self:refresh()
end
function SmileyPage:InitSmileyConfig()
	if symbols and next(symbols) then
		return
	end
	symbols = {}
	local config = commonlib.gettable("Mod.Truck.Config");
	local pages = config.SmileyConfig.symbols
	local page_size = pages:size()
	for i = 1,page_size do
		symbols[i] = pages:get(i)
	end
	local index, item
	for index, item in ipairs(symbols) do
		gsid_map[tonumber(item.gsid)] = item;
	end
end
function SmileyPage:DS_Func_Items(index)
	if(not symbols)then return 0 end
	if(index == nil) then
		return #(symbols);
	else
		return symbols[index];
	end
end
-- function SmileyPage:ShowPage()
-- 	local self = SmileyPage;
-- 	self.last_caret = ChatEdit.GetCurCaretPosition();

-- 	local x,y,width, height = _guihelper.GetLastUIObjectPos();
-- 	x = x+width/2-15;
-- 	if(x<0) then
-- 		x = 0;
-- 	end
-- 	local params = {
-- 			url = "script/apps/Aries/BBSChat/ChatSystem/SmileyPage.teen.html", 
-- 			name = "SmileyPage.ShowPage", 
-- 			app_key=MyCompany.Aries.app.app_key, 
-- 			isShowTitleBar = false,
-- 			DestroyOnClose = true, -- prevent many ViewProfile pages staying in memory
-- 			style = CommonCtrl.WindowFrame.ContainerStyle,
-- 			zorder = 2,
-- 			enable_esc_key = true,
-- 			isTopLevel = false,
-- 			allowDrag = true,
-- 			directPosition = true,
-- 				align = "_lt",
-- 				x = x,
-- 				y = y-180,
-- 				width = 250,
-- 				height = 180,
-- 		};

-- 	System.App.Commands.Call("File.MCMLWindowFrame", params);
-- end

-- for kids version only. 
function SmileyPage:ShowPage_Kids(bShow)
	local x,y,width, height = _guihelper.GetLastUIObjectPos();
	x = x+width/2-65;
	if(x<0) then
		x = 0;
	end
	width, height = 275, 177;
	local _mainWnd = ParaUI.GetUIObject("AriesSmileySelector");
	
	if(_mainWnd:IsValid() == false) then
		if(bShow == false) then
			return;
		end
		
		_mainWnd = ParaUI.CreateUIObject("container", "AriesSmileySelector", "_fi", 0,0,0,0);
		_mainWnd.background = "";
		_mainWnd.zorder = 1;
		_mainWnd:AttachToRoot();
		
		_mainWnd.onmouseup = [[;MyCompany.Aries.Desktop.Dock.OnClickSmiley(false);]];
		
		local _content = ParaUI.CreateUIObject("container", "Content", "_lt", x, y-height, width, height);
		
		_content.background = "";
		_content.zorder = 1;
		_mainWnd:AddChild(_content);
		
		local contentPage = System.mcml.PageCtrl:new({url = "script/apps/Aries/BBSChat/ChatSystem/SmileyPage.kids.html"});
		contentPage:Create("SmileySelector", _content, "_fi", 0, 0, 0, 0);
	else
		-- toggle visibility if bShow is nil
		if(bShow == nil) then
			bShow = not _mainWnd.visible;
		end
		_mainWnd.visible = bShow;
		if(bShow) then
			_mainWnd:GetChild("Content"):Reposition("_lt", x, y-height, width, height)
		end
	end
end

function SmileyPage:SendSmiley(index)
	if(not index)then return end
	local node = symbols[index] or {};
	--ChatEdit.InsertSymbol(node.symbol,self.last_caret);
	--直接发送
	-- ChatChannel.SendMessage( ChatChannel.EnumChannels.NearBy, nil, nil, node.symbol );
	NPL.load("(gl)script/Truck/Game/UI/UIManager.lua");
	local UIManager= commonlib.gettable("Mod.Truck.Game.UI.UIManager");
	local chatUI = UIManager.getUI("FriendChat")
	if chatUI then
		chatUI:SetChatText(node.symbol)
	end
end

function SmileyPage:DoClick(index)
	if paras and paras.callback then
		local node = symbols[index]
		paras.callback(node.symbol)
	end
	self:SendSmiley(index)
	self:close()
end

function SmileyPage.HasSymbol(s)
	if(not s)then return end
	if(string.find(s,"$[0-9]"))then
		return true;
	end	
end

-- remove gsid that is not owned by the current user
function SmileyPage.RemoveNotOwnedGsid(s)
	if(not SmileyPage.HasSymbol(s))then
		return s;
	end
	local pre_text, gsid, post_text;
	local out = {};
	for pre_text, gsid, post_text in s:gmatch("([^$]*)$(%d+)([^$]*)") do
		out[#out+1] = pre_text;
		gsid = tonumber(gsid);
		if(gsid) then
			local item = gsid_map[gsid];
			if(not item) then
				local gsItem = ItemManager.GetGlobalStoreItemInMemory(gsid);
				if(gsItem) then
					if(gsItem.template.cangift and gsItem.template.canexchange) then
						-- only allow tradable items to be displayed this way, to prevent user sending other unnecessary stuff. 
						local bHas = ItemManager.IfOwnGSItem(gsid);
						if(bHas) then
							out[#out+1] = format("$%d", gsid);
						end
					end
				end
			else
				out[#out+1] = format("$%d", gsid);
			end
		end
		out[#out+1] = post_text;
	end
	return table.concat(out);
end

-- remove smiley symbol, but leaves gsid symbols
-- @param bCheckOwn: if true, the current user must own the smiley 
function SmileyPage.RemoveSmiley(s)
	if(not SmileyPage.HasSymbol(s))then
		return s;
	end

	local pre_text, gsid, post_text;
	local out = {};
	for pre_text, gsid, post_text in s:gmatch("([^$]*)$(%d+)([^$]*)") do
		out[#out+1] = pre_text;
		gsid = tonumber(gsid);
		if(gsid) then
			local item = gsid_map[gsid];
			if(not item) then
				local gsItem = ItemManager.GetGlobalStoreItemInMemory(gsid);
				if(gsItem) then
					if(gsItem.template.cangift and gsItem.template.canexchange) then
						-- only allow tradable items to be displayed this way, to prevent user sending other unnecessary stuff. 
						out[#out+1] = format("$%d", gsid);
					end
				end
			end
		end
		out[#out+1] = post_text;
	end
	return table.concat(out);
end

function SmileyPage.ChangeToMcml(s, icon_size)
	SmileyPage.InitSmileyConfig()
	if(not SmileyPage.HasSymbol(s))then
		return s;
	end
	icon_size = icon_size or 32;

	local pre_text, gsid, post_text;
	local out = {};
	for pre_text, gsid, post_text in s:gmatch("([^$]*)$(%d+)([^$]*)") do
		out[#out+1] = pre_text;
		gsid = tonumber(gsid);
		if(gsid) then
			local item = gsid_map[gsid];
			if(item) then
				local icon = item.icon;
				local symbol = item.symbol;
				local img = string.format([[<img style='width:%dpx;height:%dpx;background:url(%s)' />]],icon_size,icon_size, icon);
				out[#out+1] = img;
			else
				local itemname = CommonCtrl.GenericTooltip.GetItemMCMLText(gsid,nil, nil, "class='bordertext'");
				if(itemname) then
					local gsItem = ItemManager.GetGlobalStoreItemInMemory(gsid);
					if(gsItem) then
						local pure_name = gsItem.template.name;
						if(gsItem.template.cangift and gsItem.template.canexchange) then
							-- only allow tradable items to be displayed this way, to prevent user sending other unnecessary stuff. 
							if(itemname and not pure_name:match("未使用") and not pure_name:match("废弃") and not pure_name:match("废除")) then
								out[#out+1] = itemname;
							end
						end
					end
				end
			end
		end
		out[#out+1] = post_text;
	end
	return table.concat(out);
end
