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

uniform float SearchStepSize < __UNIFORM_DRAG_FLOAT1
    ui_label = "Search Step Size";
    ui_tooltip = "Determines the radius NFAA will search for edges.\n"
                 "Default is 1.00";
    ui_min = 0.0; ui_max = 4.0;
> = 1.00;

uniform int DebugOutput <
    ui_type = "combo";
    ui_items = "None\0Edge Mask View\0Normal View\0Fake DLSS\0";
    ui_label = "Debug Output";
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
	// The Edge Seeking code can be adjusted to look for longer edges.
    // But, I don't think it's really needed.
    float4 NFAA = 1.0;
	float Mask = 1.0;
    float t, l, r, b;
    float SSS = SearchStepSize;
    float EDT = EdgeDetectionThreshold;
    
	if (DebugOutput == 3) // Fake DLSS
	{
        SSS = 5.0;
        EDT = 0.005;
    }
    
	float2 SW = BUFFER_PIXEL_SIZE * SSS;
    float2 UV = texcoord.xy;
    
    // Find Edges
    t = LI(GetBB(float2(UV.x, UV.y - SW.y)).rgb);
    b = LI(GetBB(float2(UV.x, UV.y + SW.y)).rgb);
    l = LI(GetBB(float2(UV.x - SW.x, UV.y)).rgb);
    r = LI(GetBB(float2(UV.x + SW.x, UV.y)).rgb);
    float2 n = float2(t - b, l - r);
	float nl = length(n);

    
    // Seek aliasing and apply AA. Think of this as basically blur control.
    if (nl < EDT) // face
	{
		NFAA = GetBB(UV);
    }
    else // edge
	{
		// Lets make that mask for a sharper image.
		// 1.0 - 10.0 * nl
		// 0 if nl >= 0.1
		Mask = saturate(mad(nl, -10.0, 1.0));

        n *= BUFFER_PIXEL_SIZE / nl;
        if (DebugOutput == 3) n *= 2.0; // Fake DLSS

        float4 o = GetBB(UV),
                t0 = GetBB(UV + float2(n.x, -n.y) * 0.5) * 0.9,
                t1 = GetBB(UV - float2(n.x, -n.y) * 0.5) * 0.9,
                t2 = GetBB(UV + n * 0.9) * 0.75,
                t3 = GetBB(UV - n * 0.9) * 0.75;

		NFAA = lerp((o + t0 + t1 + t2 + t3) / 4.3, o, Mask);
    }

	// DebugOutput
    if(DebugOutput == 1)
    {
        NFAA.rgb = Mask;
    }
    else if (DebugOutput == 2)
    {
        NFAA.rgb = float3(-float2(-(r - l), -(t - b)) * 0.5 + 0.5, 1.0);
    }

	return NFAA;
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
