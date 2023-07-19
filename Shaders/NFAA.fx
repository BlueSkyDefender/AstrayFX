 ////-------------//
 ///**NFAA Fast**///
 //-------------////

 //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
 //* Normal Filter Anti Aliasing.
 //* For ReShade 3.0+ & Freestyle
 //*  ---------------------------------
 //*                                                                          NFAA
 //* Due Diligence
 //* Based on port by b34r
 //* https://www.gamedev.net/forums/topic/580517-nfaa---a-post-process-anti-aliasing-filter-results-implementation-details/?page=2
 //* If I missed any please tell me.
 //*
 //* LICENSE
 //* ============
 //* Normal Filter Anti Aliasing is licenses under: Attribution-NoDerivatives 4.0 International
 //*
 //* You are free to:
 //* Share - copy and redistribute the material in any medium or format
 //* for any purpose, even commercially.
 //* The licensor cannot revoke these freedoms as long as you follow the license terms.
 //* Under the following terms:
 //* Attribution - You must give appropriate credit, provide a link to the license, and indicate if changes were made.
 //* You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.
 //*
 //* NoDerivatives - If you remix, transform, or build upon the material, you may not distribute the modified material.
 //*
 //* No additional restrictions - You may not apply legal terms or technological measures that legally restrict others from doing anything the license permits.
 //*
 //* https://creativecommons.org/licenses/by-nd/4.0/
 //*
 //* Have fun,
 //* Jose Negrete AKA BlueSkyDefender
 //*
 //* https://github.com/BlueSkyDefender/Depth3D
 //*
 //* Have fun,
 //* Jose Negrete AKA BlueSkyDefender
 //*
 //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include "ReShadeUI.fxh"
#include "ReShade.fxh"

uniform int EdgeDetectionType < __UNIFORM_COMBO_INT1
	ui_items = "Luminance edge detection\0Perceived Luminance edge detection\0";
	ui_label = "Edge Detection Type";
> = 1;

uniform float EdgeDetectionThreshold < __UNIFORM_DRAG_FLOAT1
	ui_label = "Edge Detection Threshold";
    ui_tooltip = "If NFAA misses some edges try lowering this.\n"
				 "Default is 0.063";
    ui_min = 0.005; ui_max = 0.1;
> = 0.005;

uniform float SearchWidth < __UNIFORM_DRAG_FLOAT1
    ui_label = "Search Width";
    ui_tooltip = "Determines the radius NFAA will search for edges.\n"
                 "Default is 1.500";
    ui_min = 0.5; ui_max = 4.5;
> = 1.500;

uniform int DebugOutput < __UNIFORM_COMBO_INT1
    ui_label = "Debug Output";
    ui_items = "None\0Edge Mask View\0Normal View\0Fake DLSS\0";
    ui_tooltip = "Edge Mask View gives you a view of the edge detection.\n"
                 "Normal View gives you an view of the normals created.\n"
                 "Fake DLSS is NV_AI_DLSS Parody experiance..........";
> = 0;

//Total amount of frames since the game started.
uniform uint framecount < source = "framecount"; >;

////////////////////////////////////////////////////////////NFAA////////////////////////////////////////////////////////////////////
// sRGB Luminance
static const float3 LuminanceVector[2] = {float3(0.2126, 0.7152, 0.0722), float3(0.299, 0.587, 0.114)};

float LI(in float3 color)
{
    return dot(color.rgb, LuminanceVector[EdgeDetectionType]);
}

float4 GetBB(float2 texcoord : TEXCOORD)
{
    return tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0.0, 0.0));
}

float4 NFAA(float2 texcoord)
{
    float SW = SearchWidth;
    float EDT = EdgeDetectionThreshold;
    
	if (DebugOutput == 3) // Fake DLSS
	{
        SW = 4.5;
        EDT = 0.005;
    }

	float2 SS = SearchWidth * BUFFER_PIXEL_SIZE;

    // Find Edges
	// Enhanced edge detection with linear sampling
	//  +---+---+---+---+---+
	//  |   |   | a | b |   |
	//  +---+---+---x---+---+
	//  | m | n | c | d |   |
	//  +---x---+---+---+---+
	//  | o | p |   | e | f |
	//  +---+---+---+---x---+
	//  |   | i | j | g | h |
	//  +---+---x---+---+---+
	//  |   | k | l |   |   |
	//  +---+---+---+---+---+
	float4 ts, ls, rs, bs;
	ts = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(0.5, -SW), BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
	rs = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(SW, 0.5), BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
	bs = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(-0.5, SW), BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
	ls = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(-SW, 0.5), BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
    
	float t, l, r, b;
	float2 UV = texcoord.xy;
    t = LI(GetBB(float2(UV.x, UV.y - SS.y)).rgb);
    b = LI(GetBB(float2(UV.x, UV.y + SS.y)).rgb);
    l = LI(GetBB(float2(UV.x - SS.x, UV.y)).rgb);
    r = LI(GetBB(float2(UV.x + SS.x, UV.y)).rgb);
    float2 n = float2(t - b, r - l);
	
	// float t, l, r, b;
	// t = LI(ts.rgb);
    // b = LI(bs.rgb);
    // l = LI(ls.rgb);
    // r = LI(rs.rgb);
    // float2 n = float2(t - b, r - l);
	float nl = length(n);
    
	float Mask = 1.0;
    float4 Color = GetBB(texcoord);
    if (nl >= EDT)
	{
		// Lets make that mask for a sharper image.
		// Mask Formula: 1.0 - 10.0 * nl.
		// Mask is 0 if nl >= 0.1.
		Mask = saturate(mad(nl, -10.0, 1.0));

        SS = BUFFER_PIXEL_SIZE * n / nl;
        if (DebugOutput == 3) SS *= 2.0; // Fake DLSS
	
		//  +---+---+---+---+---+
		//  |\\\|   | a | b |   |
		//  +---+---+---x---+---+
		//  | m |\\\| c | d |   |
		//  +---x---+---+---+---+
		//  | o | p |\\\| e | f |
		//  +---+---+---+---x---+
		//  |   | i | j |\\\| h |
		//  +---+---x---+---+---+
		//  |   | k | l |   |\\\|
		//  +---+---+---+---+---+
        ts = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(0.7, -2.1), SS, texcoord), 0.0, 0.0)) * 0.75;
		rs = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(2.1, 0.7), SS, texcoord), 0.0, 0.0)) * 0.9;
		bs = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(-0.7, 2.1), SS, texcoord), 0.0, 0.0)) * 0.75;
		ls = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(-2.1, -0.7), SS, texcoord), 0.0, 0.0)) * 0.9;

		Color = lerp((Color + ts + rs + bs + ls) / 4.3, Color, Mask);
    }

	// DebugOutput
    if(DebugOutput == 1)
    {
        Color.rgb = Mask;
    }
    else if (DebugOutput == 2)
    {
        Color.rgb = float3(mad(n.yx, 0.5, 0.5), 1.0);
    }

	return Color;
}

float4 Out(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	return NFAA(texcoord);
}

//*Rendering passes*//
technique Normal_Filter_Anti_Aliasing
{
		pass NFAA_Fast
        {
            VertexShader = PostProcessVS;
            PixelShader = Out;
        }
}
