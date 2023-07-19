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

uniform int AA_Adjust <
    ui_type = "drag";
    ui_min = 1; ui_max = 128;
    ui_label = "AA Power";
    ui_tooltip = "Use this to adjust the AA power.\n"
                 "Default is 16";
    ui_category = "NFAA";
> = 16;

uniform float Mask_Adjust <
    ui_type = "drag";
    ui_min = 0.0; ui_max = 4.0;
    ui_label = "Mask Adjustment";
    ui_tooltip = "Use this to adjust the Mask.\n"
                 "Default is 1.00";
    ui_category = "NFAA";
> = 1.00;

uniform int View_Mode <
    ui_type = "combo";
    ui_items = "NFAA\0Mask View\0Normals\0DLSS\0";
    ui_label = "View Mode";
    ui_tooltip = "This is used to select the normal view output or debug view.\n"
                 "NFAA Masked gives you a sharper image with applyed Normals AA.\n"
                 "Masked View gives you a view of the edge detection.\n"
                 "Normals gives you an view of the normals created.\n"
                 "DLSS is NV_AI_DLSS Parody experiance..........\n"
                 "Default is NFAA.";
    ui_category = "NFAA";
> = 0;

//Total amount of frames since the game started.
uniform uint framecount < source = "framecount"; >;

////////////////////////////////////////////////////////////NFAA////////////////////////////////////////////////////////////////////
// sRGB Luminance
float LI(in float3 value)
{
    // return dot(value.rgb, float3(0.2126, 0.7152, 0.0722)); // sRGB luminance
    return dot(value.rgb, float3(0.299, 0.587, 0.114)); // Perceived Luminance
}

float4 GetBB(float2 texcoord : TEXCOORD)
{
    return tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0.0, 0.0));
}

float4 NFAA(float2 texcoord)
{
    float4 NFAA; // The Edge Seeking code can be adjusted to look for longer edges.
    float2 n; // But, I don't think it's really needed.
    float t, l, r, b;
    float MA = Mask_Adjust;
    float Rep = rcp(AA_Adjust);
    if (View_Mode == 3) {
        // DLSS
        MA = 5.0;
        Rep = rcp(128);
    }
    float2 SW = BUFFER_PIXEL_SIZE * MA;
    float2 UV = texcoord.xy;
    
    // Find Edges
    t = LI(GetBB(float2(UV.x, UV.y - SW.y)).rgb);
    b = LI(GetBB(float2(UV.x, UV.y + SW.y)).rgb);
    l = LI(GetBB(float2(UV.x - SW.x, UV.y)).rgb);
    r = LI(GetBB(float2(UV.x + SW.x, UV.y)).rgb);
    n = float2(t - b, l - r);
	float nl = length(n);
    
    // Seek aliasing and apply AA. Think of this as basically blur control.
    if (nl < Rep)
	{
        // face
          NFAA = GetBB(UV);
    }
    else
	{
        // edge
        n *= BUFFER_PIXEL_SIZE / nl;
        if (View_Mode == 3) n *= 2.0;

        float4 o = GetBB(UV),
                t0 = GetBB(UV + float2(n.x, -n.y) * 0.5) * 0.9,
                t1 = GetBB(UV - float2(n.x, -n.y) * 0.5) * 0.9,
                t2 = GetBB(UV + n * 0.9) * 0.75,
                t3 = GetBB(UV - n * 0.9) * 0.75;

        NFAA = (o + t0 + t1 + t2 + t3) / 4.3;
    }

    // Lets make that mask for a sharper image.
    float Mask = nl * 5.0;
    if (Mask > 0.025)
        Mask = 1 - Mask;
    else
        Mask = 1;
    // Super Evil Magic Number.
    Mask = saturate(lerp(Mask, 1, -1));

    // Final color
    if(View_Mode == 0)
    {
        NFAA = lerp(NFAA, GetBB(UV), Mask);
    }
    else if(View_Mode == 1)
    {
        NFAA = Mask;
    }
    else if (View_Mode == 2)
    {
        NFAA = float3(-float2(-(r - l), -(t - b)) * 0.5 + 0.5, 1.0);
    }
	return NFAA;
}

float4 Out(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float3 Color = NFAA(texcoord).rgb;
    return float4(Color, 1.0);
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
