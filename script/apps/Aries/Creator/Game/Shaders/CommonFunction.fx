#include "CommonDefine.fx"
#include "FXAA.hlsl"
float3 decodeNormal(float3 normal)
{
	return normal*2.0-1.0;
}
float calculateLightDiffuseFactor(float3 lightDirection,float3 normal)
{
	return saturate(dot(lightDirection,normal));
}
//1:no shadow
//0£ºfull shadow
float getShadowFactor(sampler2D s,float2 uv,float testDepth,float shadowMapSize,float invShadowMapSize)
{
#ifdef HARDWARE_SHADOW_ENABLE
	return tex2D(s,float3(uv,testDepth));
#else
#ifdef PCF_SHADOW_ENABLE
	const float2 uv_in_texel_f=uv*shadowMapSize;
	const float2 uv_in_texel_i=floor(uv_in_texel_f);
	const float2 scalar=frac(uv_in_texel_f);
	float2 uv0=uv_in_texel_i*invShadowMapSize;
	float2 uv1=(uv_in_texel_i+float2(1,0))*invShadowMapSize;
	float shadow0=tex2D(s,uv0).r>=testDepth?1:0;
	float shadow1=tex2D(s,uv1).r>=testDepth?1:0;
	float shadow_up=lerp(shadow0,shadow1,scalar.x);
	uv0=(uv_in_texel_i+float2(0,1))*invShadowMapSize;
	uv1=(uv_in_texel_i+1)*invShadowMapSize;
	shadow0=tex2D(s,uv0).r>=testDepth?1:0;
	shadow1=tex2D(s,uv1).r>=testDepth?1:0;
	float shadow_down=lerp(shadow0,shadow1,scalar.x);
	return lerp(shadow_up,shadow_down,scalar.y);
#else
	float shadow_depth=tex2D(s,uv).r;
	float shadow=shadow_depth>=testDepth?1:0;;
	return shadow;
#endif
#endif
}
float calculatefadeShadowFactor(float viewDepth,float shadowRadius)
{
	return saturate((viewDepth-shadowRadius)/(shadowRadius*0.1));
}
float calculateShadowFactor(sampler2D s,float3 worldPosition,float viewDepth,float4x4 shadowMatrix,float shadowMapSize,float invShadowMapSize,float shadowRadius)
{
	const float4 shadow_map_coord=mul(float4(worldPosition,1.0),shadowMatrix);
	const float shadow_test_depth=shadow_map_coord.z-0.0025;
	const float2 uv=shadow_map_coord.xy/shadow_map_coord.w;
#ifdef SOFT_SHADOW_ENABLE
	float ret=0;
	for(float i=-1; i<=1; i+=1)
	{
		for(float j=-1; j<=1; j+=1)
		{
			const float2 texelpos=uv+float2(i*invShadowMapSize,j*invShadowMapSize);
			ret+=getShadowFactor(s,texelpos,shadow_test_depth,shadowMapSize,invShadowMapSize);
		}
	}
	ret/=9;
#else
	float ret=getShadowFactor(s,uv,shadow_test_depth,shadowMapSize,invShadowMapSize);
#endif
	ret=lerp(ret,1.0,calculatefadeShadowFactor(viewDepth,shadowRadius));
	return ret;
}
float4 brightPassFilter(sampler2D s,float2 uv,float luminance,float middleGray,float brightThreshold,float brightOffset)
{
	float3 ColorOut=tex2D(s,uv);

	ColorOut*=middleGray/(luminance+0.001f);
	ColorOut-=brightThreshold;

	ColorOut=max(ColorOut, 0.0f);

	ColorOut/=(brightOffset+ColorOut);
  ColorOut*=8;

	return float4(ColorOut, 1.0f);
}

float4 bloorH(sampler2D s,float2 uv,float2 invTexSize)
{
	const int g_cKernelSize=13;

	float2 PixelKernel[g_cKernelSize]=
	{
		{-6, 0},
		{-5, 0},
		{-4, 0},
		{-3, 0},
		{-2, 0},
		{-1, 0},
		{0, 0},
		{1, 0},
		{2, 0},
		{3, 0},
		{4, 0},
		{5, 0},
		{6, 0},
	};
	const float BlurWeights[g_cKernelSize]=
	{
		0.002216,
		0.008764,
		0.026995,
		0.064759,
		0.120985,
		0.176033,
		0.199471,
		0.176033,
		0.120985,
		0.064759,
		0.026995,
		0.008764,
		0.002216,
	};

	float4 Color=0;

	for(int i=0; i < g_cKernelSize; i++)
	{
		Color+=tex2D(s,uv+PixelKernel[i].xy*invTexSize) * BlurWeights[i];
	}

	return Color;
}

float4 bloorV(sampler2D s,float2 uv,float2 invTexSize)
{
	const int g_cKernelSize=13;

	float2 PixelKernel[g_cKernelSize]=
	{
		{0, -6},
		{0, -5},
		{0, -4},
		{0, -3},
		{0, -2},
		{0, -1},
		{0,  0},
		{0,  1},
		{0,  2},
		{0,  3},
		{0,  4},
		{0,  5},
		{0,  6},
	};
	const float BlurWeights[g_cKernelSize]=
	{
		0.002216,
		0.008764,
		0.026995,
		0.064759,
		0.120985,
		0.176033,
		0.199471,
		0.176033,
		0.120985,
		0.064759,
		0.026995,
		0.008764,
		0.002216,
	};

	float4 Color=0;

	for(int i=0; i < g_cKernelSize; i++)
	{
		Color+=tex2D(s,uv+PixelKernel[i].xy*invTexSize) * BlurWeights[i];
	}

	return Color;
}

float3 gammaCorrectRead(float3 rgb)
{
	return pow(rgb,2.2);
}

float3 gammaCorrectWrite(float3 rgb)
{
	return pow(rgb,1.0/2.2);
}