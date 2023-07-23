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
    ui_tooltip = "The radius to search for edges.\n"
				 "Try lowering this if short edges are not blurred.\n"
				 "Try raising this if using in-game upscaling.\n"
                 "Default is 1.000";
    ui_min = 0.500; ui_max = 4.000;
> = 1.000;

uniform float BlurStrength < __UNIFORM_DRAG_FLOAT1
    ui_label = "Blur Strength";
    ui_tooltip = "Darkens Edge Mask for filtering edge blur strength.\n"
				 "Try raising this if edges are still too aliased.\n"
				 "Try lowering this if text or icons become blurry.\n"
                 "Default is 1.000";
    ui_min = 0.000; ui_max = 2.000;
> = 1.000;

uniform float BlurSize < __UNIFORM_DRAG_FLOAT1
    ui_label = "Blur Size";
    ui_tooltip = "Sets Normal Map depth for larger edge blur length.\n"
				 "Try raising this if edges are still too aliased.\n"
				 "Try lowering this if text or icons become blurry.\n"
                 "Default is 1.000";
    ui_min = 0.000; ui_max = 2.000;
> = 1.000;

uniform int DebugOutput < __UNIFORM_COMBO_INT1
    ui_label = "Debug Output";
    ui_items = "None\0Edge Mask View\0Normal Map View\0";
    ui_tooltip = "Edge Mask View gives you a view of the Edge Detection and Blur Strength.\n"
                 "Normal Map View gives you a view of the Normal Map creation, Blur Size, and Blur Direction.";
> = 0;

////////////////////////////////////////////////////////////Variables////////////////////////////////////////////////////////////////////

// sRGB Luminance
static const float3 LinearizeVector[4] = { float3(0.2126, 0.7152, 0.0722), float3(0.299, 0.587, 0.114), float3(1.0, 1.0, 1.0), float3(0.508, 1.0, 0.195) };

static const float cos45 = 0.70710678118654752440084436210485;

////////////////////////////////////////////////////////////Functions////////////////////////////////////////////////////////////////////

float signF(float n) {
	// sign intrinsic can return 0, which we don't want.
	return n < 0.0 ? -1.0 : 1.0;
}

float LinearDifference(float3 A, float3 B)
{
	float lumDiff = dot(A, LinearizeVector[EdgeDetectionType]) - dot(B, LinearizeVector[EdgeDetectionType]);
	if (EdgeDetectionType < 2)
    	return lumDiff;
	
	// color detection is a bit more expensive, so luminance is default
	else if (EdgeDetectionType == 2)
	{
		float3 C = abs(A - B);
		return max(max(C.r, C.g), C.b) * signF(lumDiff);
	}
	else { // if (EdgeDetectionType == 3)
		float3 C = abs(A - B) * LinearizeVector[EdgeDetectionType];
		return max(max(C.r, C.g), C.b) * signF(lumDiff);
	}
}

float2 Rotate45(float2 p) {
	return float2(p.x * cos45 - p.y * cos45, p.x * cos45 + p.y * cos45);
}

////////////////////////////////////////////////////////////NFAA////////////////////////////////////////////////////////////////////

float4 NFAA(float2 texcoord, float4 offsets[4])
{
	// Find Edges
	//  +---+---+---+---+---+
	//  |   |   |   |   |   |
	//  +---+---+---+---+---+
	//  |   | e | f | g |   |
	//  +---+--(a)-(b)--+---+
	//  |   | h | P | i |   |
	//  +---+--(c)-(d)--+---+
	//  |   | j | k | l |   |
	//  +---+---+---+---+---+
	//  |   |   |   |   |   |
	//  +---+---+---+---+---+
	// Much better at horizontal/vertical lines, slightly better diagonals, always compares 6 pixels, not 2.
	float3 a = tex2Dlod(ReShade::BackBuffer, offsets[0]).rgb;
	float3 b = tex2Dlod(ReShade::BackBuffer, offsets[1]).rgb;
	float3 c = tex2Dlod(ReShade::BackBuffer, offsets[2]).rgb;
	float3 d = tex2Dlod(ReShade::BackBuffer, offsets[3]).rgb;

	// Original edge detection from b34r & BlueSkyDefender
	//  +---+---+---+---+---+
	//  |   |   |   |   |   |
	//  +---+---+---+---+---+
	//  |   |   | t |   |   |
	//  +---+---+---+---+---+
	//  |   | l | C | r |   |
	//  +---+---+---+---+---+
	//  |   |   | b |   |   |
	//  +---+---+---+---+---+
	//  |   |   |   |   |   |
	//  +---+---+---+---+---+
	// float angle = 0.0;
	// float3 t = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(0.0, -SearchWidth), BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0)).rgb;
	// float3 b = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(-0.0, SearchWidth), BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0)).rgb;
	// float3 r = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(SearchWidth, 0.0), BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0)).rgb;
	// float3 l = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(-SearchWidth, 0.0), BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0)).rgb;

	float4 color = tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0.0, 0.0));
	
	// Normal Depth
	// float2 n = float2(LinearDifference(t, b), LinearDifference(r, l));

	// top vs bottom = 	a + b - c - d = 	(e + 2*f + g) / 4 - (j + 2*k + l) / 4
	// TL vs BR = 		4/3 * (a - d) = 	(h + e + f) / 3 - (k + l + i) / 3
	float4 n;
	n.x = LinearDifference(b + d, a + c); // right - left
	n.y = LinearDifference(c + d, a + b); // bottom - top
	n.z = 1.3333333 * LinearDifference(d, a); // bottom-right - top-left
	n.w = 1.3333333 * LinearDifference(c, b); // bottom-left - top-right
    
	float2 nLength = float2(length(n.xy), length(n.zw));
	
	float3 normalMap = float3(0.5, 0.5, 1.0);
	float edgeMask = 1.0;

	float2 normal;
	float edge;
	if (nLength.y > nLength.x) {
		normal = Rotate45(n.zw);
		edge = nLength.y;
	}
	else {
		normal = n.xy;
		edge = nLength.x;
	}

    if (edge >= EdgeDetectionThreshold)
	{
		// Lets make that edgeMask for a sharper image.
		// Mask Formula: 1.0 - 5.0 * edge.
		edgeMask = saturate(mad(edge, -5.0 * BlurStrength, 1.0));
		// Normal map, right = red, green = top
		normalMap.rg = mad(float2(-normal.r, normal.g) * BlurSize, 0.5, 0.5);

		// calculate x/y coordinates on the line at specified distances and offsets
		// +---+---+---+---+---+ +---+---+---+---+---+
		// |   |   |   |   |   | |   |   |   |   |   |
		// +---+---+---+---+---+ +---+---+---+---+---+
		// |   |   |   |   |   | |   |   | (e)   |   |
		// +---+(g)a---b(e)+---+ +---+---a---b(f)+---+
		// |   |-O | P | O |   | |   |   | P |   |   |
		// +---+(h)c---d(f)+---+ +---+(g)c---d---+---+
		// |   |   |   |   |   | |   |   (h) |   |   |
		// +---+---+---+---+---+ +---+---+---+---+---+
		// |   |   |   |   |   | |   |   |   |   |   |
		// +---+---+---+---+---+ +---+---+---+---+---+

		// slope m = normal.r / normal.g
		// distance d = 1
		// y = mx
		// d^2 = y^2 + x^2 = (mx)^2+x^2
		// d^2 = x^2(1 + m^2)
		// x^2 = d^2/(1 + m^2)

		float4 offset;
		float m = normal.g != 0 ? normal.r / normal.g : 1024.0;
		offset.x = sqrt(BlurSize * BlurSize / (1.0 + m * m));
		offset.y = m * offset.x;
		m = normal.r != 0 ? -normal.g / normal.r : 1024.0;
		offset.z = sqrt(0.25 * BlurSize * BlurSize / (1.0 + m * m));
		offset.w = m * offset.z;

        float3 e = tex2Dlod(ReShade::BackBuffer, float4(mad(offset.xy + offset.zw, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0)).rgb;
        float3 f = tex2Dlod(ReShade::BackBuffer, float4(mad(offset.xy - offset.zw, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0)).rgb;
        float3 g = tex2Dlod(ReShade::BackBuffer, float4(mad(-offset.xy + offset.zw, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0)).rgb;
		float3 h = tex2Dlod(ReShade::BackBuffer, float4(mad(-offset.xy - offset.zw, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0)).rgb;

		// possible to reduce taps by re-using edge detection taps a, b, c, d
		// but its not worth it, nearby pixels should already be cached, and needs more math

		color.rgb = lerp(mad(e + f + g + h, 0.125 * BlurStrength, color.rgb * 0.5 * (2.0 - BlurStrength)), color.rgb, edgeMask);

		// original blur from b34r & BlueSkyDefender
		// may need some work to be functional again due to some variable name refactoring I reversed how/why it worked - Eric B.
		// +---+---+---+---+---+
		// |   |   |   |   |   |
		// +---+---+---+---+---+
		// |\\\|   | x | x |   |
		// +---+---+---+---+---+
		// |   |\\\|\\\| x |   |
		// +---+---+---+---+---+
		// |   |   | x |\\\|\\\|
		// +---+---+---+---+---+
		// |   |   |   |   |   |
		// +---+---+---+---+---+
		// y = -0.5x; n.x = 1; n.y = 0.5; nl = 1.18; dn.x = 0.85; dn.y = 0.42;
		// t0/1 = 0.425, 0.21; d ~= 0.5
		// t2/3 = 0.765, -0.38; d ~= 0.85
		// float2 dn = n / nl * BlurSize;
		// float4 t0 = tex2Dlod(ReShade::BackBuffer, float4(mad(-dn * 0.5, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
		// float4 t1 = tex2Dlod(ReShade::BackBuffer, float4(mad(dn * 0.5, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
		// float4 t2 = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(dn.x, -dn.y) * 0.9, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
		// float4 t3 = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(-dn.x, dn.y) * 0.9, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
		// color = lerp(mad(color, 0.23, 0.175 * (t2 + t3) + 0.21 * (t0 + t1)), color, edgeMask);
    }

    if(DebugOutput == 1)
    {
        color.rgb = edgeMask;
    }
    else if (DebugOutput == 2)
    {
        color.rgb = normalMap;
    }

	return color;
}

void NFAA_VS(in uint id : SV_VertexID, out float4 position : SV_POSITION, out float2 texcoord : TEXCOORD, out float4 offsets[4] : OFFSETS )
{
    PostProcessVS(id, position, texcoord);
	offsets[0] = float4(mad(float2(-1.0, -1.0) * BUFFER_PIXEL_SIZE, SearchWidth, texcoord), 0.0, 0.0);
	offsets[1] = float4(mad(float2(1.0, -1.0) * BUFFER_PIXEL_SIZE, SearchWidth, texcoord), 0.0, 0.0);
	offsets[2] = float4(mad(float2(-1.0, 1.0) * BUFFER_PIXEL_SIZE, SearchWidth, texcoord), 0.0, 0.0);
	offsets[3] = float4(mad(float2(1.0, 1.0) * BUFFER_PIXEL_SIZE, SearchWidth, texcoord), 0.0, 0.0);
}

float4 NFAA_PS(in float4 position : SV_Position, in float2 texcoord : TEXCOORD, in float4 offsets[4] : OFFSETS) : SV_Target
{
	return NFAA(texcoord, offsets);
}

technique NFAA
{
		pass NFAA_Fast
        {
            VertexShader = NFAA_VS;
            PixelShader = NFAA_PS;
        }
}
