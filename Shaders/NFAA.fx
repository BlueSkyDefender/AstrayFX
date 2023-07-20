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
	ui_items = "Luminance edge detection\0Perceived Luminance edge detection\0Color edge detection\0Perceived Color edge detection\0";
	ui_label = "Edge Detection Type";
> = 1;

uniform float EdgeDetectionThreshold < __UNIFORM_DRAG_FLOAT1
	ui_label = "Edge Detection Threshold";
    ui_tooltip = "If NFAA misses some edges try lowering this slightly.\n"
				 "Default is 0.100";
    ui_min = 0.000; ui_max = 0.200;
> = 0.100;

uniform float SearchWidth < __UNIFORM_DRAG_FLOAT1
    ui_label = "Search Radius";
    ui_tooltip = "The radius to search for edges and normal mask depth.\n"
				 "Large values may cause text smearing or loss of detail near edges.\n"
                 "Default is 1.000";
    ui_min = 0.000; ui_max = 4.000;
> = 1.000;

uniform float BlurStrength < __UNIFORM_DRAG_FLOAT1
    ui_label = "Blur Strength";
    ui_tooltip = "The size of the edge bluring with normal map direction bias.\n"
				 "If set to 0, blurring is not disabled, but it minimizes normal map bias.\n"
				 "Large values may cause text smearing or loss of detail near edges.\n"
                 "Default is 1.000";
    ui_min = 0.000; ui_max = 2.000;
> = 1.000;

uniform int DebugOutput < __UNIFORM_COMBO_INT1
    ui_label = "Debug Output";
    ui_items = "None\0Edge Mask View\0Normal Mask View\0";
    ui_tooltip = "Edge Mask View gives you a view of the edge detection.\n"
                 "Normal Mask View gives you an view of the normals created.";
> = 0;

//Total amount of frames since the game started.
uniform uint framecount < source = "framecount"; >;

////////////////////////////////////////////////////////////NFAA////////////////////////////////////////////////////////////////////
float signF(float n) {
	// sign intrinsic can return 0, which we don't want.
	return n < 0.0 ? -1.0 : 1.0;
}

// sRGB Luminance
static const float3 LinearizeVector[4] = { float3(0.2126, 0.7152, 0.0722), float3(0.299, 0.587, 0.114), float3(1.0, 1.0, 1.0), float3(0.299, 0.587, 0.114) };

float LinearDifference(float3 A, float3 B)
{
	float lumDiff = dot(A, LinearizeVector[EdgeDetectionType]) - dot(B, LinearizeVector[EdgeDetectionType]);
	if (EdgeDetectionType < 2)
    	return lumDiff;
	
	else if (EdgeDetectionType == 2)
	{
		float3 C = abs(A - B);
		return max(max(C.r, C.g), C.b) * signF(lumDiff);
	}
	
	else // if (EdgeDetectionType == 3)
		return dot(abs(A - B), LinearizeVector[EdgeDetectionType]) * signF(lumDiff);
}

float2 Rotate(float2 p, float angle) {
	return float2(p.x * cos(angle) - p.y * sin(angle), p.x * sin(angle) + p.y * cos(angle));
}

float4 NFAA(float2 texcoord)
{
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
	float angle = atan(0.5 / SearchWidth);
	float4 color = tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0.0, 0.0));
	float3 t = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(0.5, -SearchWidth), BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0)).rgb;
	float3 b = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(-0.5, SearchWidth), BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0)).rgb;
	float3 r = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(SearchWidth, 0.5), BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0)).rgb;
	float3 l = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(-SearchWidth, 0.5), BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0)).rgb;

	float4 e = float4(LinearDifference(t, color.rgb), LinearDifference(l, color.rgb), LinearDifference(b, color.rgb), LinearDifference(r, color.rgb));
	float el = max(length(e.xy), length(e.zw));
	
	float2 n = float2(LinearDifference(t, b), LinearDifference(r, l));
	float nl = length(n);
    
	float edgeMask = 1.0;
	float3 normalMask = float3(0.5, 0.5, 1.0);
    if (el >= EdgeDetectionThreshold)
	{
		// Lets make that edgeMask for a sharper image.
		// Mask Formula: 1.0 - 2.5 * el.
		// Mask is 0 if el >= 0.50.
		edgeMask = saturate(mad(el, -2.5, 1.0));
		normalMask.rg = mad(Rotate(-n.yx, -angle), 0.5, 0.5);

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

		// calculate x/y coordinates on this slope at specified distance to origin
		// +---+---+---+---+---+ +---+---+---+---+---+ +---+---+---+---+---+
		// |   |   |   |   |   | |\\\|   |   |   |   | |   |   | 1 | 1 |///|
		// +---+---+---+---+---+ +--(1)--+---+---+---+ +---+---+--(2)--+---+
		// | 1 | 1 | 1 | 1 |   | |   |-d |   |   |   | |   |   | 1 | d | 0 |
		// +--(1)--+--(2)--+---+ +---+--(3)--+---+---+ +---+---+---+--(0)--+
		// |\\\|-d |\\\| d |\\\| |   |   |\\\|   |   | | 1 | 1 |///| 0 | 0 |
		// +---+--(3)--+--(0)--+ +---+---+--(2)--+---+ +--(1)--+---+---+---+
		// |   | 0 | 0 | 0 | 0 | |   |   |   | d |   | | 1 |-d | 0 |   |   |
		// +---+---+---+---+---+ +---+---+---+--(0)--+ +---+--(3)--+---+---+
		// |   |   |   |   |   | |   |   |   |   |\\\| |///| 0 | 0 |   |   |
		// +---+---+---+---+---+ +---+---+---+---+---+ +---+---+---+---+---+
		
		float d = 1.333333 * nl * BlurStrength;
		float2 d0;
		d0.x = sqrt(d*d / (1 + m*m));
		d0.y = m * d0.x;
		d0 += 0.5;

        float4 t0 = 0.175 * tex2Dlod(ReShade::BackBuffer, float4(mad(d0, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
		float4 t1 = 0.175 * tex2Dlod(ReShade::BackBuffer, float4(mad(-d0, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
		float4 t2 = 0.175 * tex2Dlod(ReShade::BackBuffer, float4(mad(d0 - 1.0, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
		float4 t3 = 0.175 * tex2Dlod(ReShade::BackBuffer, float4(mad(-d0 + 1.0, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
		color = lerp(mad(color, 0.3, t0 + t1 + t2 + t3), color, edgeMask);
    }

	// DebugOutput
    if(DebugOutput == 1)
    {
        color.rgb = edgeMask;
    }
    else if (DebugOutput == 2)
    {
        color.rgb = normalMask;
    }

	return color;
}

float4 Out(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	return NFAA(texcoord);
}

//*Rendering passes*//
technique NFAA
{
		pass NFAA_Fast
        {
            VertexShader = PostProcessVS;
            PixelShader = Out;
        }
}
