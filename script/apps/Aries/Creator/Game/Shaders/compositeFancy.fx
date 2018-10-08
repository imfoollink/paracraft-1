#include "composite.fx"
technique Default_Normal
{
  pass P0
  {
		cullmode = none;
		ZEnable = false;
		ZWriteEnable = false;
		FogEnable = False;
    AlphaBlendEnable = false;
		VertexShader = compile vs_3_0 CompositeQuadVS();
    PixelShader = compile ps_3_0 CompositeLitePS();
  }
  pass P1
  {
		cullmode = none;
		ZEnable = false;
		ZWriteEnable = false;
		FogEnable = False;
    AlphaBlendEnable = true;
    SrcBlend = srcalpha;
    DestBlend = invsrcalpha;
		VertexShader = compile vs_3_0 CompositeQuadVS();
    PixelShader = compile ps_3_0 CompositeWaterPS();
  }
  pass P2
  {
		cullmode = none;
		ZEnable = false;
		ZWriteEnable = false;
    ZFunc = always;
		FogEnable = False;
    AlphaBlendEnable = false;
		VertexShader = compile vs_3_0 CompositeQuadVS();
    PixelShader = compile ps_3_0 CompositeGammaCorrect();
  }
pass P3
  {
		cullmode = none;
		ZEnable = false;
		ZWriteEnable = false;
    ZFunc = always;
		FogEnable = False;
    AlphaBlendEnable = false;
		VertexShader = compile vs_3_0 CompositeQuadVS();
    PixelShader = compile ps_3_0 CompositeBrightPassPS();
  }
  pass P4
  {
		cullmode = none;
		ZEnable = false;
		ZWriteEnable = false;
    ZFunc = always;
		FogEnable = False;
    AlphaBlendEnable = false;
		VertexShader = compile vs_3_0 CompositeQuadVS();
    PixelShader = compile ps_3_0 CompositeBloomH();
  }
  pass P5
  {
		cullmode = none;
		ZEnable = false;
		ZWriteEnable = false;
    ZFunc = always;
		FogEnable = False;
    AlphaBlendEnable = false;
		VertexShader = compile vs_3_0 CompositeQuadVS();
    PixelShader = compile ps_3_0 CompositeBloomV();
  }
  pass P6
  {
		cullmode = none;
		ZEnable = false;
		ZWriteEnable = false;
    ZFunc = always;
		FogEnable = False;
    AlphaBlendEnable = false;
		VertexShader = compile vs_3_0 CompositeQuadVS();
    PixelShader = compile ps_3_0 CompositeCombine();
  }
  pass P7
  {
		cullmode = none;
		ZEnable = false;
		ZWriteEnable = false;
		FogEnable = False;
    AlphaBlendEnable = false;
		VertexShader = compile vs_3_0 CompositeQuadVS();
    PixelShader = compile ps_3_0 CompositeFXAA();
  }
}