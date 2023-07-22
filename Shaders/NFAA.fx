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
				 "Default is 0.050";
    ui_min = 0.000; ui_max = 0.200;
> = 0.050;

uniform float SearchWidth < __UNIFORM_DRAG_FLOAT1
    ui_label = "Search Radius";
    ui_tooltip = "The radius to search for edges.\n"
				 "Try raising this if using in-game upscaling.\n"
                 "Default is 1.000";
    ui_min = 0.000; ui_max = 4.000;
> = 1.000;

uniform float BlurStrength < __UNIFORM_DRAG_FLOAT1
    ui_label = "Blur Strength";
    ui_tooltip = "Darkens Edge Mask for filtering edge blur strength.\n"
				"Try raising this if edges are still too aliased.\n"
                 "Default is 1.000";
    ui_min = 0.000; ui_max = 2.000;
> = 1.000;

uniform float BlurSize < __UNIFORM_DRAG_FLOAT1
    ui_label = "Blur Size";
    ui_tooltip = "Sets Normal Map depth for larger edge blur length.\n"
				 "Try lowering this if text or icons become blurry.\n"
                 "Default is 1.000";
    ui_min = 0.000; ui_max = 2.000;
> = 1.000;

uniform int DebugOutput < __UNIFORM_COMBO_INT1
    ui_label = "Debug Output";
    ui_items = "None\0Edge Mask View\0Normal Map View\0";
    ui_tooltip = "Edge Mask View gives you a view of the edge detection.\n"
                 "Normal Map View gives you an view of the normals created.";
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

	// linear sampling for improved edge detection - worse at detecting jagged edges
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
	// float angle = atan(0.5 / SearchWidth);
	// float3 t = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(0.5, -SearchWidth), BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0)).rgb;
	// float3 b = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(-0.5, SearchWidth), BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0)).rgb;
	// float3 r = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(SearchWidth, 0.5), BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0)).rgb;
	// float3 l = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(-SearchWidth, -0.5), BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0)).rgb;

	//  +---+---+---+---+---+
	//  |   |   |   |   |   |
	//  +---+---+---+---+---+
	//  |   | x | x | x |   |
	//  +---+---l---t---+---+
	//  |   | x | C | x |   |
	//  +---+---b---r---+---+
	//  |   | x | x | x |   |
	//  +---+---+---+---+---+
	//  |   |   |   |   |   |
	//  +---+---+---+---+---+
	float angle = 0.0; //radians(45.0);
	float2 SW = 0.5 * SearchWidth * BUFFER_PIXEL_SIZE;
	float3 t = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(1.0, -1.0), SW, texcoord), 0.0, 0.0)).rgb;
	float3 b = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(-1.0, 1.0), SW, texcoord), 0.0, 0.0)).rgb;
	float3 r = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(1.0, 1.0), SW, texcoord), 0.0, 0.0)).rgb;
	float3 l = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(-1.0, -1.0), SW, texcoord), 0.0, 0.0)).rgb;

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
	
	// we can skip this tap by averaging diagonal taps and using discard and alpha channel blending
	// float4 color = float4((t + b + r + l) / 4.0, 1.0);
	float4 color = tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0.0, 0.0));
	
	// Normal Depth
	// float2 n = float2(LinearDifference(t, b), LinearDifference(r, l));
	float3 tn = t + l - color.rgb * max(2 - SearchWidth, 0);
	float3 bn = b + r - color.rgb * max(2 - SearchWidth, 0);
	float3 rn = r + t - color.rgb * max(2 - SearchWidth, 0);
	float3 ln = l + b - color.rgb * max(2 - SearchWidth, 0);
	float2 n = float2(LinearDifference(tn, bn), LinearDifference(rn, ln));
	float nl = length(n);
    
	float edgeMask = 1.0;
	float3 normalMap = float3(0.5, 0.5, 1.0);
    if (nl >= EdgeDetectionThreshold)
	{
		// Lets make that edgeMask for a sharper image.
		// Mask Formula: 1.0 - BlurStrength * nl.
		edgeMask = saturate(mad(nl, -10.0 * BlurStrength, 1.0));
		// normalMap.rg = mad(-n.yx * BlurSize, 0.5, 0.5);
		normalMap.rg = mad(Rotate(-n.yx, -angle) * BlurSize, 0.5, 0.5);

		// // estimate slope on rotated coordinates
		// float mp = (n.x != 0.0) ? -n.y / n.x : 1000.0;
		// // rotate axis and recalc slope relative to the new coordinate system
		// float2 p0 = Rotate(float2(1.0, mp), -angle);
		// float m = (p0.x != 0.0) ? p0.y / p0.x : 1000.0;


		// calculate x/y coordinates on this slope at specified distance
		// +---+---+---+---+---+
		// |   |   |   |   |   |
		// +---+---+---+---+---+
		// |   |   |   |(1)|   |
		// +---+---+---+---+---+
		// |\\\|-d |\\\|(0)|\\\|
		// +---+---+---+---+---+
		// |   |   |   |(2)|   |
		// +---+---+---+---+---+
		// |   |   |   |   |   |
		// +---+---+---+---+---+
		
		// float m = (n.x != 0.0) ? -n.y / n.x : 1000.0;
		// float d = dot(n, float2(signF(n.x), signF(n.y))) / nl * 0.5 * BlurSize;
		// float2 d0, d1, d2;
		// d0.x = sqrt(d*d / (1 + m*m));
		// d0.y = m * d0.x;

		// d *= 2.0;
		// m = -m;
		// d1.x = sqrt(d*d / (1 + m*m));
		// d1.y = m * d1.x;

		// m = -rcp(m);
		// d2.x = sqrt(d*d / (1 + m*m));
		// d2.y = m * d2.x;

        // float4 t0 = tex2Dlod(ReShade::BackBuffer, float4(mad(d0, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
		// float4 t1 = tex2Dlod(ReShade::BackBuffer, float4(mad(-d0, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
		// float4 t2 = tex2Dlod(ReShade::BackBuffer, float4(mad(d1, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
		// float4 t3 = tex2Dlod(ReShade::BackBuffer, float4(mad(-d1, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
		// float4 t4 = tex2Dlod(ReShade::BackBuffer, float4(mad(d2, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
		// float4 t5 = tex2Dlod(ReShade::BackBuffer, float4(mad(-d2, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
		// color = lerp(mad(color, 0.2222222, mad(t0 + t1, 0.1666667, 0.1111111 * (t2 + t3 + t4 + t5))), color, edgeMask);
		
		// +---+---+---+---+---+
		// |   |   |   |   |   |
		// +---+---+---+---+---+
		// |\\\| 1 | 1 | 1 |   |
		// +---+---l---t---+---+
		// |   |\\\|\\\| 1 |   |
		// +---+---b---r---+---+
		// |   | 0 | 0 |\\\|\\\|
		// +---+---+---+---+---+
		// |   |   |   |   |   |
		// +---+---+---+---+---+
		// float2 dn = Rotate(n, -angle) / nl * BlurSize;
		// y = -0.5x; n.x = 2.5/6; n.y = 1/6; nl = 0.4487; dn.x = 0.928; dn.y = 0.371;
		// t0/1 = 0.464, 0.186;
		// t2/3 = 0.835, -0.34;
		// we can reuse initial taps
		// t0x = 
		

		// original blur from b34r & BlueSkyDefender
		// +---+---+---+---+---+
		// |   |   |   |   |   |
		// +---+---+---+---+---+
		// |\\\|   | 1 |   |   |
		// +---+---+---+---+---+
		// |   |\\\|\\\| 1 |   |
		// +---+---+---+---+---+
		// |   |   | 0 |\\\|\\\|
		// +---+---+---+---+---+
		// |   |   |   |   |   |
		// +---+---+---+---+---+
		// y = -0.5x; n.x = 1; n.y = 0.5; nl = 1.18; dn.x = 0.85; dn.y = 0.42;
		// t0/1 = 0.425, 0.21; d ~= 0.5
		// t2/3 = 0.765, -0.38; d ~= 0.85
		float2 dn = Rotate(n, -angle) / nl * BlurSize;
		// float2 dn = n / nl * BlurSize;
		float4 t0 = tex2Dlod(ReShade::BackBuffer, float4(mad(-dn * 0.5, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
		float4 t1 = tex2Dlod(ReShade::BackBuffer, float4(mad(dn * 0.5, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
		float4 t2 = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(dn.x, -dn.y) * 0.9, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
		float4 t3 = tex2Dlod(ReShade::BackBuffer, float4(mad(float2(-dn.x, dn.y) * 0.9, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
		float4 t4 = tex2Dlod(ReShade::BackBuffer, float4(mad(-dn.yx * 0.9, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
		float4 t5 = tex2Dlod(ReShade::BackBuffer, float4(mad(dn.yx * 0.9, BUFFER_PIXEL_SIZE, texcoord), 0.0, 0.0));
		color = lerp(mad(color, 0.23, 0.0875 * (t2 + t3 + t4 + t5) + 0.21 * (t0 + t1)), color, edgeMask);

		// color.rgb = lerp((t + b + r + l) / 4.0, color.rgb, edgeMask);
    }

	// DebugOutput
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

float4 NFAA_PS(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	return NFAA(texcoord);
}

technique NFAA
{
		pass NFAA_Fast
        {
            VertexShader = PostProcessVS;
            PixelShader = NFAA_PS;
        }
}
