--[[
Title: deferred shading final composite effect 
Author(s): LiXizhi
Date: 2013/10/10
Desc: Reconstructing 3d position from view space depth data and do deferred shading effect on the quad. 
use the lib:
------------------------------------------------------------
NPL.load("(gl)script/apps/Aries/Creator/Game/Shaders/FancyPostProcessing.lua");
local FancyV1 = GameLogic.GetShaderManager():GetFancyShader();
-------------------------------------------------------
]]
NPL.load("(gl)script/apps/Aries/Creator/Game/game_logic.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Commands/CommandManager.lua");
local CommandManager = commonlib.gettable("MyCompany.Aries.Game.CommandManager");
local GameLogic = commonlib.gettable("MyCompany.Aries.Game.GameLogic")

NPL.load("(gl)script/apps/Aries/Creator/Game/Effects/ShaderEffectBase.lua");
local FancyV1 = commonlib.inherit(commonlib.gettable("MyCompany.Aries.Game.Effects.ShaderEffectBase"), commonlib.gettable("MyCompany.Aries.Game.Shaders.FancyV1"));
FancyV1:Property({"name", "Fancy",});
FancyV1:Property({"BloomEffect", false, "HasBloomEffect", "EnableBloomEffect", auto=true});
FancyV1:Property({"DepthOfViewEffect", false, "HasDepthOfViewEffect", "EnableDepthOfViewEffect", auto=true});
FancyV1:Property({"DepthOfViewFactor", 0.01, "GetDepthOfViewFactor", "SetDepthOfViewFactor", auto=true});
FancyV1:Property({"EyeBrightness", 0.5, auto=true, desc="(0-1), used for HDR tone mapping"});
FancyV1:Property({"BloomScale", 1.1, "GetBloomScale", "SetBloomScale", auto=true});
FancyV1:Property({"BloomCount", 2, "GetBloomCount", "SetBloomCount", auto=true});
FancyV1:Property({"AOFactor", 0.8, "GetAOFactor", "SetAOFactor", auto=true});
FancyV1:Property({"AOWidth", 0.2, "GetAOWidth", "SetAOWidth", auto=true});
FancyV1:Property({"HDRLuminance", 0.08, "GetHDRLuminance", "SetHDRLuminance", auto=true});
FancyV1:Property({"HDRMiddleGray", 0.18, "GetHDRMiddleGray", "SetHDRMiddleGray", auto=true});
FancyV1:Property({"HDRBrightThreshold", 1, "GetHDRBrightThreshold", "SetHDRBrightThreshold", auto=true});
FancyV1:Property({"HDRBrightOffset", 1, "GetHDRBrightOffset", "SetHDRBrightOffset", auto=true});
FancyV1:Property({"CustomLightColour0", {0,0,0}, "GetCustomLightColour0", "SetCustomLightColour0", auto=true});
FancyV1:Property({"CustomLightColour1", {0,0,0}, "GetCustomLightColour1", "SetCustomLightColour1", auto=true});
FancyV1:Property({"CustomLightColour2", {0,0,0}, "GetCustomLightColour2", "SetCustomLightColour2", auto=true});
FancyV1:Property({"CustomLightColour3", {0,0,0}, "GetCustomLightColour3", "SetCustomLightColour3", auto=true});
FancyV1:Property({"CustomLightDirection0", {0,0,0}, "GetCustomLightDirection0", "SetCustomLightDirection0", auto=true});
FancyV1:Property({"CustomLightDirection1", {0,0,0}, "GetCustomLightDirection1", "SetCustomLightDirection1", auto=true});
FancyV1:Property({"CustomLightDirection2", {0,0,0}, "GetCustomLightDirection2", "SetCustomLightDirection2", auto=true});
FancyV1:Property({"CustomLightDirection3", {0,0,0}, "GetCustomLightDirection3", "SetCustomLightDirection3", auto=true});

FancyV1.BlockRenderMethod = {
	FixedFunction = 0,
	Standard = 1,
	Fancy = 2,
}

local lTimeParameters;
local function _loadFromFile(filePath)
  local time_parameters=nil;
  local xml_root = ParaXML.LuaXML_ParseFile(filePath);
  if xml_root then
    time_parameters={};
    for time_node in commonlib.XPath.eachNode(xml_root,"/parameters/time") do
      local node=commonlib.XPath.selectNode(time_node,"/lighting");
      if node then
        time_parameters[#time_parameters+1]={};
        time_parameters[#time_parameters].time=tonumber(time_node.attr.value);
        if node.attr.ambientr and node.attr.ambientg and node.attr.ambientb then
          time_parameters[#time_parameters].ambient={tonumber(node.attr.ambientr),tonumber(node.attr.ambientg),tonumber(node.attr.ambientb)};
        end
        if node.attr.sundiffuser and node.attr.sundiffuseg and node.attr.sundiffuseb then
          time_parameters[#time_parameters].sundiffuse={tonumber(node.attr.sundiffuser),tonumber(node.attr.sundiffuseg),tonumber(node.attr.sundiffuseb)};
        end
        if node.attr.sunintensity then
          time_parameters[#time_parameters].sunintensity=tonumber(node.attr.sunintensity);
        end
        if node.attr.shadowradius then
          time_parameters[#time_parameters].shadowradius=tonumber(node.attr.shadowradius);
        end
        node=commonlib.XPath.selectNode(time_node,"/bloom");
        if node then
          if node.attr.bloomscale then
            time_parameters[#time_parameters].bloomscale=tonumber(node.attr.bloomscale);
          end
          if node.attr.bloomcount then
            time_parameters[#time_parameters].bloomcount=tonumber(node.attr.bloomcount);
          end
        end
        node=commonlib.XPath.selectNode(time_node,"/ao");
        if node then
          if node.attr.aofactor then
            time_parameters[#time_parameters].aofactor=tonumber(node.attr.aofactor);
          end
          if node.attr.aowidth then
            time_parameters[#time_parameters].aowidth=tonumber(node.attr.aowidth);
          end
        end
        node=commonlib.XPath.selectNode(time_node,"/fog");
        if node then
          if node.attr.colorr and node.attr.colorg and node.attr.colorb then
            time_parameters[#time_parameters].fogcolor={tonumber(node.attr.colorr),tonumber(node.attr.colorg),tonumber(node.attr.colorb)};
          end
        end
        node=commonlib.XPath.selectNode(time_node,"/hdr");
        if node then
          if node.attr.luminance then
            time_parameters[#time_parameters].HDRLuminance=tonumber(node.attr.luminance);
          end
          if node.attr.middlegray then
            time_parameters[#time_parameters].HDRMiddleGray=tonumber(node.attr.middlegray);
          end
          if node.attr.brightthreshold then
            time_parameters[#time_parameters].HDRBrightThreshold=tonumber(node.attr.brightthreshold);
          end
          if node.attr.brightoffset then
            time_parameters[#time_parameters].HDRBrightOffset=tonumber(node.attr.brightoffset);
          end
        end
        node=commonlib.XPath.selectNode(time_node,"/customlight0");
        if node then
          if node.attr.colourr and node.attr.colourg and node.attr.colourb then
            time_parameters[#time_parameters].CustomLightColour0={tonumber(node.attr.colourr),tonumber(node.attr.colourg),tonumber(node.attr.colourb)};
          end
          if node.attr.directionx and node.attr.directiony and node.attr.directionz then
            time_parameters[#time_parameters].CustomLightDirection0={tonumber(node.attr.directionx),tonumber(node.attr.directiony),tonumber(node.attr.directionz)};
          end
        end
        node=commonlib.XPath.selectNode(time_node,"/customlight1");
        if node then
          if node.attr.colourr and node.attr.colourg and node.attr.colourb then
            time_parameters[#time_parameters].CustomLightColour1={tonumber(node.attr.colourr),tonumber(node.attr.colourg),tonumber(node.attr.colourb)};
          end
          if node.attr.directionx and node.attr.directiony and node.attr.directionz then
            time_parameters[#time_parameters].CustomLightDirection1={tonumber(node.attr.directionx),tonumber(node.attr.directiony),tonumber(node.attr.directionz)};
          end
        end
        node=commonlib.XPath.selectNode(time_node,"/customlight2");
        if node then
          if node.attr.colourr and node.attr.colourg and node.attr.colourb then
            time_parameters[#time_parameters].CustomLightColour2={tonumber(node.attr.colourr),tonumber(node.attr.colourg),tonumber(node.attr.colourb)};
          end
          if node.attr.directionx and node.attr.directiony and node.attr.directionz then
            time_parameters[#time_parameters].CustomLightDirection2={tonumber(node.attr.directionx),tonumber(node.attr.directiony),tonumber(node.attr.directionz)};
          end
        end
        node=commonlib.XPath.selectNode(time_node,"/customlight3");
        if node then
          if node.attr.colourr and node.attr.colourg and node.attr.colourb then
            time_parameters[#time_parameters].CustomLightColour3={tonumber(node.attr.colourr),tonumber(node.attr.colourg),tonumber(node.attr.colourb)};
          end
          if node.attr.directionx and node.attr.directiony and node.attr.directionz then
            time_parameters[#time_parameters].CustomLightDirection3={tonumber(node.attr.directionx),tonumber(node.attr.directiony),tonumber(node.attr.directionz)};
          end
        end
      end
    end
  end
  return time_parameters;
end

function FancyV1:ctor()
  lTimeParameters=_loadFromFile("config/Fancy.xml");
  self.mTimeParameters=lTimeParameters;
end

-- return true if succeed. 
function FancyV1:SetEnabled(bEnable)
	if(bEnable) then
		local res, reason = FancyV1.IsHardwareSupported();
		if(res) then
			ParaTerrain.GetBlockAttributeObject():SetField("PostProcessingScript", "MyCompany.Aries.Game.Shaders.FancyV1.OnRender(0)")
			ParaTerrain.GetBlockAttributeObject():SetField("PostProcessingAlphaScript", "MyCompany.Aries.Game.Shaders.FancyV1.OnRender(1)")
			--ParaTerrain.GetBlockAttributeObject():SetField("UseSunlightShadowMap", true);
			--ParaTerrain.GetBlockAttributeObject():SetField("UseWaterReflection", true);
			self:SetBlockRenderMethod(self.BlockRenderMethod.Fancy);
			return true;
		elseif(reason == "AA_IS_ON") then
			ParaEngine.GetAttributeObject():SetField("MultiSampleType", 0);
			ParaEngine.WriteConfigFile("config/config.txt");
			LOG.std(nil, "info", "FancyV1", "MultiSampleType must be 0 in order to use deferred shading. We have set it for you. you must restart. ");
			_guihelper.MessageBox("抗锯齿已经关闭, 请重启客户端");
		end
	else
		ParaTerrain.GetBlockAttributeObject():SetField("PostProcessingScript", "");
		self:SetBlockRenderMethod(self.BlockRenderMethod.Standard);
		return true;
	end
end

function FancyV1:IsEnabled()
	return ParaTerrain.GetBlockAttributeObject():GetField("BlockRenderMethod", 1) == 2;
end

-- @param shader_method: type of BlockRenderMethod: 0 fixed function; 1 standard; 2 fancy graphics.
function FancyV1:SetBlockRenderMethod(method)
	ParaTerrain.GetBlockAttributeObject():SetField("BlockRenderMethod", method);
end

-- static function: 
function FancyV1.IsHardwareSupported()
	if( ParaTerrain.GetBlockAttributeObject():GetField("CanUseAdvancedShading", false) ) then
		-- must disable AA. 
		if(ParaEngine.GetAttributeObject():GetField("MultiSampleType", 0) ~= 0) then
			LOG.std(nil, "info", "FancyV1", "MultiSampleType must be 0 in order to use deferred shading. ");
			
			return false, "AA_IS_ON";
		end
		local effect = ParaAsset.LoadEffectFile("composite","script/apps/Aries/Creator/Game/Shaders/composite.fxo");
		effect:LoadAsset();
		return effect:IsValid();		
	end
	return false;
end

----------------------------
-- shader uniforms
----------------------------
local sun_diffuse = {1,1,1};
local sun_color = {1,1,1};
local timeOfDaySTD = 0;
local timeNoon = 0;
local timeMidnight = 0;
-- compute according to current setting. 
function FancyV1:ComputeShaderUniforms(bIsHDRShader)
	timeOfDaySTD = ParaScene.GetTimeOfDaySTD();
	timeNoon = math.max(0, (0.5 - math.abs(timeOfDaySTD)) * 2.0);
	timeMidnight = math.max(0, (math.abs(timeOfDaySTD) - 0.5) * 2.0);
	if(bIsHDRShader) then
		local att = ParaScene.GetAttributeObjectSunLight();
		sun_diffuse = att:GetField("Diffuse", sun_diffuse);
		sun_color[1] = sun_diffuse[1] * timeNoon * 1.6;
		sun_color[2] = sun_diffuse[2] * timeNoon * 1.6;
		sun_color[3] = sun_diffuse[3] * timeNoon * 1.6;
		-- colorSunlight = sunrise_sun * timeSunrise  +  noon_sun * timeNoon  +  sunset_sun * timeSunset  +  midnight_sun * timeMidnight;
	end
end

-- static function: engine callback function
-- @param nPass: 0 for opache pass, 1 for alpha blended pass. 
function FancyV1.OnRender(nPass)
  GameLogic.GetShaderManager():GetFancyShader():updateTimeParameters();
	local ps_scene = ParaScene.GetPostProcessingScene();
	GameLogic.GetShaderManager():GetFancyShader():OnCompositeQuadRendering(ps_scene, nPass);
end

-- @param nPass: 0 for opache pass, 1 for alpha blended pass. 
function FancyV1:OnRenderLite(ps_scene, nPass)
	--[[if(nPass and nPass >= 1) then
		-- no need to alpha pass.
		return;
	end]]

	local effect = ParaAsset.LoadEffectFile("compositeLite","script/apps/Aries/Creator/Game/Shaders/compositeLite.fxo");
	effect = ParaAsset.GetEffectFile("compositeLite");
		
	if(effect:Begin()) then
		-- 0 stands for S0_POS_TEX0,  all data in stream 0: position and tex0
		ParaEngine.SetVertexDeclaration(0); 

		-- save the current render target
		local old_rt = ParaEngine.GetRenderTarget();
    ParaEngine.SetRenderTarget2(1,"");
    ParaEngine.SetRenderTarget2(2,"");
    ParaEngine.SetRenderTarget2(3,"");
			
		-- create/get a temp render target: "_ColorRT" is an internal name 
		local _ColorRT = ParaAsset.LoadTexture("_ColorRT", "_ColorRT", 0); 
			
		----------------------- down sample pass ----------------
		-- copy content from one surface to another
		ParaEngine.StretchRect(old_rt, _ColorRT);
			
		local attr = ParaTerrain.GetBlockAttributeObject();
		local params = effect:GetParamBlock();
		self:ComputeShaderUniforms();
		params:SetParam("mShadowMapTex", "mat4ShadowMapTex");
		params:SetParam("mShadowMapViewProj", "mat4ShadowMapViewProj");
		params:SetParam("ShadowMapSize", "vec2ShadowMapSize");
		params:SetParam("ShadowRadius", "floatShadowRadius");
		
		params:SetParam("gbufferProjectionInverse", "mat4ProjectionInverse");
		params:SetParam("screenParam", "vec2ScreenSize");
			
		params:SetParam("matView", "mat4View");
		params:SetParam("matViewInverse", "mat4ViewInverse");
		params:SetParam("matProjection", "mat4Projection");
		
		params:SetParam("g_FogColor", "vec3FogColor");
		params:SetParam("ViewAspect", "floatViewAspect");
		params:SetParam("TanHalfFOV", "floatTanHalfFOV");
		params:SetParam("cameraFarPlane", "floatCameraFarPlane");
		params:SetFloat("FogStart", GameLogic.options:GetFogStart());
		params:SetFloat("FogEnd", GameLogic.options:GetFogEnd());

		params:SetFloat("timeMidnight", timeMidnight);
		local sunIntensity = attr:GetField("SunIntensity", 1);
		params:SetFloat("sunIntensity", sunIntensity);
		
		params:SetParam("gbufferWorldViewProjectionInverse", "mat4WorldViewProjectionInverse");
		params:SetParam("cameraPosition", "vec3cameraPosition");
		params:SetParam("sunDirection", "vec3SunDirection");
    params:SetParam("sunAmbient", "vec3SunAmbient");
		params:SetVector3("RenderOptions", 
			if_else(attr:GetField("UseSunlightShadowMap", false),1,0), 
			if_else(attr:GetField("UseWaterReflection", false),1,0),
			0);
		params:SetParam("TorchLightColor", "vec3BlockLightColor");
		params:SetParam("SunColor", "vec3SunColor");
		params:SetVector2("AOParam", self:GetAOFactor(),self:GetAOWidth());
    params:SetVector3("CustomLightColour0",self:GetCustomLightColour0()[1],self:GetCustomLightColour0()[2],self:GetCustomLightColour0()[3]);
    params:SetVector3("CustomLightColour1",self:GetCustomLightColour1()[1],self:GetCustomLightColour1()[2],self:GetCustomLightColour1()[3]);
    params:SetVector3("CustomLightColour2",self:GetCustomLightColour2()[1],self:GetCustomLightColour2()[2],self:GetCustomLightColour2()[3]);
    params:SetVector3("CustomLightColour3",self:GetCustomLightColour3()[1],self:GetCustomLightColour3()[2],self:GetCustomLightColour3()[3]);
    params:SetVector3("CustomLightDirection0",self:GetCustomLightDirection0()[1],self:GetCustomLightDirection0()[2],self:GetCustomLightDirection0()[3]);
    params:SetVector3("CustomLightDirection1",self:GetCustomLightDirection1()[1],self:GetCustomLightDirection1()[2],self:GetCustomLightDirection1()[3]);
    params:SetVector3("CustomLightDirection2",self:GetCustomLightDirection2()[1],self:GetCustomLightDirection2()[2],self:GetCustomLightDirection2()[3]);
    params:SetVector3("CustomLightDirection3",self:GetCustomLightDirection3()[1],self:GetCustomLightDirection3()[2],self:GetCustomLightDirection3()[3]);
								
		-----------------------compose lum texture with original texture --------------
		ParaEngine.SetRenderTarget(old_rt);
		
		effect:BeginPass(nPass);
			-- color render target. 
			params:SetTextureObj(0, _ColorRT);
			-- entity and lighting texture
			params:SetTextureObj(1, ParaAsset.LoadTexture("_BlockInfoRT", "_BlockInfoRT", 0));
			-- shadow map
			params:SetTextureObj(2, ParaAsset.LoadTexture("_SMColorTexture_R32F", "_SMColorTexture_R32F", 0));
			-- depth texture 
			params:SetTextureObj(3, ParaAsset.LoadTexture("_DepthTexRT_R32F", "_DepthTexRT_R32F", 0));
			-- normal texture 
			params:SetTextureObj(4, ParaAsset.LoadTexture("_NormalRT", "_NormalRT", 0));

			effect:CommitChanges();
			ParaEngine.DrawQuad();
		effect:EndPass();
    if nPass == 1 then
      ParaEngine.StretchRect(old_rt, _ColorRT);
      effect:BeginPass(2);
        -- color render target. 
        params:SetTextureObj(0, _ColorRT);
        effect:CommitChanges();
        ParaEngine.DrawQuad();
      effect:EndPass();
    end
		-- Make sure the render target isn't still set as a source texture
		-- this will prevent d3d warning in debug mode
		effect:SetTexture(0, "");
		effect:SetTexture(1, "");
		effect:SetTexture(2, "");
		effect:SetTexture(3, "");
		effect:SetTexture(4, "");
		effect:End();
	else
		-- revert to normal effect. 
		self:GetEffectManager():SetShaders(1);
	end
end

function FancyV1:OnRenderHighWithHDR(ps_scene, nPass)
	local effect = ParaAsset.LoadEffectFile("composite","script/apps/Aries/Creator/Game/Shaders/composite.fxo");
	effect = ParaAsset.GetEffectFile("composite");
  if(effect:Begin()) then
    -- 0 stands for S0_POS_TEX0,  all data in stream 0: position and tex0
    ParaEngine.SetVertexDeclaration(0); 

    -- save the current render target
    local old_rt = ParaEngine.GetRenderTarget();
    ParaEngine.SetRenderTarget2(1,"");
    ParaEngine.SetRenderTarget2(2,"");
    ParaEngine.SetRenderTarget2(3,"");
        
    -- create/get a temp render target: "_ColorRT" is an internal name
    local screen_size = ParaUI.GetUIObject("root"):GetAttributeObject():GetField("BackBufferSize", {800, 600});
    local _ColorRT = ParaAsset.LoadTexture("_ColorRT", "_ColorRT", 0); 
    local _CompositeRT_DownScale4x4 = ParaAsset.LoadTexture("_CompositeRT_DownScale4x4", "_CompositeRT_DownScale4x4", 0);
    _CompositeRT_DownScale4x4:SetSize(screen_size[1]/4,screen_size[2]/4);
    local _CompositeRT_DownScale16x16_0 = ParaAsset.LoadTexture("_CompositeRT_DownScale16x16_0", "_CompositeRT_DownScale16x16_0", 0);
    _CompositeRT_DownScale16x16_0:SetSize(_CompositeRT_DownScale4x4:GetWidth()/4,_CompositeRT_DownScale4x4:GetHeight()/4);
    local _CompositeRT_DownScale16x16_1 = ParaAsset.LoadTexture("_CompositeRT_DownScale16x16_1", "_CompositeRT_DownScale16x16_1", 0);
    _CompositeRT_DownScale16x16_1:SetSize(_CompositeRT_DownScale16x16_0:GetWidth(),_CompositeRT_DownScale16x16_0:GetHeight());
    ----------------------- down sample pass ----------------
    -- copy content from one surface to another
    ParaEngine.StretchRect(old_rt, _ColorRT);
        
    local attr = ParaTerrain.GetBlockAttributeObject();
    local params = effect:GetParamBlock();
    self:ComputeShaderUniforms();
    params:SetParam("mShadowMapTex", "mat4ShadowMapTex");
    params:SetParam("mShadowMapViewProj", "mat4ShadowMapViewProj");
    params:SetParam("ShadowMapSize", "vec2ShadowMapSize");
    params:SetParam("ShadowRadius", "floatShadowRadius");
      
    params:SetParam("gbufferProjectionInverse", "mat4ProjectionInverse");
    params:SetParam("screenParam", "vec2ScreenSize");
      
    params:SetParam("matView", "mat4View");
    params:SetParam("matViewInverse", "mat4ViewInverse");
    params:SetParam("matProjection", "mat4Projection");
    
    params:SetParam("g_FogColor", "vec3FogColor");
    params:SetParam("ViewAspect", "floatViewAspect");
    params:SetParam("TanHalfFOV", "floatTanHalfFOV");
    params:SetParam("cameraFarPlane", "floatCameraFarPlane");
    params:SetFloat("FogStart", GameLogic.options:GetFogStart());
    params:SetFloat("FogEnd", GameLogic.options:GetFogEnd());
    params:SetFloat("timeMidnight", timeMidnight);
    local sunIntensity = attr:GetField("SunIntensity", 1);
    params:SetFloat("sunIntensity", sunIntensity);
    
    params:SetParam("gbufferWorldViewProjectionInverse", "mat4WorldViewProjectionInverse");
    params:SetParam("cameraPosition", "vec3cameraPosition");
    params:SetParam("sunDirection", "vec3SunDirection");
    params:SetParam("sunAmbient", "vec3SunAmbient");
    params:SetVector3("RenderOptions", 
      if_else(attr:GetField("UseSunlightShadowMap", false),1,0), 
      if_else(attr:GetField("UseWaterReflection", false),1,0),
      0);
    params:SetParam("TorchLightColor", "vec3BlockLightColor");
    params:SetParam("SunColor", "vec3SunColor");
		params:SetVector2("AOParam", self:GetAOFactor(),self:GetAOWidth());
    params:SetVector3("CustomLightColour0",self:GetCustomLightColour0()[1],self:GetCustomLightColour0()[2],self:GetCustomLightColour0()[3]);
    params:SetVector3("CustomLightColour1",self:GetCustomLightColour1()[1],self:GetCustomLightColour1()[2],self:GetCustomLightColour1()[3]);
    params:SetVector3("CustomLightColour2",self:GetCustomLightColour2()[1],self:GetCustomLightColour2()[2],self:GetCustomLightColour2()[3]);
    params:SetVector3("CustomLightColour3",self:GetCustomLightColour3()[1],self:GetCustomLightColour3()[2],self:GetCustomLightColour3()[3]);
    params:SetVector3("CustomLightDirection0",self:GetCustomLightDirection0()[1],self:GetCustomLightDirection0()[2],self:GetCustomLightDirection0()[3]);
    params:SetVector3("CustomLightDirection1",self:GetCustomLightDirection1()[1],self:GetCustomLightDirection1()[2],self:GetCustomLightDirection1()[3]);
    params:SetVector3("CustomLightDirection2",self:GetCustomLightDirection2()[1],self:GetCustomLightDirection2()[2],self:GetCustomLightDirection2()[3]);
    params:SetVector3("CustomLightDirection3",self:GetCustomLightDirection3()[1],self:GetCustomLightDirection3()[2],self:GetCustomLightDirection3()[3]);
                        
    if nPass==0 then
      --lighting,shadowing and shading
      effect:BeginPass(0);
        -- color render target. 
        params:SetTextureObj(0, _ColorRT);
        -- entity and lighting texture
        params:SetTextureObj(1, ParaAsset.LoadTexture("_BlockInfoRT", "_BlockInfoRT", 0));
        -- shadow map
        params:SetTextureObj(2, ParaAsset.LoadTexture("_SMColorTexture_R32F", "_SMColorTexture_R32F", 0));
        -- depth texture 
        params:SetTextureObj(3, ParaAsset.LoadTexture("_DepthTexRT_R32F", "_DepthTexRT_R32F", 0));
        -- normal texture 
        params:SetTextureObj(4, ParaAsset.LoadTexture("_NormalRT", "_NormalRT", 0));

        effect:CommitChanges();
        ParaEngine.DrawQuad();
      effect:EndPass();
      ParaEngine.StretchRect(old_rt, _ColorRT);
    elseif nPass==1 then
      --lighting,shadowing and shading
      effect:BeginPass(1);
        -- color render target. 
        params:SetTextureObj(0, _ColorRT);
        -- entity and lighting texture
        params:SetTextureObj(1, ParaAsset.LoadTexture("_BlockInfoRT", "_BlockInfoRT", 0));
        -- shadow map
        params:SetTextureObj(2, ParaAsset.LoadTexture("_SMColorTexture_R32F", "_SMColorTexture_R32F", 0));
        -- depth texture 
        params:SetTextureObj(3, ParaAsset.LoadTexture("_DepthTexRT_R32F", "_DepthTexRT_R32F", 0));
        -- normal texture 
        params:SetTextureObj(4, ParaAsset.LoadTexture("_NormalRT", "_NormalRT", 0));

        effect:CommitChanges();
        ParaEngine.DrawQuad();
      effect:EndPass();
      --gamma
      ParaEngine.StretchRect(old_rt, _ColorRT);
      effect:BeginPass(2);
        -- color render target. 
        params:SetTextureObj(0, _ColorRT);
        effect:CommitChanges();
        ParaEngine.DrawQuad();
      effect:EndPass();
      ParaEngine.StretchRect(old_rt, _ColorRT);
      --downscale 4x4
      ParaEngine.StretchRect(old_rt, _CompositeRT_DownScale4x4);
      --downscale 4x4
      ParaEngine.StretchRect(_CompositeRT_DownScale4x4, _CompositeRT_DownScale16x16_0);
      --bright pass
      ParaEngine.SetRenderTarget(_CompositeRT_DownScale16x16_1);
      effect:BeginPass(3);
        -- color render target.
        params:SetVector4("HDRParameter",self:GetHDRLuminance(),self:GetHDRMiddleGray(),self:GetHDRBrightThreshold(),self:GetHDRBrightOffset());
        params:SetTextureObj(0, _CompositeRT_DownScale16x16_0);
        effect:CommitChanges();
        ParaEngine.DrawQuad(1);
      effect:EndPass();
      params:SetVector4("TextureSize0", _CompositeRT_DownScale16x16_0:GetWidth(),_CompositeRT_DownScale16x16_0:GetHeight(),1/_CompositeRT_DownScale16x16_0:GetWidth(),1/_CompositeRT_DownScale16x16_0:GetHeight());
      params:SetFloat("BloomScale",self:GetBloomScale());
      for i=1,self:GetBloomCount() do
        --h bloom
        ParaEngine.SetRenderTarget(_CompositeRT_DownScale16x16_0);
        effect:BeginPass(4);
          -- color render target. 
          params:SetTextureObj(0, _CompositeRT_DownScale16x16_1);
          effect:CommitChanges();
          ParaEngine.DrawQuad(1);
        effect:EndPass();
        --v bloom
        ParaEngine.SetRenderTarget(_CompositeRT_DownScale16x16_1);
        effect:BeginPass(5);
          -- color render target. 
          params:SetTextureObj(0, _CompositeRT_DownScale16x16_0);
          effect:CommitChanges();
          ParaEngine.DrawQuad(1);
        effect:EndPass();
      end
      --combine
      ParaEngine.SetRenderTarget(old_rt);
      effect:BeginPass(6);
        -- color render target. 
        params:SetTextureObj(0, _ColorRT);
        params:SetTextureObj(1, _CompositeRT_DownScale16x16_1);
        effect:CommitChanges();
        ParaEngine.DrawQuad();
      effect:EndPass();
      --fxaa
      ParaEngine.StretchRect(old_rt, _ColorRT);
      effect:BeginPass(7);
        -- color render target. 
        params:SetTextureObj(0, _ColorRT);
        effect:CommitChanges();
        ParaEngine.DrawQuad();
      effect:EndPass();
      -- this will prevent d3d warning in debug mode
      effect:SetTexture(0, "");
      effect:SetTexture(1, "");
      effect:SetTexture(2, "");
      effect:SetTexture(3, "");
      effect:SetTexture(4, "");
    end
    effect:End();
  else
      -- revert to normal effect. 
      self:GetEffectManager():SetShaders(1);
  end
end

function FancyV1:IsHDR()
	return (self:HasBloomEffect() or self:HasDepthOfViewEffect());
end

function FancyV1:OnCompositeQuadRendering(ps_scene, nPass)
	if(self:IsHDR()) then
		self:OnRenderHighWithHDR(ps_scene, nPass);
	else
		self:OnRenderLite(ps_scene, nPass)
	end
end

function FancyV1:updateTimeParameters()
  if not self.mTimeParameters then
    return;
  end
  local current_time=ParaScene.GetTimeOfDay()%(ParaScene.GetAttributeObjectSunLight():GetField("DayLength",60)*60);
  current_time=current_time/(ParaScene.GetAttributeObjectSunLight():GetField("DayLength",60)*60);
  local key1=self.mTimeParameters[1];
  local key2=key1;
  for i=1,#self.mTimeParameters do
    if self.mTimeParameters[i].time<=current_time and (not self.mTimeParameters[i+1] or self.mTimeParameters[i+1].time>=current_time) then
      key1=self.mTimeParameters[i];
      key2=self.mTimeParameters[i+1];
      break;
    end
  end
  if not key2 then
    key2=key1;
  end
  if key1 then
    local lerp_scalar=0;
    if key1.time~=key2.time then
      lerp_scalar=(current_time-key1.time)/(key2.time-key1.time);
    end
    if key1.ambient then
      ParaScene.GetAttributeObjectSunLight():SetField("Ambient", key1.ambient);
    end
    if key1.sundiffuse then
      ParaScene.GetAttributeObjectSunLight():SetField("Diffuse", key1.sundiffuse);
    end
    if key1.sunintensity then
      ParaTerrain.SetBlockWorldSunIntensity(key1.sunintensity);
    end
    if key1.shadowradius then
      ParaScene.GetAttributeObjectSunLight():SetField("ShadowRadius",key1.shadowradius);
    end
    if key1.bloomscale then
      self:SetBloomScale(key1.bloomscale);
    end
    if key1.bloomcount then
      self:SetBloomCount(key1.bloomcount);
    end
    if key1.aofactor then
      self:SetAOFactor(key1.aofactor);
    end
    if key1.aowidth then
      self:SetAOWidth(key1.aowidth);
    end
    if key1.fogcolor then
      CommandManager:RunCommand("/fog -color "..tostring(key1.fogcolor[1]).." "..tostring(key1.fogcolor[2]).." "..tostring(key1.fogcolor[3]));
    end
    if key1.HDRLuminance then
      self:SetHDRLuminance(key1.HDRLuminance)
    end
    if key1.HDRMiddleGray then
      self:SetHDRMiddleGray(key1.HDRMiddleGray)
    end
    if key1.HDRBrightThreshold then
      self:SetHDRBrightThreshold(key1.HDRBrightThreshold)
    end
    if key1.HDRBrightOffset then
      self:SetHDRBrightOffset(key1.HDRBrightOffset)
    end
    for i=0,3 do
      local key_colour="CustomLightColour"..tostring(i)
      if key1[key_colour] then
        self["Set"..key_colour](self,key1[key_colour])
      end
      local key_dir="CustomLightDirection"..tostring(i)
      if key1[key_dir] then
        self["Set"..key_dir](self,key1[key_dir])
      end
    end
  end
end

function FancyV1:setTimeParametersFile(filePath)
  self.mTimeParameters=_loadFromFile(filePath) or lTimeParameters;
end

local lStashTimeParameters=nil;
function FancyV1:stashTimeParameters()
  if not lStashTimeParameters then
    lStashTimeParameters=self.mTimeParameters;
    self.mTimeParameters=nil;
  end
end

function FancyV1:popStashTimeParameters()
  self.mTimeParameters=lStashTimeParameters;
  lStashTimeParameters=nil;
end