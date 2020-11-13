////-------------//
///**RadiantGI**///
//-------------////

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////                                               																									*//
//For Reshade 3.0+ Global Illumination Ver 1.2
//--------------------------------------------
//                                                                Radiant Global Illumination
//
// Due Diligence
// Michael Bunnell Disk Screen Space Ambient Occlusion or Disk to Disk SSAO 14.3
// https://developer.nvidia.com/gpugems/gpugems2/part-ii-shading-lighting-and-shadows/chapter-14-dynamic-ambient-occlusion-and
// - Arkano22
//   https://www.gamedev.net/topic/550699-ssao-no-halo-artifacts/
// - Martinsh
//   http://devlog-martinsh.blogspot.com/2011/10/nicer-ssao.html
// - Boulotaur2024
//   https://github.com/PeterTh/gedosato/blob/master/pack/assets/dx9/martinsh_ssao.fx
// Computer graphics & visualization Global Illumination Effects.
// - Christian A. Wiesner
//   https://slideplayer.com/slide/3533454/
//Improved Normal Reconstruction From Depth
// - Turanszkij
//   https://wickedengine.net/2019/09/22/improved-normal-reconstruction-from-depth/
// Upsample Code
// - PETER KL "I think"
//   https://frictionalgames.blogspot.com/2014/01/tech-feature-ssao-and-temporal-blur.html#Code
// TAA Based on my own port of Epics Temporal AA
//   https://de45xmedrsdbp.cloudfront.net/Resources/files/TemporalAA_small-59732822.pdf
// Joined Bilateral Upsampling Filtering
// - Bart Wronski
//   https://bartwronski.com/2019/09/22/local-linear-models-guided-filter/
// - Johannes Kopf | Michael F. Cohen | Dani Lischinski | Matt Uyttendaele
//   https://johanneskopf.de/publications/jbu/paper/FinalPaper_0185.pdf
// Reinhard by Tom Madams
//   http://imdoingitwrong.wordpress.com/2010/08/19/why-reinhard-desaturates-my-blacks-3/
// Generate Noise is Based on this implamentation
//   https://www.shadertoy.com/view/wtsSW4
// Text rendering code by Hamneggs
//   https://www.shadertoy.com/view/4dtGD2
// A slightly faster buffer-less vertex shader trick by CeeJay.dk
//   https://www.reddit.com/r/gamedev/comments/2j17wk/a_slightly_faster_bufferless_vertex_shader_trick/
//
// If I missed any please tell me.
//
// Special Thank You to CeeJay.dk & Dorinte. May the Pineapple Kringle lead you too happiness.
//
// LICENSE
// ============
// Overwatch & Code out side the work of people mention above is licenses under: Attribution-NoDerivatives 4.0 International
//
// You are free to:
// Share - copy and redistribute the material in any medium or format
// for any purpose, even commercially.
//
// The licensor cannot revoke these freedoms as long as you follow the license terms.
//
// Under the following terms:
// Attribution - You must give appropriate credit, provide a link to the license, and indicate if changes were made.
// You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.
//
// NoDerivatives - If you remix, transform, or build upon the material, you may not distribute the modified material.
//
// No additional restrictions - You may not apply legal terms or technological measures that legally restrict others from doing anything the license permits.
//
// https://creativecommons.org/licenses/by-nd/4.0
//
// Have fun,
// Written by Jose Negrete AKA BlueSkyDefender <UntouchableBlueSky@gmail.com>, October 2020
// https://github.com/BlueSkyDefender/Depth3D
//
// Notes to the other developers: https://github.com/BlueSkyDefender/AstrayFX
//
// I welcome almost any help that seems to improve the code. But, The changes need to be approved by myself. So feel free to submit changes here on github.
// Things to work on are listed here. Oh if you feel your code changes too much. Just add a preprocessor to section off your code. Thank you.
//
// Better TAA if you know how to do this better change it.Frame-to-frame coherence Is fast enough in my eyes now. but, I know other devs can do better.
// Much sparser sampling is need to hide low poly issues so we need better Smooth Normals code, Bent Normal maps ect.
// Better specular reflections.......... ect.
//
// Oh if you can make a 2nd Bounce almost as fast as One Bounce....... Do it with your magic you wizard.
//
// Write your name and changes/notes below.
// __________________________________________________________________________________________________________________________________________________________________________________
// -------------------------------------------------------------------Around Line 794----------------------------------------------------------------------------------------
// Lord of Lunacy - https://github.com/LordOfLunacy
// Reveil DeHaze Masking was inserted around GI Creation.
// __________________________________________________________________________________________________________________________________________________________________________________
// -------------------------------------------------------------------Around Line 0000---------------------------------------------------------------------------------------
// Dev Name - Repo
// Notes from Dev. 
// 
//                                                                    Radiant GI Notes
// Upcoming Updates.............................................no guarantee
// Need to add indirect color from the sky.
// Need Past Edge Brightness storage.
// Need to rework the Joint Bilateral Gaussian Upscaling for sharper Debug and less artifacts in motion.
//
// Update 1.2
// This update did change a few things here and there like PBGI_Alpha and PBGI_Beta are now PBGI_One and PBGI_Two. 
// Error Code edited so it does not show the warning anymore. But, it's still shows the shader name as yellow.¯\_('_')_/¯ 
// This version has a small perf loss. Also removed some extra code that was not mine. Forgot to replace it my bad.....
// TAA now gives The JBGU shader motion information to blur in motion so there is less noise in motion. :)
// 
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#if exists "Overwatch.fxh"                                           //Overwatch Intercepter//
	#include "Overwatch.fxh"
	#define OS 0
#else// DA_Y = [Depth Adjust] DA_Z = [Offset] DA_W = [Depth Linearization] DB_X = [Depth Flip]
	static const float DA_Y = 7.5, DA_Z = 0.0, DA_W = 0.0, DB_X = 0;
	// DC_X = [Barrel Distortion K1] DC_Y = [Barrel Distortion K2] DC_Z = [Barrel Distortion K3] DC_W = [Barrel Distortion Zoom]
	static const float DC_X = 0, DC_Y = 0, DC_Z = 0, DC_W = 0;
	// DD_X = [Horizontal Size] DD_Y = [Vertical Size] DD_Z = [Horizontal Position] DD_W = [Vertical Position]
	static const float DD_X = 1, DD_Y = 1, DD_Z = 0.0, DD_W = 0.0;
	//Triggers
	static const int RE = 0, NC = 0, RH = 0, NP = 0, ID = 0, SP = 0, DC = 0, HM = 0, DF = 0, NF = 0, DS = 0, LBC = 0, LBM = 0, DA = 0, NW = 0, PE = 0, FV = 0, ED = 0;
	//Overwatch.fxh State
	#define OS 1
#endif

//Keep in mind you are not licenced to redistribute this shader with setting modified below. Please Read the Licence.
//This GI shader is free and shouldn't sit behind a paywall. If you paid for this shader ask for a refund right away.

//Generated Ray Resolution
#define Automatic_Resolution_Scaling 1 //[Off | On] This is used to enable or disable Automatic Resolution Scaling. Default is On.
#define RSRes 1.0              //[0.5 - 1.0]        Noise start too takes over around 0.666 at 1080p..... Higher the res lower the noise.

//Depth Buffer Adjustments
#define DB_Size_Position 0     //[Off | On]         This is used to reposition and the size of the depth buffer.
#define BD_Correction 0        //[Off | On]         Barrel Distortion Correction for non conforming BackBuffer.

//TAA Quality Level
#define Denoiser_Power 1      //[0 Low |1 Normal]   Use this if the Noise that is generated on Foliage/Edges is too much for you. A pineapple said. It can affect performance.
#define RL_Alternation 0      //[Off | On]          Used for enabling Ray Length Alternation Mode. This lets the ray size alternate every frame at 75% of current length.
#define TAA_Clamping 0.2      //[0.0 - 1.0]         Use this to adjust TAA clamping.

//Performance Settings
#define Foced_SNM 0           //[Off | On]          Use force smooth normals in a non-proper way with a box blur. High performance cost. If you want to make this better please dooooooooo
#define Sparse_Grid 1         //[Off | On]          A Sparse Grid is used to improve performance for GI since this information is reconstructed later. You Gain perf turning this on.

//Other Settings
#define MaxDepth_Cutoff 0.999 //[0.1 - 1.0]         Used to cutout the sky with depth buffer masking. This lets the shader save on performance by limiting what is used in GI.
#define Controlled_Blend 0    //[Off | On]          Use this if you want control over blending GI in to the final
#define Dark_Mode 0           //[Off | On]          Instead of using a 50% gray it displays Black for the absence of information.
#define Text_Info_Key 122     //F11 Key             Text Information Key Default 122 is the F11 Key. You can use this site https://keycode.info to pick your own.
#define Disable_Debug_Info 0  //[Off | On]          Use this to disable help information that gives you hints for fixing many games with Overwatch.fxh.
#define Minimize_Web_Info 0   //[Off | On]          Use this to minimize the website logo on startup.

//Keep in mind you are not licenced to redistribute this shader with setting modified above. Please Read the Licence.
//This GI shader is free and shouldn't sit behind a paywall. If you paid for this shader ask for a refund right away.

//Non User settings.
#define Max_Ray_Length 250 //Don't change this it will break small details.
#if __RESHADE__ >= 40500
	#define RGBA RGB10A2
#else
	#define RGBA RGBA8
#endif
#if exists "ReVeil.fx"
	#define Look_For_Buffers_ReVeil 1
#if __RESHADE__ <= 40700 //Needed to do this Because how the warning system in reshade changed from under me. :( Wish the Shader name didn't change to yellow.:(
	#warning "ReVeil.fx Detected! Yoink! Took your Transmission Buffer"
#endif
#else
	#define Look_For_Buffers_ReVeil 0
#endif
//Help / Guide Information stub uniform a idea from LucasM
uniform int RadiantGI <
	ui_text = "RadiantGI is an indirect lighting algorithm based on the disk-to-disk radiance transfer by Michael Bunnell.\n"
			  		"As you can tell its name is a play on words and it radiates the kind of feeling I want from it one Ray Bounce at a time.\n"
			  			  "This GI shader is free and shouldn't sit behind a paywall. If you paid for this shader ask for a refund right away.\n"
			  			  		"As for my self I do want to provide the community with free shaders and any donations will help keep that motivation alive.\n"
			  			  			  "For more information and please feel free to visit http://www.Depth3D.info or https://blueskydefender.github.io/AstrayFX.\n "
			  "Please enjoy this shader and Thank You for using RadiantGI.";
	ui_category = "RadiantGI";
	ui_category_closed = true;
	ui_label = " ";
	ui_type = "radio";
>;
uniform int samples <
	ui_type = "slider";
	ui_min = 1; ui_max = 64; ui_step = 1;
	ui_label = "Samples";
	ui_tooltip = "GI Sample Quantity is used increase samples amount as a side effect this reduce noise.";
	ui_category = "PBGI";
> = 6;

uniform float GI_Ray_Length <
	ui_type = "drag";
	ui_min = 1.0; ui_max = Max_Ray_Length; ui_step = 1;
	ui_label = "GI Ray Length";
	ui_tooltip = "GI Ray Length adjustment is used to increase the Ray Cast Dististance.\n"
			     "This scales automatically with multi level detail.";
	ui_category = "PBGI";
> = 125;
uniform int GI_AT <
	ui_type = "slider";
	ui_min = 0; ui_max = 4; ui_step = 1;
	ui_label = "Bleed Through";
	ui_tooltip = "Decrease or Increase The Accuracy of GI by lowering or raising it's edge tolerance.";
	ui_category = "PBGI";
> = 0;
uniform float2 NCD <
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Near Details";
	ui_tooltip = "Lets you adjust detail of objects near the cam and or like weapon hand GI.\n"
			     "The 2nd Option is for Weapon Hands in game that fall out of range.\n"
			     "Defaults are [Near Details X 0.125] [Weapon Hand Y 0.0]";
	ui_category = "PBGI";
> = float2(0.125,0.0);
uniform float Trim <
	ui_type = "slider";
	ui_min = 0.0; ui_max = 2.5;
	ui_label = "Trimming";
	ui_tooltip = "Trim GI by limiting how far the GI is able to effect the objects around them..\n"
			     "Default is [0.250] and Zero is Off.";
	ui_category = "PBGI";
> = 0.25;
/*
uniform float AO_Ray_Length <
	ui_type = "drag";
	ui_min = 1.0; ui_max = Max_Ray_Length; ui_step = 1;
	ui_label = "AO Ray Length";
	ui_tooltip = "AO Ray Length adjustment is used to increase the Ray Cast Dististance.\n"
			     "This scales automatically with multi level detail.";
	ui_category = "PBAO";
> = 125;
uniform float AO_Trim <
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "AO Trimming";
	ui_tooltip = "Trim AO by limiting how far the AO is able to effect the objects around them..\n"
			     "Default is [0.250] and Zero is Off.";
	ui_category = "PBAO";
> = 0.25;
*/
#if Controlled_Blend
uniform float Blend <
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Blend";
    ui_tooltip = "Use this to change the look of GI when applyed to the final image.";
    ui_category = "Image";
> = 0.5;
#else
uniform int BM <
	ui_type = "combo";
    ui_label = "Blendmode";
    ui_tooltip = "Use this to change the look of GI when applyed to the final image.";
    ui_items = "Mix\0Overlay\0Softlight\0";
    ui_category = "Image";
    > = 0;
#endif
uniform float GI_Power <
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Power";
	ui_tooltip = "Main overall GI application power control.\n"
			     "Default is [Power 0.5].";
	ui_category = "Image";
> = 0.5;
uniform float2 GI_NearFar < //Blame the pineapple for this option.
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Depth Scaling";
	ui_tooltip = "GI Application Power that is based on Depth scaling for controlled fade In-N-Out.\n" //That's What A Hamburger's All About
			     "Can be set from 0 to 1 and is in the order of Near Depth and Far Depth.\n"
			     "Defaults are [Near X 1.0] [Far Y 0.125].";
	ui_category = "Image";
> = float2(1.0,0.125);
uniform float Saturation <
	ui_type = "slider";
	ui_min = 0.0; ui_max = 2.0;
	ui_label = "Saturation";
	ui_tooltip = "Irradiance Map Saturation";
	ui_category = "Image";
> = 1.0;
uniform float HDR_BP <
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "HDR Extraction Power";
	ui_tooltip = "Use This to adjust the HDR Power, You can override this value and set it to like 1.5 or something.\n"
				 "Number 0.0 is Off.";
	ui_category = "Image";
> = 0.5;
uniform int Depth_Map <
	ui_type = "combo";
	ui_items = "DM0 Normal\0DM1 Reversed\0";
	ui_label = "Depth Map Selection";
	ui_tooltip = "Linearization for the zBuffer also known as Depth Map.\n"
			     "DM0 is Z-Normal and DM1 is Z-Reversed.\n";
	ui_category = "Depth Map";
> = DA_W;
uniform float Depth_Map_Adjust <
	ui_type = "drag";
	ui_min = 1.0; ui_max = 250.0;
	ui_label = "Depth Map Adjustment";
	ui_tooltip = "This allows for you to adjust the DM precision.\n"
				 "Adjust this to keep it as low as possible.\n"
				 "Default is 7.5";
	ui_category = "Depth Map";
> = DA_Y;
uniform float Offset <
	ui_type = "drag";
	ui_min = -1.0; ui_max = 1.0;
	ui_label = "Depth Map Offset";
	ui_tooltip = "Depth Map Offset is for non conforming ZBuffer.\n"
				 "It is rare that you would need to use this option.\n"
				 "Use this to make adjustments to DM 0 or DM 1.\n"
				 "Default and starts at Zero and it is Off.";
	ui_category = "Depth Map";
> = DA_Z;
uniform bool Depth_Map_Flip <
	ui_label = "Depth Map Flip";
	ui_tooltip = "Flip the depth map if it is upside down.";
	ui_category = "Depth Map";
> = DB_X;
uniform int Debug <
	ui_type = "combo";
	ui_items = "RadiantGI\0Irradiance Map\0Depth & Normals\0";
	ui_label = "Debug View";
	ui_tooltip = "View Debug Buffers.";
	ui_category = "Extra Options";
> = 0;
#if !Disable_TAA
uniform int Performance_Level <
	ui_type = "combo";
	ui_items = "Low\0Medium\0High\0Ultra\0";
	ui_label = "Quality Level";//Ya CeeJay.dk you got your way..
	ui_tooltip = "This raises or lowers Quality of the Final Denoiser which in turn affects Performance.\n"
				 "Default is Medium.";
	ui_category = "Extra Options";
> = 1;
#else
static const int Performance_Level = 3;
#endif
#if Look_For_Buffers_ReVeil
	uniform bool UseReVeil<
		ui_label = "Use Transmission from ReVeil";
		ui_tooltip = "Requires ReVeil to be enabled (Lord of Lunacy waz here)";
		ui_category = "Extra Options";
	> = true;
#endif
#if DB_Size_Position || SP == 2
uniform float2 Horizontal_and_Vertical <
	ui_type = "drag";
	ui_min = 0.0; ui_max = 2;
	ui_label = "Horizontal & Vertical Size";
	ui_tooltip = "Adjust Horizontal and Vertical Resize. Default is 1.0.";
	ui_category = "Depth Corrections";
> = float2(DD_X,DD_Y);
uniform float2 Image_Position_Adjust<
	ui_type = "drag";
	ui_min = -1.0; ui_max = 1.0;
	ui_label = "Horizontal & Vertical Position";
	ui_tooltip = "Adjust the Image Position if it's off by a bit. Default is Zero.";
	ui_category = "Depth Corrections";
> = float2(DD_Z,DD_W);
#else
static const float2 Horizontal_and_Vertical = float2(DD_X,DD_Y);
static const float2 Image_Position_Adjust = float2(DD_Z,DD_W);
#endif
#if BD_Correction
uniform int BD_Options <
	ui_type = "combo";
	ui_items = "On\0Off\0";
	ui_label = "Distortion Options";
	ui_tooltip = "Use this to Turn BD Off or On.\n"
				 "Default is ON.";
	ui_category = "Depth Corrections";
> = 0;

uniform float3 Colors_K1_K2_K3 <
	#if Compatibility
	ui_type = "drag";
	#else
	ui_type = "slider";
	#endif
	ui_min = -2.0; ui_max = 2.0;
	ui_tooltip = "Adjust the Distortion K1, K2, & K3.\n"
				 "Default is 0.0";
	ui_label = "BD K1 K2 K3";
	ui_category = "Depth Corrections";
> = float3(DC_X,DC_Y,DC_Z);
uniform float Zoom <
	ui_type = "drag";
	ui_min = -0.5; ui_max = 0.5;
	ui_label = "BD Zoom";
	ui_category = "Depth Corrections";
> = DC_W;
#else
	#if DC
	uniform bool BD_Options <
		ui_label = "Toggle Barrel Distortion";
		ui_tooltip = "Use this if you modded the game to remove Barrel Distortion.";
	ui_category = "Depth Corrections";
	> = !true;
	#else
		static const int BD_Options = 1;
	#endif
static const float3 Colors_K1_K2_K3 = float3(DC_X,DC_Y,DC_Z);
static const float Zoom = DC_W;
#endif
#if BD_Correction || DB_Size_Position
	uniform bool Depth_Guide <
		ui_label = "Alinement Guide";
		ui_tooltip = "Use this for a guide for alinement.";
	ui_category = "Depth Corrections";
	> = !true;
#else
		static const int Depth_Guide = 0;
#endif
//This GI shader is free and shouldn't sit behind a paywall. If you paid for this shader ask for a refund right away.
#if Automatic_Resolution_Scaling //Automatic Adjustment based on Resolutionsup to 4k considered. LOL good luck with 8k in 2020
	#undef RSRes
	#if (BUFFER_HEIGHT <= 720)
		#define RSRes 1.0
	#elif (BUFFER_HEIGHT <= 1080)
		#define RSRes 0.7
	#elif (BUFFER_HEIGHT <= 1440)
		#define RSRes 0.6
	#elif (BUFFER_HEIGHT <= 2160)
		#define RSRes 0.5
	#else
		#define RSRes 0.4 //??? 8k Mystery meat
	#endif
#endif
//This GI shader is free and shouldn't sit behind a paywall. If you paid for this shader ask for a refund right away.
uniform bool Text_Info < source = "key"; keycode = Text_Info_Key; toggle = true; mode = "toggle";>;
#define pix float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT)
#define Near_Far lerp(0,8,saturate(GI_NearFar))
uniform float frametime < source = "frametime"; >;     // Time in milliseconds it took for the last frame to complete.
uniform int framecount < source = "framecount"; >;     // Total amount of frames since the game started.
uniform float timer < source = "timer"; >;             // A timer that starts when the Game starts.
#define Alternate framecount % 2 == 0                  // Alternate per frame
#define PI 3.14159265358979323846264                   // PI
#define sigmaXYZ 30.                                   // Gussian Sigma for vectors XYZ
#define SN_offset float2(3,4)                          // Smooth Normals offests for Guss
/////////////////////////////////////////////////////D3D Starts Here/////////////////////////////////////////////////////////////////
static const float2 XYoffset[8] = { float2( 0,+pix.y ), float2( 0,-pix.y), float2(+pix.x, 0), float2(-pix.x, 0), float2(-pix.x,-pix.y), float2(+pix.x,-pix.y), float2(-pix.x,+pix.y), float2(+pix.x,+pix.y) };

float fmod(float a, float b)
{
	float c = frac(abs(a / b)) * abs(b);
	return a < 0 ? -c : c;
}
#if BD_Correction || DC
float2 D(float2 p, float k1, float k2, float k3) //Lens + Radial lens undistort filtering Left & Right
{   // Normalize the u,v coordinates in the range [-1;+1]
	p = (2. * p - 1.);
	// Calculate Zoom
	p *= 1 + Zoom;
	// Calculate l2 norm
	float r2 = p.x*p.x + p.y*p.y;
	float r4 = r2 * r2;
	float r6 = r4 * r2;
	// Forward transform
	float x2 = p.x * (1. + k1 * r2 + k2 * r4 + k3 * r6);
	float y2 = p.y * (1. + k1 * r2 + k2 * r4 + k3 * r6);
	// De-normalize to the original range
	p.x = (x2 + 1.) * 1. * 0.5;
	p.y = (y2 + 1.) * 1. * 0.5;

return p;
}
#endif
float2 SampleXY()
{
	if (Performance_Level == 0)
		return Denoiser_Power ? float2(2.0,2.0) : float2(3.0,3.0);
	if (Performance_Level == 1)
		return Denoiser_Power ? float2(3.0,3.0) : float2(4.0,4.0);
	if (Performance_Level == 2)
		return Denoiser_Power ? float2(4.0,4.0) : float2(5.0,5.0);
	else
		return float2(6.0,6.0);
}

float Gaussian(float sigma, float x)
{
    return exp(-(x*x) / (2.0 * sigma*sigma));
}

float3 RGBtoYCbCr(float3 rgb)
{
	float Y  =  .299 * rgb.x + .587 * rgb.y + .114 * rgb.z; // Luminance
	float Cb = -.169 * rgb.x - .331 * rgb.y + .500 * rgb.z; // Chrominance Blue
	float Cr =  .500 * rgb.x - .419 * rgb.y - .081 * rgb.z; // Chrominance Red
	return float3(Y,Cb + 128./255.,Cr + 128./255.);
}

float3 YCbCrtoRGB(float3 ycc)
{
	float3 c = ycc - float3(0., 128./255., 128./255.);

	float R = c.x + 1.400 * c.z;
	float G = c.x - 0.343 * c.y - 0.711 * c.z;
	float B = c.x + 1.765 * c.y;
	return float3(R,G,B);
}

float3 Reinhard(float3 color)
{
	return color/(1+color);
}

float3 inv_Reinhard(float4 color)
{
	return color.rgb * rcp(max((1.0 + color.w) - color.rgb,0.001));
}

float3 Saturator(float3 color)
{
	return lerp(dot(color.rgb, 0.333), color.rgb, Saturation.x );
}

texture DepthBufferTex : DEPTH;

sampler ZBuffer
	{
		Texture = DepthBufferTex;
	};

texture BackBufferTex : COLOR;

sampler BackBufferPBGI
	{
		Texture = BackBufferTex;
	};

texture2D PBGIpastTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16f; };
sampler2D PBGIpastFrame { Texture = PBGIpastTex; };

texture2D PBGIaccuTex { Width = BUFFER_WIDTH/2; Height = BUFFER_HEIGHT/2; Format = RGBA8; };
sampler2D PBGIaccuFrames { Texture = PBGIaccuTex; };

texture2D PBGIcurrColorTex < pooled = true; >{ Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; MipLevels = 11;};
sampler2D PBGIcurrColor { Texture = PBGIcurrColorTex;
	MagFilter = POINT;
	MinFilter = POINT;
	MipFilter = POINT;
 };

texture2D PBGIcurrDepthTex < pooled = true; >{ Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = R16f; MipLevels = 11;};
sampler2D PBGIcurrDepth { Texture = PBGIcurrDepthTex;};

texture2D PBGIcurrNormalsTex < pooled = true; >{ Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16f; MipLevels = 11;};
sampler2D PBGIcurrNormals { Texture = PBGIcurrNormalsTex; };

texture2D RadiantGITex  { Width = BUFFER_WIDTH * RSRes ; Height = BUFFER_HEIGHT * RSRes ; Format = RGBA; };//For AO this need to be RGBA16f or RGBA8
sampler2D PBGI_Info { Texture = RadiantGITex; };

texture2D PBGIupsampleTex < pooled = true; > { Width = BUFFER_WIDTH ; Height = BUFFER_HEIGHT ; Format = RGBA;};//For AO this need to be RGBA16f or RGBA8
sampler2D PBGIupsample_Info { Texture = PBGIupsampleTex; };

texture2D PBGIbackbufferTex < pooled = true; > { Width = BUFFER_WIDTH ; Height = BUFFER_HEIGHT ; Format = RGBA;  MipLevels = 4;};
sampler2D PBGIbackbuffer_Info { Texture = PBGIbackbufferTex; };
//Seen issues whe pooling this texture...... may be a fluke can remove it when testing.
texture2D PBGIhorizontalTex < pooled = true; > { Width = BUFFER_WIDTH ; Height = BUFFER_HEIGHT ; Format = RGBA16f;};
sampler2D PBGI_BGUHorizontal_Sample { Texture = PBGIhorizontalTex;};
#if Foced_SNM
texture2D PBGIsmoothnormalsTex < pooled = true; > { Width = BUFFER_WIDTH ; Height = BUFFER_HEIGHT ; Format = RGBA16f;};
sampler2D PBGI_Smooth_Normals { Texture = PBGIsmoothnormalsTex;};
#endif

#if Look_For_Buffers_ReVeil
texture Transmission { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = R16f; };
sampler2D ReVeilTransmission {Texture = Transmission;};
#endif

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
float Depth_Info(float2 texcoord)
{
	#if BD_Correction || DC
	if(BD_Options == 0)
	{
		float3 K123 = Colors_K1_K2_K3 * 0.1;
		texcoord = D(texcoord.xy,K123.x,K123.y,K123.z);
	}
	#endif
	#if DB_Size_Position || SP || LBC || LB_Correction
		texcoord.xy += float2(-Image_Position_Adjust.x,Image_Position_Adjust.y)*0.5;
	#if LBC || LB_Correction
		float2 H_V = Horizontal_and_Vertical * float2(1,LBDetection() ? 1.315 : 1 );
	#else
		float2 H_V = Horizontal_and_Vertical;
	#endif
		float2 midHV = (H_V-1) * float2(BUFFER_WIDTH * 0.5,BUFFER_HEIGHT * 0.5) * pix;
		texcoord = float2((texcoord.x*H_V.x)-midHV.x,(texcoord.y*H_V.y)-midHV.y);
	#endif

	if (Depth_Map_Flip)
		texcoord.y =  1 - texcoord.y;

	//Conversions to linear space.....
	float zBuffer = tex2Dlod(ZBuffer, float4(texcoord,0,0)).x, zBufferWH = zBuffer, Far = 1.0, Near = 0.125/Depth_Map_Adjust, NearWH = 0.125/(Depth_Map ? NCD.y : 10*NCD.y), OtherSettings = Depth_Map ? NCD.y : 100 * NCD.y ; //Near & Far Adjustment
	//Man Why can't depth buffers Just Be Normal
	float2 C = float2( Far / Near, 1.0 - Far / Near ), Z = Offset < 0 ? min( 1.0, zBuffer * ( 1.0 + abs(Offset) ) ) : float2( zBuffer, 1.0 - zBuffer ), Offsets = float2(1 + OtherSettings,1 - OtherSettings), zB = float2( zBufferWH, 1-zBufferWH );

	if(Offset > 0 || Offset < 0)
	Z = Offset < 0 ? float2( Z.x, 1.0 - Z.y ) : min( 1.0, float2( Z.x * (1.0 + Offset) , Z.y / (1.0 - Offset) ) );

	if (NCD.y > 0)
	zB = min( 1, float2( zB.x * Offsets.x , zB.y / Offsets.y  ));

	if (Depth_Map == 0)
	{   //DM0 Normal
		zBuffer = rcp(Z.x * C.y + C.x);
		zBufferWH = Far * NearWH / (Far + zB.x * (NearWH - Far));
	}
	else if (Depth_Map == 1)
	{   //DM1 Reverse
		zBuffer = rcp(Z.y * C.y + C.x);
		zBufferWH = Far * NearWH / (Far + zB.y * (NearWH - Far));
	}

	return  saturate( lerp(NCD.y > 0 ? zBufferWH : zBuffer,zBuffer,0.925) );
}
//Improved Normal reconstruction from Depth
float3 DepthNormals(float2 texcoord)
{
	float2 Pix_Offset = pix.xy;
	//A 2x2 Taps is done here. You can also do 4x4 tap
	float2 uv0 = texcoord; // center
	float2 uv1 = texcoord + float2( Pix_Offset.x, 0); // right
	float2 uv2 = texcoord + float2(-Pix_Offset.x, 0); // left
	float2 uv3 = texcoord + float2( 0, Pix_Offset.y); // down
	float2 uv4 = texcoord + float2( 0,-Pix_Offset.y); // up

	float depth = Depth_Info( uv0 );

	float depthR = Depth_Info( uv1 );
	float depthL = Depth_Info( uv2 );
	float depthD = Depth_Info( uv3 );
	float depthU = Depth_Info( uv4 );

	float3 P0, P1, P2;

	int best_Z_horizontal = abs(depthR - depth) < abs(depthL - depth) ? 1 : 2;
	int best_Z_vertical = abs(depthD - depth) < abs(depthU - depth) ? 3 : 4;

	if (best_Z_horizontal == 1 && best_Z_vertical == 4)
	{   //triangle 0 = P0: center, P1: right, P2: up
		P1 = float3(uv1 - 0.5, 1) * depthR;
		P2 = float3(uv4 - 0.5, 1) * depthU;
	}
	if (best_Z_horizontal == 1 && best_Z_vertical == 3)
	{   //triangle 1 = P0: center, P1: down, P2: right
		P1 = float3(uv3 - 0.5, 1) * depthD;
		P2 = float3(uv1 - 0.5, 1) * depthR;
	}
	if (best_Z_horizontal == 2 && best_Z_vertical == 4)
	{   //triangle 2 = P0: center, P1: up, P2: left
		P1 = float3(uv4 - 0.5, 1) * depthU;
		P2 = float3(uv2 - 0.5, 1) * depthL;
	}
	if (best_Z_horizontal == 2 && best_Z_vertical == 3)
	{   //triangle 3 = P0: center, P1: left, P2: down
		P1 = float3(uv2 - 0.5, 1) * depthL;
		P2 = float3(uv3 - 0.5, 1) * depthD;
	}

	P0 = float3(uv0 - 0.5, 1) * depth;

	return normalize(cross(P2 - P0, P1 - P0));
}

float3 SmoothNormals(float2 TC, int NS,int Dir, float SNOffset)
{   //Smooth Normals done in two passes now Faster. But, still slow.
	float4 StoredNormals_Depth = float4(Dir ? DepthNormals(TC) : tex2Dlod(PBGIcurrNormals,float4(TC,0,0)).xyz,tex2Dlod(PBGIcurrDepth,float4(TC,0,0)).x), SmoothedNormals = float4(StoredNormals_Depth.xyz,1);
	#if Foced_SNM
	[loop] // -1 0 +1 on x and y
	for(float xy = -NS; xy <= NS; xy++)
	{
		if(smoothstep(0,1,StoredNormals_Depth.w) > MaxDepth_Cutoff)
			break;
		float2 XY = Dir ? float2(xy,0) : float2(0,xy);
		float2 offsetcoords = TC + XY * pix * SNOffset;
		float4 Normals_Depth     = float4(Dir ? DepthNormals(offsetcoords) : tex2Dlod(PBGIcurrNormals,float4(offsetcoords,0,0)).xyz,tex2Dlod(PBGIcurrDepth,float4(offsetcoords,0,0)).x);
		if (abs(StoredNormals_Depth.w - Normals_Depth.w) < 0.001 && dot(Normals_Depth.xyz, StoredNormals_Depth.xyz) > 0.5f)
		{
			SmoothedNormals.xyz += Normals_Depth.xyz;
			++SmoothedNormals.w;
		}
	}
	#endif
	return SmoothedNormals.xyz / SmoothedNormals.w;
}
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
float DepthMap(float2 texcoords, int Mips)
{
	return tex2Dlod(PBGIcurrDepth,float4(texcoords,0,Mips)).x;
}

float3 NormalsMap(float2 texcoords, int Mips)
{
	#if Foced_SNM
	float3 BN = tex2Dlod(PBGI_Smooth_Normals,float4(texcoords,0,Mips)).xyz;
	#else
	float3 BN = tex2Dlod(PBGIcurrNormals,float4(texcoords,0,Mips)).xyz;
	#endif
		   //BN.xy = (BN.xy - 0 ) / (0.625 - 0);//Not Needed oh well stored code.
	return BN;
}

float4 BBColor(float2 texcoords, int Mips)
{   float Adapt = tex2Dlod(PBGIcurrColor, float4(0.5,0.5,0,12)).w, LL_Comp = 0.5; //Wanted to automate this but it's really not need.
	float4 BBC = tex2Dlod(PBGIcurrColor, float4(texcoords,0,Mips));
	BBC.rgb = (BBC.rgb - 0.5) * (LL_Comp + 1.0) + 0.5;
	return BBC + (LL_Comp * 0.5625);
}

float Mask(float2 TC)
{
	return (tex2Dlod(PBGIbackbuffer_Info,float4(TC,0,2)).w > 0.0125);
}

void MCNoise(inout float Noise, float FC ,float2 TC,float seed)
{ //This is the noise I used for rendering
	float motion = FC, a = 12.9898, b = 78.233, c = 43758.5453, dt= dot( TC.xy * 2.0 , float2(a,b)), sn= fmod(dt,PI);
	Noise = frac(frac(tan(distance(sn*(seed+dt),  float2(a,b)  )) * c) + 0.61803398875f * motion);
}

float3 GetPosition(float2 coords)
{
	float3 DM = DepthMap(coords, 1 ).xxx;
	return float3(coords.xy*2-1,1.0)*DM;
}
//Disk-to-Disk Form Factor Approximation
void FormFactor(inout float4 GI,inout float3 II,in float2 texcoord,in float3 ddiff_A,in float3 ddiff_B,in float3 normals, in float2 CA, in float2 CB)
{   //So normal and the vector between occluder and occludee, "Element to Element."
	float4 V_A = float4(normalize(-ddiff_A), length(-ddiff_A)), Irradiance_Information = float4(Saturator(II.rgb),1),V_B = float4(normalize(-ddiff_B), length(-ddiff_B));
	float3 Global_Illumination = saturate(100.0 * saturate( dot(NormalsMap(texcoord+float2(CA.x,CB.x),2),-V_A.xyz)) * saturate(dot( normals, V_A.xyz )) /((1000*Trim)*(V_A.w*V_A.w)+1.0) );
	//float AO = (1.0-saturate(dot(NormalsMap(texcoord+float2(CA.y,CB.y),1),-V_B.xyz))) * saturate(dot( normals,V_B.xyz )) * (1.0 - (22.5*AO_Trim)/sqrt(rcp(V_B.w*V_B.w) + 1.0));
	GI += float4(Global_Illumination.rgb,1) * Irradiance_Information;
}

float4 PBGI(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float4 Noise;
	MCNoise( Noise.x, framecount * (1-Mask(texcoord) * bool(!Denoiser_Power)), texcoord, 1 );
	MCNoise( Noise.y, framecount * (1-Mask(texcoord) * bool(!Denoiser_Power)), texcoord, 2 );
	MCNoise( Noise.z, framecount, texcoord, 3 );
	MCNoise( Noise.w, framecount, texcoord, 4 );
	float4 random = Noise.xyzw * 2.0 - 1.0;
	float3 n = NormalsMap(texcoord,0), p = GetPosition(texcoord) * 0.999;
	float4 GI, PWH;
	//Global Illumination Ray Length & Depth
	float GIRL = saturate(GI_Ray_Length * rcp(Max_Ray_Length)),depth = DepthMap(texcoord, 0 ), D = depth;
	//Basic Bayer like pattern. Used for 3 levels of Rays. Color names are a hold over for pattern.
	float2 Angle = float2(Performance_Level > 0 ? PI*PI : 0,0), grid = floor(float2(texcoord.x * BUFFER_WIDTH , texcoord.y * BUFFER_HEIGHT ) * RSRes), rl_gi_ao = float2(GI_Ray_Length,0);//AO_Ray_Length);
	float GB = fmod(grid.x+grid.y,2.0) ? 1 : 0, GR = fmod(grid.x+grid.y,2.0) ? 0.75 : 0.25;
	float Bayer = fmod(grid.x,2.0) ? GR : GB;
	//Did this just because Ceejay said bayer not usefull for anything.
	if(Bayer == 0)
		rl_gi_ao = rl_gi_ao;
	else if(Bayer == 1)
		rl_gi_ao *= 0.375;
	else if(Bayer == 0.75)
		rl_gi_ao *= 0.75;
	else
		rl_gi_ao *= 0.125;
	#if RL_Alternation //Soooooooooo this part not needed. But, I like the look......
		rl_gi_ao.x = Alternate ? rl_gi_ao.x * 0.75 : rl_gi_ao.x;//This stresses the TAA.
	#endif
	float GS = GIRL < 0.25 ? lerp(1.0,0.250,saturate(GIRL * 4)) : lerp(0.250,0.075,GIRL), SG = Sparse_Grid ? fmod(grid.x*grid.y,2.0) : 0;
	//Basic depth rescaling from Near to Far
	depth = smoothstep(-NCD.x,1, depth );
	float w_gi = (pix.x*rl_gi_ao.x*random.x)/depth, h_gi = (pix.y*rl_gi_ao.x*random.y)/depth;
	//depth = smoothstep(-1,1, D ) ;
	float w_ao = (pix.x*rl_gi_ao.y*random.z)/depth, h_ao = (pix.y*rl_gi_ao.y*random.w)/depth;
	[fastopt] // Dose this even do anything better vs unroll? Compile times seem the same too me. Maybe this will work better if I use the souls I collect of the users that use this shader?
	for (int i = 0; i <= samples; i ++)
	{ //Sparse grid to increase perf and Max Depth Exclusion...... every ms counts.........
		if(SG || smoothstep(0,1,D) > MaxDepth_Cutoff)
			break;
		//Reflection vectors in space are constant we just add more samples in tangent space.
		float2 rot = radians(Angle);
		PWH = float4(float2(cos(rot.x)*w_gi-sin(rot.x)*w_gi, sin(rot.x)*h_gi+cos(rot.x)*h_gi),float2(0,0));//float2(cos(rot.y)*w_ao-sin(rot.y)*w_ao, sin(rot.y)*h_ao+cos(rot.y)*h_ao));
		//This is view vectors
		float3 ddiff = GetPosition(texcoord+float2(PWH.x,PWH.y))-p, ddiff_B;// = GetPosition(texcoord+float2(PWH.z,PWH.w))-p;
		//Irradiance Information
		float3 II = BBColor(texcoord+float2(PWH.x, PWH.y),clamp(int(3+GI_AT),3,8)).rgb;
		//GI and AO Form Factor code look above
		FormFactor(GI, II, texcoord, ddiff, ddiff_B, n, PWH.xz, PWH.yw);

		Angle += 360.0/(PI*PI);
	}
	
	GI *= rcp(samples);

	float4 output = float4(RGBtoYCbCr( (GI.rgb * ( lerp(Near_Far.y,Near_Far.x, 1-D ) * min(GI_Power.x,2.0) ))), 0);//1-GI.w*2.5);
	#if Look_For_Buffers_ReVeil //Lord of Lunacy DeHaze insertion was here.
	if(UseReVeil)
	{
		output.r *= tex2D(ReVeilTransmission, texcoord).r;
	}
	#endif
	return output;
}

float4 GI_Adjusted(float2 TC, int Mip)
{
	float4 Convert = tex2Dlod(PBGI_Info, float4(TC,0, Mip)).xyzw;
	float GILP = Sparse_Grid ? 0.65625 : 0.5;
	Convert.x *= GILP;
	return float4(Saturator(YCbCrtoRGB(Convert.xyz)),Convert.w);
}

void Upsample(float4 vpos : SV_Position, float2 texcoords : TEXCOORD, out float4 UpGI : SV_Target0, out float4 ColorOut : SV_Target1, out float3 SN : SV_Target2)
{ // May want to rewrite this.
	float DepthMask;
	float2 Offsets = 2.0, vClosest = texcoords, vBilinearWeight = 1.0 - frac(texcoords);
	float4 fTotalGI, fTotalWeight;
	[unroll]
	for(float x = 0.0; x < 2.0; ++x)
	{
		for(float y = 0.0; y < 2.0; ++y)
		{
			 // Sample depth (stored in meters) and AO for the half resolution
			 float fSampleDepth = DepthMap( vClosest + float2(x,y) * pix,0);
			 float4 fSampleGI = GI_Adjusted(vClosest + float2(x,y) * pix / RSRes,0);
			 // Calculate bilinear weight
			 float fBilinearWeight = (x-vBilinearWeight.x) * (y-vBilinearWeight.y);
			 // Calculate upsample weight based on how close the depth is to the main depth
			 float fUpsampleWeight = max(0.00001, 0.1 - abs(fSampleDepth - DepthMap(texcoords,0) ) ) * 30.0;
			 // Apply weight and add to total sum
			 fTotalGI += (fBilinearWeight + fUpsampleWeight) * fSampleGI;
			 fTotalWeight += (fBilinearWeight + fUpsampleWeight);
		}
	}

float Depth = DepthMap(texcoords,0), FakeAO = (Depth + DepthMap(texcoords + float2(pix.x ,0),1) + DepthMap(texcoords + float2(-pix.x ,0),2) + DepthMap(texcoords + float2(0,pix.y ),3)  + DepthMap(texcoords + float2(0,-pix.y ), 4) ) * 0.2;
	DepthMask = 1-(Depth/FakeAO> 0.997);
	// Divide by total sum to get final GI
	UpGI = fTotalGI / fTotalWeight;
	ColorOut = float4(tex2D(BackBufferPBGI,texcoords).rgb,DepthMask);
	SN = SmoothNormals(texcoords, SN_offset.x, 0, SN_offset.y);
}

float4 GI(float2 TC)
{ //CeeJay Said to place noise after the TAA pass. I ignored him and put it here.......
	float4  Noise;
	MCNoise( Noise.x, framecount, TC, 1 );
	MCNoise( Noise.y, framecount, TC, 2 );
	MCNoise( Noise.z, framecount, TC, 3 );
	MCNoise( Noise.w, framecount, TC, 4 );
	float4 N = float4(Noise.xyz * 0.5 + 0.5,Noise.w + 0.5);
	#line 1337 "For the latest version go https://blueskydefender.github.io/AstrayFX/ or http://www.Depth3D.info�
	#warning ""
return tex2Dlod(PBGIupsample_Info, float4(TC,0,0)).xyzw * N;
}
//	float Denoise_Adjustment = Denoiser_Power == 0 ? lerp(lerp(1,25, V_Buffer),6.25,Mask(texcoords)) : lerp(1,25, V_Buffer);
// * Denoise_Adjustment
//		GI_Blur += GI(texcoords + Offset * Denoise_Adjustment )*0.125;
void GI_TAA(float4 vpos : SV_Position, float2 texcoords : TEXCOORD, out float4 color : SV_Target0)
{   //Depth Similarity
	//float M_Similarity = 0.0, D_Similarity = saturate(pow(abs(DepthMap(texcoords, 0)/tex2D(PBGIpastFrame,texcoords).w), 4) + M_Similarity);
	//Velocity Scailer
	float S_Velocity = 12.5 * lerp(1,80,TAA_Clamping), V_Buffer = saturate(distance(DepthMap(texcoords, 0),tex2D(PBGIpastFrame,texcoords).w) * S_Velocity);
	//Accumulation buffer Start
    float4 PastColor = tex2Dlod(PBGIaccuFrames,float4(texcoords,0,0) );
	float3 CurrAOGI = GI(texcoords);

	float3 antialiased = PastColor.xyz;
	float mixRate = min(PastColor.w, 0.5), MB;// = -0.0025;

	antialiased = lerp(antialiased * antialiased, CurrAOGI.rgb * CurrAOGI.rgb, mixRate);
	antialiased = sqrt(antialiased);
	
	float Denoise_Adjustment = Denoiser_Power == 1 ? lerp(4,1,Mask(texcoords)) : 4;

	float3 minColor = CurrAOGI - MB;
	float3 maxColor = CurrAOGI + MB;

	[unroll]
	for(int i = 0; i < 8; ++i)
	{   float2 Offset = XYoffset[i] * (RSRes + Denoise_Adjustment);
		float3 GISamples = GI(texcoords + Offset ).rgb;
		minColor = min(minColor,GISamples) - MB;
		maxColor = max(maxColor,GISamples) + MB;
	}
	//Min Max neighbourhood clamping.
	antialiased = clamp(antialiased, minColor, maxColor);

	mixRate = rcp(1.0 / mixRate + 1.0);
	//Added Velocity Clamping.......
	float clampAmount = V_Buffer;

	mixRate += clampAmount;
	mixRate = clamp(mixRate, 0.05, 0.5);

	float4  TAA = float4(antialiased,mixRate),GIStored = float4(CurrAOGI,1);
	//Sample from Accumulation buffer, with mix rate clamping.
	color = lerp(TAA,GIStored,Mask(texcoords) * bool(!Denoiser_Power));
}

float4 Captured_GI(float2 texcoord)
{
	return tex2Dlod(BackBufferPBGI, float4(texcoord,0,0)).rgba;
}
//Joint Bilateral Gaussian Upscaling
float4 JointBGU(float2 TC, int SamplesXY,int Dir)
{   //Captured_GI(texcoords).w // Add A blur mask for motion denoise
	float4 StoredNormals_Depth = float4(NormalsMap(TC,0),DepthMap(TC,0));
	float4 total, ret, modified, origin =  Dir ? tex2Dlod(PBGI_BGUHorizontal_Sample,float4(TC,0,0)) : Captured_GI(TC);
	float DM = smoothstep(0,1,StoredNormals_Depth.w) > MaxDepth_Cutoff, MB = tex2Dlod(BackBufferPBGI, float4(TC,0,0)).w;
	if(!DM)
	{
		[fastopt]
		for (float xy = -SamplesXY; xy <= SamplesXY; xy++)
		{
			float GXYZ = Gaussian( sigmaXYZ, xy ), G = GXYZ * GXYZ;
			float2 XY = Dir ? float2(xy,0) : float2(0,xy), offsetxy = TC + XY * pix.xy * lerp(4,16,MB * bool(!Debug));
			float4 ModifiedNormals_Depth = float4(NormalsMap(offsetxy,0),DepthMap(offsetxy,0));
			if (abs(StoredNormals_Depth.w - ModifiedNormals_Depth.w) < 0.01 && dot(ModifiedNormals_Depth.xyz, StoredNormals_Depth.xyz) > 0.5f)
			{
				modified =  Dir ? tex2Dlod(PBGI_BGUHorizontal_Sample,float4(offsetxy,0,0)) : Captured_GI(offsetxy);
				float FinalG = Gaussian( sigmaXYZ, length(modified - origin) );

				total += G * FinalG;
				ret += G * FinalG * modified;
			}
		}
	}
	return ret / (DM ? 1 : total);
}
//Horizontal Bilateral Gaussian Upscaling
float4 BGU_Hoz(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	return JointBGU(texcoord, SampleXY().x , 0);
}
//Vertical Bilateral Gaussian Upscaling
float4 JBGU(float2 texcoord)
{
	return JointBGU(texcoord, SampleXY().y , 1);
}

float getAvgColor( float3 col )
{
    return dot( col.xyz, float3( 0.333333f, 0.333334f, 0.333333f ));
}
/*
float3 ClipColor( float3 color )
{
    float lum         = getAvgColor( color.xyz );
    float mincol      = min( min( color.x, color.y ), color.z );
    float maxcol      = max( max( color.x, color.y ), color.z );
    color.xyz         = ( mincol < 0.0f ) ? lum + (( color.xyz - lum ) * lum ) / ( lum - mincol ) : color.xyz;
    color.xyz         = ( maxcol > 1.0f ) ? lum + (( color.xyz - lum ) * ( 1.0f - lum )) / ( maxcol - lum ) : color.xyz;
    return color;
}
float3 blendLuma( float3 base, float3 blend )
{
    float lumbase     = getAvgColor( base.xyz );
    float lumblend    = getAvgColor( blend.xyz );
    float ldiff       = lumblend - lumbase;
    float3 col        = base.xyz + ldiff;
    return ClipColor( col.xyz );
}
*/
float3 overlay(float3 c, float3 b) 		{ return c<0.5f ? 2.0f*c*b:(1.0f-2.0f*(1.0f-c)*(1.0f-b));}
float3 softlight(float3 c, float3 b) 	{ return b<0.5f ? (2.0f*c*b+c*c*(1.0f-2.0f*b)):(sqrt(c)*(2.0f*b-1.0f)+2.0f*c*(1.0f-b));}
float3 add(float3 c, float3 b) 	{ return c + (b * 0.5);}
//float3 blendcolor(float3 c, float3 b)       { return blendLuma(b,c);}
float3 Composite(float2 texcoords)
{   //float RealAO = JBGU(texcoords).w;
	float3 Output = Saturator(JBGU(texcoords).rgb) , Color = tex2D(PBGIbackbuffer_Info,texcoords).rgb , FiftyGray = (Output + 0.5);
	#if Controlled_Blend
		Output = (lerp( overlay( Color,  FiftyGray), softlight( Color,  FiftyGray), Blend)+ add( Color,  Output)) / 2 ;
	#else
	if(BM == 0)
		Output = (lerp( overlay( Color,  FiftyGray), softlight( Color,  FiftyGray), 0.5 ) + add( Color,  Output)) / 2;
	else if(BM == 1)
		Output = overlay( Color,  FiftyGray);
	else
		Output = softlight( Color,  FiftyGray);
	#endif
	return Output;
}

float3 MixOut(float2 texcoords)
{
	float3 Layer = Composite(texcoords).rgb;
	float Depth = DepthMap(texcoords,0), FakeAO = Debug == 1 || Depth_Guide ? (Depth + DepthMap(texcoords + float2(pix.x * 2,0),1) + DepthMap(texcoords + float2(-pix.x * 2,0),2) + DepthMap(texcoords + float2(0,pix.y * 2),Depth_Guide ? 3 : 8)  + DepthMap(texcoords + float2(0,-pix.y * 2),Depth_Guide ? 4 : 10) ) * 0.2 : 0;
	float3 Output = Saturator(JBGU(texcoords).rgb);
	if(Debug == 0)
		return Depth_Guide ? Layer * float3((Depth/FakeAO> 0.998),1,(Depth/FakeAO > 0.998))  : Layer;
	else if(Debug == 1)
		return lerp(Output + 0.50 * lerp(1-(Depth-FakeAO) ,1,smoothstep(0,1,Depth) == 1),Output,Dark_Mode); //This fake AO is a lie..........
	else	
		return texcoords.x + texcoords.y < 1 ? DepthMap(texcoords, 0 ) : NormalsMap(texcoords,0) * 0.5 + 0.5;
}
////////////////////////////////////////////////////////////////Overwatch////////////////////////////////////////////////////////////////////////////
static const float  CH_A    = float(0x69f99), CH_B    = float(0x79797), CH_C    = float(0xe111e),
					CH_D    = float(0x79997), CH_E    = float(0xf171f), CH_F    = float(0xf1711),
					CH_G    = float(0xe1d96), CH_H    = float(0x99f99), CH_I    = float(0xf444f),
					CH_J    = float(0x88996), CH_K    = float(0x95159), CH_L    = float(0x1111f),
					CH_M    = float(0x9fd99), CH_N    = float(0x9bd99), CH_O    = float(0x69996),
					CH_P    = float(0x79971), CH_Q    = float(0x69b5a), CH_R    = float(0x79759),
					CH_S    = float(0xe1687), CH_T    = float(0xf4444), CH_U    = float(0x99996),
					CH_V    = float(0x999a4), CH_W    = float(0x999f9), CH_X    = float(0x99699),
					CH_Y    = float(0x99e8e), CH_Z    = float(0xf843f), CH_0    = float(0x6bd96),
					CH_1    = float(0x46444), CH_2    = float(0x6942f), CH_3    = float(0x69496),
					CH_4    = float(0x99f88), CH_5    = float(0xf1687), CH_6    = float(0x61796),
					CH_7    = float(0xf8421), CH_8    = float(0x69696), CH_9    = float(0x69e84),
					CH_APST = float(0x66400), CH_PI   = float(0x0faa9), CH_UNDS = float(0x0000f),
					CH_HYPH = float(0x00600), CH_TILD = float(0x0a500), CH_PLUS = float(0x02720),
					CH_EQUL = float(0x0f0f0), CH_SLSH = float(0x08421), CH_EXCL = float(0x33303),
					CH_QUES = float(0x69404), CH_COMM = float(0x00032), CH_FSTP = float(0x00002),
					CH_QUOT = float(0x55000), CH_BLNK = float(0x00000), CH_COLN = float(0x00202),
					CH_LPAR = float(0x42224), CH_RPAR = float(0x24442);
#define MAP_SIZE float2(4,5)
//returns the status of a bit in a bitmap. This is done value-wise, so the exact representation of the float doesn't really matter.
float getBit( float map, float index )
{   // Ooh -index takes out that divide :)
    return fmod( floor( map * exp2(-index) ), 2.0 );
}

float drawChar( float Char, float2 pos, float2 size, float2 TC )
{   // Subtract our position from the current TC so that we can know if we're inside the bounding box or not.
    TC -= pos;
    // Divide the screen space by the size, so our bounding box is 1x1.
    TC /= size;
    // Create a place to store the result & Branchless bounding box check.
    float res = step(0.0,min(TC.x,TC.y)) - step(1.0,max(TC.x,TC.y));
    // Go ahead and multiply the TC by the bitmap size so we can work in bitmap space coordinates.
    TC *= MAP_SIZE;
    // Get the appropriate bit and return it.
    res*=getBit( Char, 4.0*floor(TC.y) + floor(TC.x) );
    return saturate(res);
}

float3 Out(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float2 TC = float2(texcoord.x,1-texcoord.y);
	float Gradient = (1-texcoord.y*50.0+48.85)*texcoord.y-0.500, Text_Timer = 12500, BT = smoothstep(0,1,sin(timer*(3.75/1000))), Size = 1.1, Depth3D, Read_Help, Supported, SetFoV, FoV, Post, Effect, NoPro, NotCom, Mod, Needs, Net, Over, Set, AA, Emu, Not, No, Help, Fix, Need, State, SetAA, SetWP, Work;
	float3 Color = MixOut(texcoord).rgb;

	if(RH || NC || NP || NF || PE || DS || OS || DA || NW || FV)
		Text_Timer = 25000;

	[branch] if(timer <= Text_Timer || Text_Info)
	{ // Set a general character size...
		float2 charSize = float2(.00875, .0125) * Size;
		// Starting position.
		float2 charPos = float2( 0.009, 0.9725);
		//Needs Copy Depth and/or Depth Selection
		Needs += drawChar( CH_N, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_E, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_E, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_D, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_S, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_BLNK, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_C, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_O, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_P, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_Y, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_BLNK, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_D, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_E, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_P, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_T, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_H, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_BLNK, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_A, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_N, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_D, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_SLSH, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_O, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_R, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_BLNK, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_D, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_E, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_P, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_T, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_H, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_BLNK, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_S, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_E, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_L, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_E, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_C, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_T, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_I, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_O, charPos, charSize, TC); charPos.x += .01 * Size;
		Needs += drawChar( CH_N, charPos, charSize, TC);
		//Network Play May Need Modded DLL
		charPos = float2( 0.009, 0.955);
		Work += drawChar( CH_N, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_E, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_T, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_W, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_O, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_R, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_K, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_BLNK, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_P, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_L, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_A, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_Y, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_BLNK, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_M, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_A, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_Y, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_BLNK, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_N, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_E, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_E, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_D, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_BLNK, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_M, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_O, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_D, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_D, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_E, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_D, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_BLNK, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_D, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_L, charPos, charSize, TC); charPos.x += .01 * Size;
		Work += drawChar( CH_L, charPos, charSize, TC);
		//Disable CA/MB/Dof/Grain
		charPos = float2( 0.009, 0.9375);
		Effect += drawChar( CH_D, charPos, charSize, TC); charPos.x += .01 * Size;
		Effect += drawChar( CH_I, charPos, charSize, TC); charPos.x += .01 * Size;
		Effect += drawChar( CH_S, charPos, charSize, TC); charPos.x += .01 * Size;
		Effect += drawChar( CH_A, charPos, charSize, TC); charPos.x += .01 * Size;
		Effect += drawChar( CH_B, charPos, charSize, TC); charPos.x += .01 * Size;
		Effect += drawChar( CH_L, charPos, charSize, TC); charPos.x += .01 * Size;
		Effect += drawChar( CH_E, charPos, charSize, TC); charPos.x += .01 * Size;
		Effect += drawChar( CH_BLNK, charPos, charSize, TC); charPos.x += .01 * Size;
		Effect += drawChar( CH_C, charPos, charSize, TC); charPos.x += .01 * Size;
		Effect += drawChar( CH_A, charPos, charSize, TC); charPos.x += .01 * Size;
		Effect += drawChar( CH_SLSH, charPos, charSize, TC); charPos.x += .01 * Size;
		Effect += drawChar( CH_M, charPos, charSize, TC); charPos.x += .01 * Size;
		Effect += drawChar( CH_B, charPos, charSize, TC); charPos.x += .01 * Size;
		Effect += drawChar( CH_SLSH, charPos, charSize, TC); charPos.x += .01 * Size;
		Effect += drawChar( CH_D, charPos, charSize, TC); charPos.x += .01 * Size;
		Effect += drawChar( CH_O, charPos, charSize, TC); charPos.x += .01 * Size;
		Effect += drawChar( CH_F, charPos, charSize, TC); charPos.x += .01 * Size;
		Effect += drawChar( CH_SLSH, charPos, charSize, TC); charPos.x += .01 * Size;
		Effect += drawChar( CH_G, charPos, charSize, TC); charPos.x += .01 * Size;
		Effect += drawChar( CH_R, charPos, charSize, TC); charPos.x += .01 * Size;
		Effect += drawChar( CH_A, charPos, charSize, TC); charPos.x += .01 * Size;
		Effect += drawChar( CH_I, charPos, charSize, TC); charPos.x += .01 * Size;
		Effect += drawChar( CH_N, charPos, charSize, TC);
		//Disable TAA/MSAA/AA
		charPos = float2( 0.009, 0.920);
		SetAA += drawChar( CH_D, charPos, charSize, TC); charPos.x += .01 * Size;
		SetAA += drawChar( CH_I, charPos, charSize, TC); charPos.x += .01 * Size;
		SetAA += drawChar( CH_S, charPos, charSize, TC); charPos.x += .01 * Size;
		SetAA += drawChar( CH_A, charPos, charSize, TC); charPos.x += .01 * Size;
		SetAA += drawChar( CH_B, charPos, charSize, TC); charPos.x += .01 * Size;
		SetAA += drawChar( CH_L, charPos, charSize, TC); charPos.x += .01 * Size;
		SetAA += drawChar( CH_E, charPos, charSize, TC); charPos.x += .01 * Size;
		SetAA += drawChar( CH_BLNK, charPos, charSize, TC); charPos.x += .01 * Size;
		SetAA += drawChar( CH_T, charPos, charSize, TC); charPos.x += .01 * Size;
		SetAA += drawChar( CH_A, charPos, charSize, TC); charPos.x += .01 * Size;
		SetAA += drawChar( CH_A, charPos, charSize, TC); charPos.x += .01 * Size;
		SetAA += drawChar( CH_SLSH, charPos, charSize, TC); charPos.x += .01 * Size;
		SetAA += drawChar( CH_M, charPos, charSize, TC); charPos.x += .01 * Size;
		SetAA += drawChar( CH_S, charPos, charSize, TC); charPos.x += .01 * Size;
		SetAA += drawChar( CH_A, charPos, charSize, TC); charPos.x += .01 * Size;
		SetAA += drawChar( CH_A, charPos, charSize, TC); charPos.x += .01 * Size;
		SetAA += drawChar( CH_SLSH, charPos, charSize, TC); charPos.x += .01 * Size;
		SetAA += drawChar( CH_A, charPos, charSize, TC); charPos.x += .01 * Size;
		SetAA += drawChar( CH_A, charPos, charSize, TC);
		//Set FoV
		charPos = float2( 0.009, 0.9025);
		SetFoV += drawChar( CH_S, charPos, charSize, TC); charPos.x += .01 * Size;
		SetFoV += drawChar( CH_E, charPos, charSize, TC); charPos.x += .01 * Size;
		SetFoV += drawChar( CH_T, charPos, charSize, TC); charPos.x += .01 * Size;
		SetFoV += drawChar( CH_BLNK, charPos, charSize, TC); charPos.x += .01 * Size;
		SetFoV += drawChar( CH_F, charPos, charSize, TC); charPos.x += .01 * Size;
		SetFoV += drawChar( CH_O, charPos, charSize, TC); charPos.x += .01 * Size;
		SetFoV += drawChar( CH_V, charPos, charSize, TC);
		//Read Help
		charPos = float2( 0.894, 0.9725);
		Read_Help += drawChar( CH_R, charPos, charSize, TC); charPos.x += .01 * Size;
		Read_Help += drawChar( CH_E, charPos, charSize, TC); charPos.x += .01 * Size;
		Read_Help += drawChar( CH_A, charPos, charSize, TC); charPos.x += .01 * Size;
		Read_Help += drawChar( CH_D, charPos, charSize, TC); charPos.x += .01 * Size;
		Read_Help += drawChar( CH_BLNK, charPos, charSize, TC); charPos.x += .01 * Size;
		Read_Help += drawChar( CH_H, charPos, charSize, TC); charPos.x += .01 * Size;
		Read_Help += drawChar( CH_E, charPos, charSize, TC); charPos.x += .01 * Size;
		Read_Help += drawChar( CH_L, charPos, charSize, TC); charPos.x += .01 * Size;
		Read_Help += drawChar( CH_P, charPos, charSize, TC);
		//New Start
		charPos = float2( 0.009, 0.018);
		// No Profile
		NoPro += drawChar( CH_N, charPos, charSize, TC); charPos.x += .01 * Size;
		NoPro += drawChar( CH_O, charPos, charSize, TC); charPos.x += .01 * Size;
		NoPro += drawChar( CH_BLNK, charPos, charSize, TC); charPos.x += .01 * Size;
		NoPro += drawChar( CH_P, charPos, charSize, TC); charPos.x += .01 * Size;
		NoPro += drawChar( CH_R, charPos, charSize, TC); charPos.x += .01 * Size;
		NoPro += drawChar( CH_O, charPos, charSize, TC); charPos.x += .01 * Size;
		NoPro += drawChar( CH_F, charPos, charSize, TC); charPos.x += .01 * Size;
		NoPro += drawChar( CH_I, charPos, charSize, TC); charPos.x += .01 * Size;
		NoPro += drawChar( CH_L, charPos, charSize, TC); charPos.x += .01 * Size;
		NoPro += drawChar( CH_E, charPos, charSize, TC); charPos.x = 0.009;
		//Not Compatible
		NotCom += drawChar( CH_N, charPos, charSize, TC); charPos.x += .01 * Size;
		NotCom += drawChar( CH_O, charPos, charSize, TC); charPos.x += .01 * Size;
		NotCom += drawChar( CH_T, charPos, charSize, TC); charPos.x += .01 * Size;
		NotCom += drawChar( CH_BLNK, charPos, charSize, TC); charPos.x += .01 * Size;
		NotCom += drawChar( CH_C, charPos, charSize, TC); charPos.x += .01 * Size;
		NotCom += drawChar( CH_O, charPos, charSize, TC); charPos.x += .01 * Size;
		NotCom += drawChar( CH_P, charPos, charSize, TC); charPos.x += .01 * Size;
		NotCom += drawChar( CH_A, charPos, charSize, TC); charPos.x += .01 * Size;
		NotCom += drawChar( CH_T, charPos, charSize, TC); charPos.x += .01 * Size;
		NotCom += drawChar( CH_I, charPos, charSize, TC); charPos.x += .01 * Size;
		NotCom += drawChar( CH_B, charPos, charSize, TC); charPos.x += .01 * Size;
		NotCom += drawChar( CH_L, charPos, charSize, TC); charPos.x += .01 * Size;
		NotCom += drawChar( CH_E, charPos, charSize, TC); charPos.x = 0.009;
		//Needs Fix/Mod
		Mod += drawChar( CH_N, charPos, charSize, TC); charPos.x += .01 * Size;
		Mod += drawChar( CH_E, charPos, charSize, TC); charPos.x += .01 * Size;
		Mod += drawChar( CH_E, charPos, charSize, TC); charPos.x += .01 * Size;
		Mod += drawChar( CH_D, charPos, charSize, TC); charPos.x += .01 * Size;
		Mod += drawChar( CH_S, charPos, charSize, TC); charPos.x += .01 * Size;
		Mod += drawChar( CH_BLNK, charPos, charSize, TC); charPos.x += .01 * Size;
		Mod += drawChar( CH_F, charPos, charSize, TC); charPos.x += .01 * Size;
		Mod += drawChar( CH_I, charPos, charSize, TC); charPos.x += .01 * Size;
		Mod += drawChar( CH_X, charPos, charSize, TC); charPos.x += .01 * Size;
		Mod += drawChar( CH_SLSH, charPos, charSize, TC); charPos.x += .01 * Size;
		Mod += drawChar( CH_M, charPos, charSize, TC); charPos.x += .01 * Size;
		Mod += drawChar( CH_O, charPos, charSize, TC); charPos.x += .01 * Size;
		Mod += drawChar( CH_D, charPos, charSize, TC); charPos.x = 0.009;
		//Overwatch.fxh Missing
		State += drawChar( CH_O, charPos, charSize, TC); charPos.x += .01 * Size;
		State += drawChar( CH_V, charPos, charSize, TC); charPos.x += .01 * Size;
		State += drawChar( CH_E, charPos, charSize, TC); charPos.x += .01 * Size;
		State += drawChar( CH_R, charPos, charSize, TC); charPos.x += .01 * Size;
		State += drawChar( CH_W, charPos, charSize, TC); charPos.x += .01 * Size;
		State += drawChar( CH_A, charPos, charSize, TC); charPos.x += .01 * Size;
		State += drawChar( CH_T, charPos, charSize, TC); charPos.x += .01 * Size;
		State += drawChar( CH_C, charPos, charSize, TC); charPos.x += .01 * Size;
		State += drawChar( CH_H, charPos, charSize, TC); charPos.x += .01 * Size;
		State += drawChar( CH_FSTP, charPos, charSize, TC); charPos.x += .01 * Size;
		State += drawChar( CH_F, charPos, charSize, TC); charPos.x += .01 * Size;
		State += drawChar( CH_X, charPos, charSize, TC); charPos.x += .01 * Size;
		State += drawChar( CH_H, charPos, charSize, TC); charPos.x += .01 * Size;
		State += drawChar( CH_BLNK, charPos, charSize, TC); charPos.x += .01 * Size;
		State += drawChar( CH_M, charPos, charSize, TC); charPos.x += .01 * Size;
		State += drawChar( CH_I, charPos, charSize, TC); charPos.x += .01 * Size;
		State += drawChar( CH_S, charPos, charSize, TC); charPos.x += .01 * Size;
		State += drawChar( CH_S, charPos, charSize, TC); charPos.x += .01 * Size;
		State += drawChar( CH_I, charPos, charSize, TC); charPos.x += .01 * Size;
		State += drawChar( CH_N, charPos, charSize, TC); charPos.x += .01 * Size;
		State += drawChar( CH_G, charPos, charSize, TC);
		//New Size
		float D3D_Size_A = 1.375,D3D_Size_B = 0.75;
		float2 charSize_A = float2(.00875, .0125) * D3D_Size_A, charSize_B = float2(.00875, .0125) * D3D_Size_B;
		//New Start Pos
		charPos = float2( 0.862, 0.018);
		//Depth3D.Info Logo/Website
		Depth3D += drawChar( CH_D, charPos, charSize_A, TC); charPos.x += .01 * D3D_Size_A;
		Depth3D += drawChar( CH_E, charPos, charSize_A, TC); charPos.x += .01 * D3D_Size_A;
		Depth3D += drawChar( CH_P, charPos, charSize_A, TC); charPos.x += .01 * D3D_Size_A;
		Depth3D += drawChar( CH_T, charPos, charSize_A, TC); charPos.x += .01 * D3D_Size_A;
		Depth3D += drawChar( CH_H, charPos, charSize_A, TC); charPos.x += .01 * D3D_Size_A;
		Depth3D += drawChar( CH_3, charPos, charSize_A, TC); charPos.x += .01 * D3D_Size_A;
		Depth3D += drawChar( CH_D, charPos, charSize_A, TC); charPos.x += 0.008 * D3D_Size_A;
		Depth3D += drawChar( CH_FSTP, charPos, charSize_A, TC); charPos.x += 0.01 * D3D_Size_A;
		charPos = float2( 0.963, 0.018);
		Depth3D += drawChar( CH_I, charPos, charSize_B, TC); charPos.x += .01 * D3D_Size_B;
		Depth3D += drawChar( CH_N, charPos, charSize_B, TC); charPos.x += .01 * D3D_Size_B;
		Depth3D += drawChar( CH_F, charPos, charSize_B, TC); charPos.x += .01 * D3D_Size_B;
		Depth3D += drawChar( CH_O, charPos, charSize_B, TC);
		//Text Information
		if(DS)
			Need = Needs;
		if(RH)
			Help = Read_Help;
		if(NW)
			Net = Work;
		if(PE)
			Post = Effect;
		if(DA)
			AA = SetAA;
		if(FV)
			FoV = SetFoV;
		//Blinking Text Warnings
		if(NP)
			No = NoPro * BT;
		if(NC)
			Not = NotCom * BT;
		if(NF)
			Fix = Mod * BT;
		if(OS)
			Over = State * BT;
		//Website
		return Depth3D+(Disable_Debug_Info ? 0 : Help+Post+No+Not+Net+Fix+Need+Over+AA+Set+FoV+Emu) ? Minimize_Web_Info ? lerp(Gradient + Depth3D,Color,saturate(Depth3D*0.98)) : Gradient : Color;
	}
	else
		return Color;
}

void CurrentFrame(float4 vpos : SV_Position, float2 texcoord : TEXCOORD, out float4 Color : SV_Target0, out float3 Depth : SV_Target1, out float3 Normals : SV_Target2)
{
	float4 BC = tex2D(BackBufferPBGI,texcoord).rgba;
	if(HDR_BP > 0)
		BC.rgb = inv_Reinhard(float4(BC.rgb,1-HDR_BP));

	float DI = Depth_Info(texcoord), GS = dot(tex2D(BackBufferPBGI,texcoord).rgb,0.333);//Intencity
	Color = float4(lerp(BC.rgb ,0, smoothstep(0,1,DI) > MaxDepth_Cutoff ), GS) ;
	Depth = DI;
	Normals = SmoothNormals(texcoord, SN_offset.x, 1, SN_offset.y);
}

void AccumulatedFramesGI(float4 vpos : SV_Position, float2 texcoords : TEXCOORD, out float4 acc : SV_Target)
{
	acc = tex2D(BackBufferPBGI,texcoords).rgba;
}

void AccumulatedFramesAO(float4 vpos : SV_Position, float2 texcoords : TEXCOORD, out float4 acc : SV_Target)
{
	acc = tex2D(BackBufferPBGI,texcoords).rgba;
}

void PreviousFrames(float4 vpos : SV_Position, float2 texcoords : TEXCOORD, out float4 prev : SV_Target)
{
	prev = float4(0,0,0,DepthMap(texcoords, 0));
}

//////////////////////////////////////////////////////////Reshade.fxh/////////////////////////////////////////////////////////////
// Vertex shader generating a triangle covering the entire screen
void PostProcessVS(in uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD)
{
	texcoord.x = (id == 2) ? 2.0 : 0.0;
	texcoord.y = (id == 1) ? 2.0 : 0.0;
	position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}
//*Rendering passes*//
technique PBGI_One
< toggle = 0x23;
ui_tooltip = "Alpha: Disk-to-Disk Global Illumination Primary Generator.¹"; >
{
		pass PastFrames
	{
		VertexShader = PostProcessVS;
		PixelShader = PreviousFrames;
		RenderTarget0 = PBGIpastTex;
	}
		pass CopyFrame
	{
		VertexShader = PostProcessVS;
		PixelShader = CurrentFrame;
		RenderTarget0 = PBGIcurrColorTex;
		RenderTarget1 = PBGIcurrDepthTex;
		RenderTarget2 = PBGIcurrNormalsTex;
	}
		pass SSGI
	{
		VertexShader = PostProcessVS;
		PixelShader = PBGI;
		RenderTarget = RadiantGITex;
	}
		pass Upsample
	{
		VertexShader = PostProcessVS;
		PixelShader = Upsample;
		RenderTarget0 = PBGIupsampleTex;
		RenderTarget1 = PBGIbackbufferTex;
		#if Foced_SNM
		RenderTarget2 = PBGIsmoothnormalsTex;
		#endif
	}
		pass TAA
	{
		VertexShader = PostProcessVS;
		PixelShader = GI_TAA;
	}
		pass AccumilateFrames
	{
		VertexShader = PostProcessVS;
		PixelShader = AccumulatedFramesGI;
		RenderTarget0 = PBGIaccuTex;
	}
}

technique PBGI_Two
< toggle = 0x23;
ui_tooltip = "Beta: Disk-to-Disk Global Illumination Secondary Output.²"; >
{
		pass Bilateral_Gaussian_Upscaling
	{
		VertexShader = PostProcessVS;
		PixelShader = BGU_Hoz;
		RenderTarget = PBGIhorizontalTex;
	}
		pass Done
	{
		VertexShader = PostProcessVS;
		PixelShader = Out;
	}
}
