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

uniform bool HFR_AA <
    ui_label = "HFR AA";
    ui_tooltip = "This allows most monitors to assist in AA if your FPS is 60 or above and Locked to your monitors refresh-rate.";
    ui_category = "HFRAA";
> = false;

uniform float HFR_Adjust <
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_label = "HFR AA Adjustment";
    ui_tooltip = "Use this to adjust HFR AA.\n"
                 "Default is 1.00";
    ui_category = "HFRAA";
> = 0.5;

//Total amount of frames since the game started.
uniform uint framecount < source = "framecount"; >;
////////////////////////////////////////////////////////////NFAA////////////////////////////////////////////////////////////////////
#define Alternate framecount % 2 == 0
#define pix float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT)

texture BackBufferTex : COLOR;

sampler BackBuffer
    {
        Texture = BackBufferTex;
    };
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//SD video
float LI(in float3 value)
{
    return dot(value.rgb,float3(0.299, 0.587, 0.114));
}

float4 GetBB(float2 texcoord : TEXCOORD)
{
    return tex2D(BackBuffer, texcoord);
}

float4 NFAA(float2 texcoord)
{    float t, l, r, s, MA = Mask_Adjust;
  if(View_Mode == 3 )
    MA = 5.0;
    float2 UV = texcoord.xy, SW = pix * MA, n; // But, I don't think it's really needed.
    float4 NFAA; // The Edge Seeking code can be adjusted to look for longer edges.
    // Find Edges
    t = LI(GetBB( float2( UV.x , UV.y - SW.y ) ).rgb);
    s = LI(GetBB( float2( UV.x , UV.y + SW.y ) ).rgb);
    l = LI(GetBB( float2( UV.x - SW.x , UV.y ) ).rgb);
    r = LI(GetBB( float2( UV.x + SW.x , UV.y ) ).rgb);
    n = float2(t - s,-(r - l));
    // I should have made rep adjustable. But, I didn't see the need.
    // Since my goal was to make this AA fast cheap and simple.
  float nl = length(n), Rep = rcp(AA_Adjust);
    if(View_Mode == 3 || View_Mode == 4)
        Rep = rcp(128);
    // Seek aliasing and apply AA. Think of this as basically blur control.
    if (nl < Rep)
    {
          NFAA = GetBB(UV);
    }
    else
    {
          n *= pix / (nl * (View_Mode == 3 ? 0.5 : 1.0));

    float4   o = GetBB( UV ),
            t0 = GetBB( UV + float2(n.x, -n.y)  * 0.5) * 0.9,
            t1 = GetBB( UV - float2(n.x, -n.y)  * 0.5) * 0.9,
            t2 = GetBB( UV + n * 0.9) * 0.75,
            t3 = GetBB( UV - n * 0.9) * 0.75;

        NFAA = (o + t0 + t1 + t2 + t3) / 4.3;
    }
    // Lets make that mask for a sharper image.
    float Mask = nl * 5.0;
    if (Mask > 0.025)
        Mask = 1-Mask;
    else
        Mask = 1;
    // Super Evil Magic Number.
    Mask = saturate(lerp(Mask,1,-1));

    // Final color
    if(View_Mode == 0)
    {
        NFAA = lerp(NFAA,GetBB( texcoord.xy), Mask );
    }
    else if(View_Mode == 1)
    {
        NFAA = Mask;
    }
    else if (View_Mode == 2)
    {
        NFAA = float3(-float2(-(r - l),-(t - s)) * 0.5 + 0.5,1);
    }

return NFAA;
}

float4 Out(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{   float3 Color = NFAA(texcoord).rgb;
    return float4(Color,1.);
}

float4 PostFilter(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{ float Shift;
  if(Alternate && HFR_AA)
    Shift = pix.x;

    return tex2D(BackBuffer, texcoord +  float2(Shift * saturate(HFR_Adjust),0.0));
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
technique Normal_Filter_Anti_Aliasing
{
            pass NFAA_Fast
        {
            VertexShader = PostProcessVS;
            PixelShader = Out;
        }
            pass HFR_AA
        {
            VertexShader = PostProcessVS;
            PixelShader = PostFilter;
        }

}
