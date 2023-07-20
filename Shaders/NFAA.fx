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
    ui_tooltip = "If NFAA misses some edges try lowering this slightly.\n"
				 "Default is 0.063";
    ui_min = 0.050; ui_max = 0.200;
> = 0.100;

uniform float SearchWidth < __UNIFORM_DRAG_FLOAT1
    ui_label = "Search Width";
    ui_tooltip = "Determines the radius NFAA will search for edges.\n"
                 "Default is 1.000";
    ui_min = 0.500; ui_max = 1.500;
> = 1.000;

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

float2 Rotate(float2 p, float angle) {
	return float2(p.x * cos(angle) - p.y * sin(angle), p.x * sin(angle) + p.y * cos(angle));
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


    // Find Edges
	// Enhanced edge detection with linear sampling
	//  +---+---+---+---+---+
	//  |   |   | x | x |   |
	//  +---+---+--(t)--+---+
	//  | x | x | x | x |   |
	//  +--(l)--+---+---+---+
	//  | x | x | C | x | x |
	//  +---+---+---+--(r)--+
	//  |   | x | x | x | x |
	//  +---+--(b)--+---+---+
	//  |   | x | x |   |   |
	//  +---+---+---+---+---+
	float angle = atan(0.5 / SW);
    float4 color = GetBB(texcoord);
	float4 ts = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(0.5, -SW), BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
	float4 rs = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(SW, 0.5), BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
	float4 bs = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(-0.5, SW), BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
	float4 ls = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(-SW, 0.5), BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
    
	// float t, l, r, b;
	// float2 UV = texcoord.xy;
	// float2 SS = SearchWidth * BUFFER_PIXEL_SIZE;
    // t = LI(GetBB(float2(UV.x, UV.y - SS.y)).rgb);
    // b = LI(GetBB(float2(UV.x, UV.y + SS.y)).rgb);
    // l = LI(GetBB(float2(UV.x - SS.x, UV.y)).rgb);
    // r = LI(GetBB(float2(UV.x + SS.x, UV.y)).rgb);
	
	float t = LI(ts.rgb);
    float r = LI(rs.rgb);
    float b = LI(bs.rgb);
    float l = LI(ls.rgb);
    
	float2 n = float2(t - b, r - l);
	float nl = length(n);
    
	float mask = 1.0;
    if (nl >= EDT)
	{
		// Lets make that mask for a sharper image.
		// Mask Formula: 1.0 - 5.0 * nl.
		// Mask is 0 if nl >= 0.20.
		mask = saturate(mad(nl, -5.0, 1.0));


		// y = -0.5*x; nx = 1; ny = 0.25; nl = 1.031; SW = 1.5; angle = 18.435 deg;
		// m' = - 1/7
		// +---+---+---+---+---+
		// |   |   | 1 | 1 |   |
		// +---+---+--(t)--+---+
		// |\\\| 1 | 1 | 1 |   |
		// +--(l)--+---+---+---+
		// | 0 |\\\|\\\| 1 | 1 |
		// +---+---+---+--(r)--+
		// |   | 0 | 0 |\\\|\\\|
		// +---+--(b)--+---+---+
		// |   | 0 | 0 |   |   |
		// +---+---+---+---+---+
		
		// y = 0.5*x; nx = 0.875; ny = -0.875; nl = 1.237
		// m' = 1
		// +---+---+---+---+---+
		// |   |   | 1 | 1 |   |
		// +---+---+--(t)--+---+
		// | 1 | 1 | 1 |\\\|\\\|
		// +--(l)--+---+---+---+
		// | 1 |\\\|\\\| 0 | 0 |
		// +---+---+---+--(r)--+
		// |\\\| 0 | 0 | 0 | 0 |
		// +---+--(b)--+---+---+
		// |   | 0 | 0 |   |   |
		// +---+---+---+---+---+

		// y = -2x; nx = 0.875; ny = 0.875;
		// m' = -1;
		// +---+---+---+---+---+
		// |   |\\\| 1 | 1 |   |
		// +---+---+--(t)--+---+
		// | 0 |\\\| 1 | 1 |   |
		// +--(l)--+---+---+---+
		// | 0 | 0 |\\\| 1 | 1 |
		// +---+---+---+--(r)--+
		// |   | 0 |\\\| 1 | 1 |
		// +---+--(b)--+---+---+
		// |   | 0 | 0 |\\\|   |
		// +---+---+---+---+---+

		// y = 2x; nx = 0.25; ny = -1.0;
		// m' = 7;
		// +---+---+---+---+---+
		// |   |   | 1 |\\\|   |
		// +---+---+--(t)--+---+
		// | 1 | 1 | 1 |\\\|   |
		// +--(l)--+---+---+---+
		// | 1 | 1 |\\\| 0 | 0 |
		// +---+---+---+--(r)--+
		// |   | 1 |\\\| 0 | 0 |
		// +---+--(b)--+---+---+
		// |   |\\\| 0 |   |   |
		// +---+---+---+---+---+

		// y = -3x; nx = 0.75; ny = 0.875;
		// m' = -4/3; 
		// +---+---+---+---+---+
		// |   |\\\| 1 | 1 |   |
		// +---+---+--(t)--+---+
		// | 0 |\\\| 1 | 1 |   |
		// +--(l)--+---+---+---+
		// | 0 | 0 |\\\| 1 | 1 |
		// +---+---+---+--(r)--+
		// |   | 0 |\\\| 1 | 1 |
		// +---+--(b)--+---+---+
		// |   | 0 |\\\|   |   |
		// +---+---+---+---+---+

		// estimate slope
		float mp = (n.x != 0.0) ? -n.y / n.x : 1000.0;
		// rotate axis and recalc slope
		float2 p0 = Rotate(float2(1.0, mp), -angle);
		float m = (p0.x != 0.0) ? p0.y / p0.x : 1000.0;

        if (DebugOutput == 3) nl *= 2.0; // Fake DLSS

		// calculate x/y coordinates on this slope at specified distance to origin
		// parallel
		float2 d0, d1, d2;
		d0.x = sqrt(1.0 / (1 + m*m));
		d0.y = m * d0.x;

		d1.x = sqrt(0.25 / (1 + m*m));
		d1.y = m * d1.x;

		// perpendicular
		m = -rcp(m);
		d2.x = sqrt(1.0 / (1 + m*m));
		d2.y = m * d0.x;

        float4 t0 = 0.3 * tex2Dlod(ReShade::BackBuffer, float4(mad(d0, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
		float4 t1 = 0.3 * tex2Dlod(ReShade::BackBuffer, float4(mad(-d0, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
		float4 t2 = 0.7 * tex2Dlod(ReShade::BackBuffer, float4(mad(d1, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
		float4 t3 = 0.7 * tex2Dlod(ReShade::BackBuffer, float4(mad(-d1, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
		float4 t4 = 0.5 * tex2Dlod(ReShade::BackBuffer, float4(mad(d2, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
		float4 t5 = 0.5 * tex2Dlod(ReShade::BackBuffer, float4(mad(-d2, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
		color = lerp((color + t0 + t1 + t2 + t3 + t4 + t5) / 4, color, mask);
    }

	// DebugOutput
    if(DebugOutput == 1)
    {
        color.rgb = mask;
    }
    else if (DebugOutput == 2)
    {
        color.rgb = float3(mad(Rotate(n.yx, -angle), 0.5, 0.5), 1.0);
    }

	return color;
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
