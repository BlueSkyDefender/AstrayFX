////---------------//
///**Depth Cues**///
//---------------////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Depth Based Unsharp Mask haloing
// For Reshade 3.0+
//  ---------------------------------
//                                                       Depth Cues
//                                Extra Information for where I got the Idea for Depth Cues.
//                             https://www.uni-konstanz.de/mmsp/pubsys/publishedFiles/LuCoDe06.pdf
//
// COPYRIGHT
// ============
// Copyright (c) 2026 Jose Negrete / BlueSkyDefender.
// All rights reserved.
//
// PERMISSION
// ============
// Permission is granted to use and share unmodified copies of this shader
// with proper credit to Jose Negrete / BlueSkyDefender.
//
// Modified versions, derivatives, ports, or redistributed modified copies
// are not permitted without separate written permission from
// Jose Negrete / BlueSkyDefender.
//
// Separate written permission may be granted for specific people, projects,
// versions, or use cases. Any such permission applies only to the terms
// stated in that written permission.
//
// This version is no longer distributed under
// Creative Commons Attribution-NoDerivatives 4.0 International.
//
// Older copies released before May 26, 2026 may have been distributed
// under Creative Commons Attribution-NoDerivatives 4.0 International.
// That older license remains valid for those older copies.
//
// Historical versions may be visible in the GitHub commit history,
// forks, archives, or previous releases, but the current version is
// covered by this notice.
//
// Have fun,
// Jose Negrete AKA BlueSkyDefender
//
// https://github.com/BlueSkyDefender/Depth3D
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//DA_W Depth_Linearization | DB_X Depth_Flip
static const float DA_W = 0.0, DB_X = 0;
#define NC 0
#define NP 0

//Automatic Blur Adjustment based on Resolutionsup to 8k considered.
#if (BUFFER_HEIGHT <= 720)
	#define Multi 0.5
#elif (BUFFER_HEIGHT <= 1080)
	#define Multi 1.0
#elif (BUFFER_HEIGHT <= 1440)
	#define Multi 1.5
#elif (BUFFER_HEIGHT <= 2160)
	#define Multi 2
#else
	#define Multi 2.5
#endif

// It is best to run Smart Sharp after tonemapping.

#if !defined(__RESHADE__) || __RESHADE__ < 40000
	#define Compatibility 1
#else
	#define Compatibility 0
#endif

uniform int Depth_Map <
	ui_type = "combo";
	ui_items = "Normal\0Reverse\0";
	ui_label = "Custom Depth Map";
	ui_tooltip = "Pick your Depth Map.";
	ui_category = "Depth Buffer";
> = DA_W;

uniform float Depth_Map_Adjust <
	#if Compatibility
	ui_type = "drag";
	#else
	ui_type = "slider";
	#endif
	ui_min = 1.0; ui_max = 1000.0; ui_step = 0.125;
	ui_label = "Depth Map Adjustment";
	ui_tooltip = "Adjust the depth map and sharpness distance.";
	ui_category = "Depth Buffer";
> = 250.0;

uniform bool Depth_Map_Flip <
	ui_label = "Depth Map Flip";
	ui_tooltip = "Flip the depth map if it is upside down.";
	ui_category = "Depth Buffer";
> = DB_X;

uniform bool DEPTH_DEBUG <
	ui_label = "View Depth";
	ui_tooltip = "Shows depth, you want close objects to be black and far objects to be white for things to work properly.";
	ui_category = "Depth Buffer";
> = false;

uniform bool No_Depth_Map <
	ui_label = "No Depth Map";
	ui_tooltip = "If you have No Depth Buffer turn this On.";
	ui_category = "Depth Buffer";
> = true;

uniform float Shade_Power <
	#if Compatibility
	ui_type = "drag";
	#else
	ui_type = "slider";
	#endif
	ui_min = 0.25; ui_max = 1.0;
	ui_label = "Shade Power";
	ui_tooltip = "Adjust the Shade Power This improves AO, Shadows, & Darker Areas in game.\n"
				 "Number 0.5 is default.";
	ui_category = "Depth Cues";
> = 0.5;

uniform float Blur_Cues <
	#if Compatibility
	ui_type = "drag";
	#else
	ui_type = "slider";
	#endif
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Blur Shade";
	ui_tooltip = "Adjust the to make Shade Softer in the Image.\n"
				 "Number 0.5 is default.";
	ui_category = "Depth Cues";
> = 0.5;

uniform float Spread <
	#if Compatibility
	ui_type = "drag";
	#else
	ui_type = "slider";
	#endif
	ui_min = 1.0; ui_max = 25.0; ui_step = 0.25;
	ui_label = "Shade Fill";
	ui_tooltip = "Adjust This to have the shade effect to fill in areas gives fakeAO effect.\n"
				 "This is used for gap filling.\n"
				 "Number 10.0 is default.";
	ui_category = "Depth Cues";
> = 10.0;

uniform bool Debug_View <
	ui_label = "Depth Cues Debug";
	ui_tooltip = "Depth Cues Debug output the shadeded output.";
	ui_category = "Depth Cues";
> = false;

//uniform bool Fake_AO <
//	ui_label = "Fake AO";
//	ui_tooltip = "Fake AO only works when you Have Depth Buffer Access.";
//	ui_category = "Fake AO";
//> = false;

/////////////////////////////////////////////////////D3D Starts Here/////////////////////////////////////////////////////////////////
#define pix float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT)
#define BlurSamples 10 //BlurSamples = # * 2
//#define Fake_AO_Adjust 0.001
#define S_Power Spread * Multi
#define M_Power Blur_Cues * Multi
uniform float timer < source = "timer"; >;

texture DepthBufferTex : DEPTH;

sampler DepthBuffer_DC
	{
		Texture = DepthBufferTex;
	};

texture BackBufferTex : COLOR;

sampler BackBuffer_DC
	{
		Texture = BackBufferTex;
	};

texture texHB_DC { Width = BUFFER_WIDTH  * 0.5 ; Height = BUFFER_HEIGHT * 0.5 ; Format = R8; MipLevels = 1;};

sampler SamplerHB_DC
	{
			Texture = texHB_DC;
	};

texture texDC { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = R8; MipLevels = 3;};

sampler SamplerDC
	{
			Texture = texDC;
	};

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
float Depth_DC(in float2 texcoord : TEXCOORD0)
{
	if (Depth_Map_Flip)
		texcoord.y =  1 - texcoord.y;

	float zBuffer = tex2D(DepthBuffer_DC, texcoord).x; //Depth Buffer

	//Conversions to linear space.....
	//Near & Far Adjustment
	float Far = 1.0, Near = 0.125/Depth_Map_Adjust; //Division Depth Map Adjust - Near

	float2 Z = float2( zBuffer, 1-zBuffer );

	if (Depth_Map == 0)//DM0. Normal
		zBuffer = Far * Near / (Far + Z.x * (Near - Far));
	else if (Depth_Map == 1)//DM1. Reverse
		zBuffer = Far * Near / (Far + Z.y * (Near - Far));

	return saturate(zBuffer);
}

float lum(float3 RGB)
{
	return dot(RGB, float3(0.2126, 0.7152, 0.0722) );
}

float BB(in float2 texcoord, float2 AD)
{
	
	//if(Fake_AO)
	//	return lerp(1-(1 - Fake_AO_Adjust/Depth_DC(texcoord + AD).x) , lum(tex2Dlod(BackBuffer_DC, float4(texcoord + AD,0,0)).rgb) , 0.125);
	//else
		return lum(tex2Dlod(BackBuffer_DC, float4(texcoord + AD,0,0)).rgb);
		
}

float H_Blur_DC(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float S = S_Power * 0.125;

	float sum = BB(texcoord,0) * BlurSamples;

    float total = BlurSamples;

    for ( int j = -BlurSamples; j <= BlurSamples; ++j)
    {
        float W = BlurSamples;

		sum += BB(texcoord , + float2(pix.x * S,0) * j ) * W;

        total += W;
    }
	return saturate(sum / total); // Get it  Total sum..... :D
}

// Spread the blur a bit more.
float DepthCues(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
		float2 S = S_Power * 0.75f * pix;

		float M_Cues = 1, result = tex2Dlod(SamplerHB_DC,float4(texcoord,0,M_Cues)).x;
		result += tex2Dlod(SamplerHB_DC,float4(texcoord + float2( 1, 0) * S ,0,M_Cues)).x;
		result += tex2Dlod(SamplerHB_DC,float4(texcoord + float2( 0, 1) * S ,0,M_Cues)).x;
		result += tex2Dlod(SamplerHB_DC,float4(texcoord + float2(-1, 0) * S ,0,M_Cues)).x;
		result += tex2Dlod(SamplerHB_DC,float4(texcoord + float2( 0,-1) * S ,0,M_Cues)).x;
		S *= 0.5;
		result += tex2Dlod(SamplerHB_DC,float4(texcoord + float2( 1, 0) * S ,0,M_Cues)).x;
		result += tex2Dlod(SamplerHB_DC,float4(texcoord + float2( 0, 1) * S ,0,M_Cues)).x;
		result += tex2Dlod(SamplerHB_DC,float4(texcoord + float2(-1, 0) * S ,0,M_Cues)).x;
		result += tex2Dlod(SamplerHB_DC,float4(texcoord + float2( 0,-1) * S ,0,M_Cues)).x;
		result *= rcp(9);

	// Formula for Image Pop = Original + (Original / Blurred).
	//float DC = BB(texcoord,0) / result;
return saturate(lerp(1.0f,BB(texcoord,0) / result,Shade_Power));
}

float3 ShaderOut_DC(float2 texcoord : TEXCOORD0)
{
	float DCB = tex2Dlod(SamplerDC,float4(texcoord,0,M_Power)).x,DB = Depth_DC(texcoord).x;
	float3 Out, BBN = tex2D(BackBuffer_DC,texcoord).rgb;

	if(No_Depth_Map)
		DB = 0.0;
		
	Out.rgb = BBN * lerp(DCB,1., DB);

	if (Debug_View)
		Out = lerp(DCB,1., DB);

	if (DEPTH_DEBUG)
		Out = DB;

	return Out;
}
////////////////////////////////////////////////////////Logo/////////////////////////////////////////////////////////////////////////
float3 Out_DC(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{ 
	float3 Color = ShaderOut_DC(texcoord).rgb;
	return Color;
}
///////////////////////////////////////////////////////////ReShade.fxh/////////////////////////////////////////////////////////////

// Vertex shader generating a triangle covering the entire screen
void PostProcessVS(in uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD)
{
	texcoord.x = (id == 2) ? 2.0 : 0.0;
	texcoord.y = (id == 1) ? 2.0 : 0.0;
	position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

//*Rendering passes*//
technique Monocular_Cues
{

			pass Blur
		{
			VertexShader = PostProcessVS;
			PixelShader = H_Blur_DC;
			RenderTarget = texHB_DC;
		}
			pass BlurDC
		{
			VertexShader = PostProcessVS;
			PixelShader = DepthCues;
			RenderTarget = texDC;
		}
			pass UnsharpMask
		{
			VertexShader = PostProcessVS;
			PixelShader = Out_DC;
		}
}
