#include "CommonFunction.fx"
float4x4 matView;
float4x4 matViewInverse;
float4x4 matProjection;
float4x4 mShadowMapTex;
float4x4 mShadowMapViewProj;

float3  g_FogColor;
float2	g_shadowFactor = float2(0.35,0.65);
float	ShadowRadius;
// x is shadow map size(such as 2048), y = 1/x
float2  ShadowMapSize;

// x>0 use sun shadow map, y>0 use water reflection. 
float3 RenderOptions;

float2 screenParam;
float ViewAspect;
float TanHalfFOV; 
float cameraFarPlane;
float FogStart;
float FogEnd;
float3 cameraPosition;
float3 sunDirection;
float3 sunAmbient;
float3 SunColor;
float3 TorchLightColor;
float2 AOParam;
float sunIntensity = 1.0; // 1 is noon. 0 is night
float timeMidnight = 0.0; // 1 is midnight.
float4 TextureSize0;
float BloomScale;
float4 HDRParameter=float4(0.08,0.18,1,1);
float3 CustomLightColour0 = float3(0,0,0);
float3 CustomLightColour1 = float3(0,0,0);
float3 CustomLightColour2 = float3(0,0,0);
float3 CustomLightColour3 = float3(0,0,0);
float3 CustomLightDirection0 = float3(0,0,0);
float3 CustomLightDirection1 = float3(0,0,0);
float3 CustomLightDirection2 = float3(0,0,0);
float3 CustomLightDirection3 = float3(0,0,0);
texture sourceTexture0;
sampler colorSampler:register(s0) = sampler_state
{
    Texture = <sourceTexture0>;
    MinFilter = Linear;
    MagFilter = Linear;
    AddressU = clamp;
    AddressV = clamp;
};

texture sourceTexture1;
sampler matInfoSampler:register(s1) = sampler_state
{
    Texture = <sourceTexture1>;
    MinFilter = Linear;
    MagFilter = Linear;
    AddressU = clamp;
    AddressV = clamp;
};

texture sourceTexture2 : TEXTURE; 
sampler ShadowMapSampler: register(s2) = sampler_state 
{
    texture = <sourceTexture2>;
#ifdef HARDWARE_SHADOW_ENABLE
    MinFilter = Linear;  
    MagFilter = Linear;
#else
    MinFilter = Point;  
    MagFilter = Point;
#endif
    MipFilter = None;
    AddressU  = BORDER;
    AddressV  = BORDER;
    BorderColor = 0xFFFFFFFF;
};

texture sourceTexture3;
sampler depthSampler:register(s3) = sampler_state
{
    Texture = <sourceTexture3>;
    MinFilter = Linear;
    MagFilter = Linear;
    AddressU = clamp;
    AddressV = clamp;
};

texture sourceTexture4;
sampler normalSampler:register(s4) = sampler_state
{
    Texture = <sourceTexture4>;
    MinFilter = Linear;
    MagFilter = Linear;
    AddressU = clamp;
    AddressV = clamp;
};

struct VSOutput
{
  float4 pos			: POSITION;         // Screen space position
  float2 texCoord		: TEXCOORD0;        // texture coordinates
  float3 CameraEye		: TEXCOORD2;      // texture coordinates
};

float4  GetNormal(float2 texCoord) {
	float4 norm = tex2D(normalSampler, texCoord);
	return float4(decodeNormal(norm.xyz), norm.w);
}


VSOutput CompositeQuadVS(float3 iPosition:POSITION,
					float2 texCoord:TEXCOORD0)
{
	VSOutput o;
	o.pos = float4(iPosition,1);
	o.texCoord = texCoord + 0.5 / screenParam;

	// for reconstructing world position from depth value
	float3 outCameraEye = float3(iPosition.x*TanHalfFOV*ViewAspect, iPosition.y*TanHalfFOV, 1);
	o.CameraEye = outCameraEye;
	return o;
}


float2 convertCameraSpaceToScreenSpace(float3 cameraSpace) 
{
	float4 clipSpace = mul(float4(cameraSpace, 1.0), matProjection);
	float2 NDCSpace = clipSpace.xy / clipSpace.w;
	float2 ScreenPos = 0.5 * NDCSpace + 0.5;
	return float2(ScreenPos.x, 1-ScreenPos.y);
}


// compute water reflection by sampling along the reflected eye ray until a pixel is found. 
float4 	ComputeRayTraceWaterReflection(float3 cameraSpacePosition, float3 cameraSpaceNormal) 
{
	float initialStepAmount = 1;
	//float stepRefinementAmount = 0.1;
	//int maxRefinements = 0;
		 
    float3 cameraSpaceViewDir = normalize(cameraSpacePosition);
    float3 cameraSpaceVector = normalize(reflect(cameraSpaceViewDir,cameraSpaceNormal)) * initialStepAmount;
	float3 oldPosition = cameraSpacePosition;
    float3 cameraSpaceVectorPosition = oldPosition + cameraSpaceVector;
    float2 currentPosition = convertCameraSpaceToScreenSpace(cameraSpaceVectorPosition);
    float4 color = float4(0,0,0,0);
	float2 finalSamplePos = float2(0, 0);
	float ray_length = initialStepAmount;
	int numSteps = 0;
	int max_step = 12; // cameraFarPlane/initialStepAmount; 4 * (1.5^10) = 230
    while(numSteps < max_step && 
		(currentPosition.x > 0 && currentPosition.x < 1 &&
         currentPosition.y > 0 && currentPosition.y < 1))
    {
        float2 samplePos = currentPosition.xy;
        float sampleDepth = tex2Dlod(depthSampler, float4(samplePos,0,0)).r;

        float currentDepth = cameraSpaceVectorPosition.z;
		float diff = currentDepth - sampleDepth;
		
        if(diff >= 0 && sampleDepth > 0 && diff <= ray_length)
		{
			// found it, exit the loop
			finalSamplePos.xy = samplePos;
			numSteps = max_step;
		}
		else
		{
			ray_length *= 1.5;
			cameraSpaceVector *= 1.5;	//Each step gets bigger
			cameraSpaceVectorPosition += cameraSpaceVector;

			currentPosition = convertCameraSpaceToScreenSpace(cameraSpaceVectorPosition);
		}
		numSteps++;
    }
	
	if (finalSamplePos.x != 0 && finalSamplePos.y != 0) 
	{
		// compute point color
		float2 texCoord = finalSamplePos.xy;
		color = tex2D(colorSampler, texCoord);
		color.a = 1;
		// r:category id,  g: sun light value, b: torch light value
		float4 block_info = tex2D(matInfoSampler, texCoord);
		int category_id = (int)(block_info.r * 255.0 + 0.4);
		float sun_light_strength = block_info.g*sunIntensity;
		float torch_light_strength = block_info.b;
		
		
		// use a simple way to render lighting for reflection to avoid another water rendering pass. 
		float shadow = 1;
		if(sun_light_strength > 0)
		{
			// get world space normal
			float3 normal = GetNormal(texCoord);
			float NdotL = dot( sunDirection, normal);

			float directSunLight = max(0, NdotL);
			if(directSunLight > 0)
				shadow = directSunLight;
			else
				shadow = 0;
		}

		//if(category_id == 255)
		//{
		//	// mesh object
		//	color.xyz *= shadow * g_shadowFactor.x + g_shadowFactor.y;
		//}
		//else
		{
			// other blocks
			float3 sun_light = color.xyz * SunColor.rgb * sun_light_strength;
			sun_light *= shadow * g_shadowFactor.x + g_shadowFactor.y;
			float3 torch_light = color.xyz * TorchLightColor.rgb * torch_light_strength;
			// compose and interpolate so that the strength of light is almost linear 
			color.xyz = lerp(torch_light.xyz+sun_light.xyz, sun_light.xyz, sun_light_strength / (torch_light_strength + sun_light_strength+0.001));
		}
		color.a *= clamp(1 - pow(distance(float2(0.5, 0.5), finalSamplePos.xy)*2.0, 2.0), 0.0, 1.0);
	}
    return color;
}

//Calculates direct sunlight without visibility check. mainly depends on surface normal. 
float 	CalculateDirectLighting(float3 normal,int categoryID)
{
	return calculateLightDiffuseFactor(sunDirection,normal);
}

// compute sun shading
// @return shadow: 1 is no shadow, 0 is full shadow(dark)
float ComputeSunShading(float directSunLight, float sun_light_strength, float4 vWorldPosition, float depth)
{
	// 1 is no shadow, 0 is full shadow(dark)
	float shadow = 1;

	// only apply global sun shadows when there is enough sun light on the material
	if(RenderOptions.x > 0 && sun_light_strength > 0 && directSunLight > 0)
	{
    shadow=calculateShadowFactor(ShadowMapSampler,vWorldPosition,depth,mShadowMapTex,ShadowMapSize.x,ShadowMapSize.y,ShadowRadius);
	}
	return shadow;
}

float4 CompositeLitePS(VSOutput input):COLOR
{
	float2 texCoord = input.texCoord;
	float4 color = tex2D(colorSampler, texCoord);

	// r:category id,  g: sun light value, b: torch light value
	float4 block_info = tex2D(matInfoSampler, texCoord);
	int category_id = (int)(block_info.r * 255.0 + 0.4);
  float ao_factor=block_info.a<AOParam.y?pow(block_info.a/AOParam.y,2):1;
	
	float sun_light_strength = block_info.g;
	
	float torch_light_strength = block_info.b;
	// get world space normal
	float4 normal_ = GetNormal(texCoord);
	float3 normal = normal_.xyz;
	// screen space depth value. 
	float depth = tex2D(depthSampler, texCoord).x;

	// Calculates direct sunlight without visibility check
	float directSunLight = CalculateDirectLighting(normal,category_id);
	
	if(depth > 0.01) 
	{
		// reconstruct world space vector from depth
		float3 cameraSpacePosition = input.CameraEye * depth;
		float4 vWorldPosition = float4(cameraSpacePosition, 1);
		vWorldPosition = mul(vWorldPosition, matViewInverse);

		// 1 is no shadow, 0 is full shadow(dark)
		float shadow = ComputeSunShading(directSunLight, sun_light_strength, vWorldPosition, depth);  
		
		// other blocks
		float3 sun_light = sun_light_strength*SunColor*directSunLight*sunIntensity;
      sun_light*=shadow;
      float ambient_factor=0.5+0.5*dot(normalize(normal),float3(0,1,0));
      float3 ambient_upper=sunAmbient;
      float3 ambient_lower=sunAmbient*0.5;
      float3 ambient=lerp(ambient_lower,ambient_upper,ambient_factor)*sun_light_strength;
      sun_light+=ambient;
    {
      if(any(CustomLightColour0)&&any(CustomLightDirection0))
      {
        sun_light+=calculateLightDiffuseFactor(-normalize(CustomLightDirection0),normal)*CustomLightColour0*sun_light_strength;  
      }
      if(any(CustomLightColour1)&&any(CustomLightDirection1))
      {
        sun_light+=calculateLightDiffuseFactor(-normalize(CustomLightDirection1),normal)*CustomLightColour1*sun_light_strength;  
      }
      if(any(CustomLightColour2)&&any(CustomLightDirection2))
      {
        sun_light+=calculateLightDiffuseFactor(-normalize(CustomLightDirection2),normal)*CustomLightColour2*sun_light_strength;  
      }
      if(any(CustomLightColour3)&&any(CustomLightDirection3))
      {
        sun_light+=calculateLightDiffuseFactor(-normalize(CustomLightDirection3),normal)*CustomLightColour3*sun_light_strength;  
      }
    }
    sun_light*=1-AOParam.x*(1-ao_factor);

		// compose and interpolate so that the strength of light is almost linear 
    float3 torch_light = saturate(TorchLightColor.rgb * torch_light_strength);
    color.xyz *= saturate(lerp(torch_light.xyz+sun_light.xyz, sun_light.xyz, sun_light / (torch_light + sun_light+0.001)));
        
		// CalculateSpecularHighlight
		if (category_id == 50)
		{
			float3 cameraSpaceViewDir = normalize(cameraSpacePosition);
			float3 cameraSpaceNormal = mul(normal, (float3x3)matView);
			// For fake specular light, we will assume light and eye are on the same point, so half vector is actually -viewDir.
			float viewVector = dot(-cameraSpaceViewDir, cameraSpaceNormal);
			if (viewVector > 0)
			{
        float specular = 1.0-normal_.w;
				float spec = pow(viewVector, 60.0)*specular;
				color.xyz += spec;
			}
		}
		
		float eyeDist = length(cameraSpacePosition);
		if (FogStart < FogEnd)
			color.xyz = lerp(color.xyz, g_FogColor.xyz, 1.0 - saturate((FogEnd - eyeDist) / (FogEnd - FogStart)));
	}
		
	// Put color into gamma space for correct display
	// color.rgb = pow(color.rgb, (1.0f / 2.2f)); 
	return float4(color.rgb, 1.0);
}

float4 CompositeWaterPS(VSOutput input):COLOR
{
	float2 texCoord = input.texCoord;
	float4 color = tex2D(colorSampler, texCoord);

	// r:category id,  g: sun light value, b: torch light value
	float4 block_info = tex2D(matInfoSampler, texCoord);
	int category_id = (int)(block_info.r * 255.0 + 0.4);
  if (!((category_id == 8 || category_id == 9) && RenderOptions.y > 0))
    discard;
  float ao_factor=block_info.a<AOParam.y?pow(block_info.a/AOParam.y,2):1;
	
	float sun_light_strength = block_info.g;
	
	float torch_light_strength = block_info.b;
	// get world space normal
	float4 normal_ = GetNormal(texCoord);
	float3 normal = normal_.xyz;
	// screen space depth value. 
	float depth = tex2D(depthSampler, texCoord).x;

	// Calculates direct sunlight without visibility check
	float directSunLight = CalculateDirectLighting(normal,category_id);
	
	if(depth > 0.01) 
	{
		// reconstruct world space vector from depth
		float3 cameraSpacePosition = input.CameraEye * depth;
		float4 vWorldPosition = float4(cameraSpacePosition, 1);
		vWorldPosition = mul(vWorldPosition, matViewInverse);

		// 1 is no shadow, 0 is full shadow(dark)
		float shadow = ComputeSunShading(directSunLight, sun_light_strength, vWorldPosition, depth);  
		
		// other blocks
		float3 sun_light = sun_light_strength*SunColor*directSunLight*sunIntensity;
      sun_light*=shadow;
      float ambient_factor=0.5+0.5*dot(normalize(normal),float3(0,1,0));
      float3 ambient_upper=sunAmbient;
      float3 ambient_lower=sunAmbient*0.5;
      float3 ambient=lerp(ambient_lower,ambient_upper,ambient_factor)*sun_light_strength;
      sun_light=saturate(sun_light+ambient);
    sun_light*=1-AOParam.x*(1-ao_factor);
    {
      if(any(CustomLightColour0)&&any(CustomLightDirection0))
      {
        sun_light+=calculateLightDiffuseFactor(-normalize(CustomLightDirection0),normal)*CustomLightColour0*sun_light_strength;  
      }
      if(any(CustomLightColour1)&&any(CustomLightDirection1))
      {
        sun_light+=calculateLightDiffuseFactor(-normalize(CustomLightDirection1),normal)*CustomLightColour1*sun_light_strength;  
      }
      if(any(CustomLightColour2)&&any(CustomLightDirection2))
      {
        sun_light+=calculateLightDiffuseFactor(-normalize(CustomLightDirection2),normal)*CustomLightColour2*sun_light_strength;  
      }
      if(any(CustomLightColour3)&&any(CustomLightDirection3))
      {
        sun_light+=calculateLightDiffuseFactor(-normalize(CustomLightDirection3),normal)*CustomLightColour3*sun_light_strength;  
      }
    }

		// compose and interpolate so that the strength of light is almost linear 
    float3 torch_light = saturate(TorchLightColor.rgb * torch_light_strength);
    color.xyz *= saturate(lerp(torch_light.xyz+sun_light.xyz, sun_light.xyz, sun_light / (torch_light + sun_light+0.001)));
        
		// water blocks
		float3 cameraSpaceNormal = mul(normal, (float3x3)matView);
		float4 reflection = ComputeRayTraceWaterReflection(cameraSpacePosition, cameraSpaceNormal);
		color.xyz = lerp(color.xyz, reflection.rgb, reflection.a);
		
		float eyeDist = length(cameraSpacePosition);
		if (FogStart < FogEnd)
			color.xyz = lerp(color.xyz, g_FogColor.xyz, 1.0 - saturate((FogEnd - eyeDist) / (FogEnd - FogStart)));
	}
		
	// Put color into gamma space for correct display
	// color.rgb = pow(color.rgb, (1.0f / 2.2f)); 
	return float4(color.rgb, 0.8);
}

float4 CompositeGammaCorrect(VSOutput input):COLOR
{
  float4 ret=tex2D(colorSampler,input.texCoord);
  ret.rgb=gammaCorrectWrite(ret.rgb);
  return ret;
}

float4 CompositeBrightPassPS(VSOutput input):COLOR
{
  return brightPassFilter(colorSampler,input.texCoord,HDRParameter.x,HDRParameter.y,HDRParameter.z,HDRParameter.w);
}

float4 CompositeBloomH(VSOutput input):COLOR
{
  return bloorH(colorSampler,input.texCoord,TextureSize0.zw)*BloomScale;
}

float4 CompositeBloomV(VSOutput input):COLOR
{
  return bloorV(colorSampler,input.texCoord,TextureSize0.zw)*BloomScale;
}

float4 CompositeCombine(VSOutput input):COLOR
{
  return tex2D(colorSampler,input.texCoord)+tex2D(matInfoSampler,input.texCoord);
}

float4 CompositeFXAA(VSOutput input):COLOR
{
    return FxaaPixelShader(
        input.texCoord,							// FxaaFloat2 pos,
        FxaaFloat4(0.0f, 0.0f, 0.0f, 0.0f),		// FxaaFloat4 fxaaConsolePosPos,
        colorSampler,							// FxaaTex tex,
        colorSampler,							// FxaaTex fxaaConsole360TexExpBiasNegOne,
        colorSampler,							// FxaaTex fxaaConsole360TexExpBiasNegTwo,
        1.0/screenParam,							// FxaaFloat2 fxaaQualityRcpFrame,
        FxaaFloat4(0.0f, 0.0f, 0.0f, 0.0f),		// FxaaFloat4 fxaaConsoleRcpFrameOpt,
        FxaaFloat4(0.0f, 0.0f, 0.0f, 0.0f),		// FxaaFloat4 fxaaConsoleRcpFrameOpt2,
        FxaaFloat4(0.0f, 0.0f, 0.0f, 0.0f),		// FxaaFloat4 fxaaConsole360RcpFrameOpt2,
        0.75f,									// FxaaFloat fxaaQualitySubpix,
        0.166f,									// FxaaFloat fxaaQualityEdgeThreshold,
        0.0833f,								// FxaaFloat fxaaQualityEdgeThresholdMin,
        0.0f,									// FxaaFloat fxaaConsoleEdgeSharpness,
        0.0f,									// FxaaFloat fxaaConsoleEdgeThreshold,
        0.0f,									// FxaaFloat fxaaConsoleEdgeThresholdMin,
        FxaaFloat4(0.0f, 0.0f, 0.0f, 0.0f)		// FxaaFloat fxaaConsole360ConstDir,
    );
}
