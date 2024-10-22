 ////-------------//
 ///**DLAA**///
 //-------------////

 //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
 //* Directionally Localized Antialiasing Plus.
 //* For ReShade 3.0+
 //*  ---------------------------------
 //*                                                                           DLAA+
 //* Due Diligence
 //* Directionally Localized Anti-Aliasing (DLAA)
 //* Original method by Dmitry Andreev
 //* http://and.intercon.ru/releases/talks/dlaagdc2011/
 //*
 //* LICENSE
 //* ============
 //* Directionally Localized Anti-Aliasing Plus is licenses under: Attribution-NoDerivatives 4.0 International
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
 //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
 
uniform float Short_Edge_Mask <
 	ui_type = "drag";
 	ui_min = 0.0; ui_max = 1.0;
 	ui_label = "Short Edge AA";
 	ui_tooltip = "Use this to adjust the Short Edge AA.\n"
 				 "Default is 0.5";
 	ui_category = "DLAA";
 > = 0.5;
 
 uniform float Long_Edge_Mask <
 	ui_type = "drag";
 	ui_min = 0.0; ui_max = 1.0;
 	ui_label = "Long Edge AA";
 	ui_tooltip = "Use this to adjust the Long Edge AA.\n"
 				 "Default is 0.5";
 	ui_category = "DLAA";
 > = 0.5;

uniform float Text_Preservation <
 	ui_type = "drag";
 	ui_min = 0.0; ui_max = 1.0;
 	ui_label = "Text Preservation";
 	ui_tooltip = "Use this to adjust Text Preservation Power.\n"
 				 "Default is 0.5";
	 ui_category = "DLAA Debuging";
 > = 0.5;
//static const float Black_Preservation = 0.7;
///*
uniform float Black_Preservation <
 	ui_type = "drag";
 	ui_min = 0.0; ui_max = 1.0;
 	ui_label = "Black Preservation";
 	ui_tooltip = "Use this to prevent Black Shades from getting AA Since most times this is not needed.\n"
 				 "Default is 0.25";
	 ui_category = "DLAA Debuging";
 > = 0.25;
//*/
uniform int View_Mode <
	ui_type = "combo";
	ui_items = "DLAA\0Red H & Green V Short Edge Mask\0Red H & Green V Long Edge Mask\0Text Preservation Mask\0";
	ui_label = "View Mode";
	ui_tooltip = "This is used to select the normal view output or debug view.";
	ui_category = "DLAA Debuging";
> = 0;
/*
uniform float TEST <
 	ui_type = "drag";
 	ui_min = 0.0; ui_max = 1.0;
 > = 0.5;
*/
//Total amount of frames since the game started.
uniform uint framecount < source = "framecount"; >;
////////////////////////////////////////////////////////////DLAA////////////////////////////////////////////////////////////////////
uniform float Delta < source = "timer"; >; 
#define Alternate framecount % 2 == 0
#define pix float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT)
#define lambda lerp(0,5,Short_Edge_Mask)
#define epsilon 0.1 //lerp(0,0.5,Error_Clamping)
#define HoizVert lerp(0.0,2.5,Long_Edge_Mask)
#define Text_Total 25000 

float fmod(float a, float b)
{
	float c = frac(abs(a / b)) * abs(b);
	return a < 0 ? -c : c;
}

texture BackBufferTex : COLOR;

sampler BackBuffer
	{
		Texture = BackBufferTex;
	};

texture SLPtex {Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; MipLevels = 1; };

sampler SamplerLoadedPixel
	{
		Texture = SLPtex;
	};

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
float CB_Pattern(float2 TC)
{
	float2 gridxy = floor(float2(TC.x * BUFFER_WIDTH, TC.y * BUFFER_HEIGHT));
	return fmod(gridxy.x+gridxy.y,2);
}

//Luminosity Intensity
float LI(in float3 value)
{
	return max(value.r, max(value.g, value.b));
}

float4 LP(float2 tc,float dx, float dy) //Load Pixel
{
	float4 BB = tex2D(BackBuffer, tc + float2(dx, dy) * pix.xy);
	return BB;
}

float3 SetInfo()
{
	return float3(Delta == 0 ? 0 : Delta,Text_Total == 0 ? 1 :  Text_Total, Delta == 0 || Text_Total == 0 ? -1 : 0);
}

float4 PreFilter(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target //Loaded Pixel
{  
	//5 bi-linear samples cross
	float4 Center = LP(texcoord, 0 , 0);
	float4 Left   = LP(texcoord,-1.0 , 0.0);
	float4 Right  = LP(texcoord, 1.0 , 0.0);
	float4 Up     = LP(texcoord, 0.0 ,-1.0);
	float4 Down   = LP(texcoord, 0.0 , 1.0);


    float4 edges = 4.0 * abs((Left + Right + Up + Down) - 4.0 * Center);
    float  edgesLum = LI(edges.rgb);

    return float4(Center.rgb, edgesLum);
}

float4 SLP(float2 tc,float dx, float dy, float MIPS) //Load Pixel
{
	return tex2Dlod(SamplerLoadedPixel, float4(tc + float2(dx, dy) * pix.xy,0,MIPS));
}

float Text_Detection(float2 texcoord)
{
	float4 BC = SLP( texcoord, 0.0 , 0.0 , 1.0 );
	// Luma Threshold Thank you Adyss
	BC.a    = LI(BC.rgb);//Luma
	BC.rgb /= max(BC.a, 0.001);
	BC.a    = max(0.0, BC.a ) > 0.994;
	//BC.rgb *= BC.a;
	//1-BC.a;//dot(BC.rgb,BC.rgb);//
    return 1-lerp(1,1-BC.a,Text_Preservation);
}

float Blacks_Detection(float2 texcoord)
{
	float4 BC = SLP( texcoord, 0.0 , 0.0 , 1.0 );
	// Luma Threshold Thank you Adyss
	BC.a    = LI(BC.rgb);//Luma
	BC.rgb /= max(BC.a, 0.001);
	BC.a    = max(0.0, BC.a );

    return 1-lerp(1,BC.a,Black_Preservation);
}


//Information on Slide 44 says to run the edge processing jointly short and Large.
float4 DLAA(float2 texcoord)
{   //Short Edge Filter http://and.intercon.ru/releases/talks/dlaagdc2011/slides/#slide43
	float4 DLAA, H, V, UDLR; //DLAA is the completed AA Result.
	float2 CBxy = floor( float2(texcoord.x * BUFFER_WIDTH, texcoord.y * BUFFER_HEIGHT));

	//5 bi-linear samples cross
	float4 Center = LP(texcoord, 0 , 0);
	float4 Left   = LP(texcoord,-1.0 , 0.0);
	float4 Right  = LP(texcoord, 1.0 , 0.0);
	float4 Up     = LP(texcoord, 0.0 ,-1.0);
	float4 Down   = LP(texcoord, 0.0 , 1.0);

	//Combine horizontal and vertical blurs together
	float4 combH	   = 2.0 * ( Up + Down );
	float4 combV	   = 2.0 * ( Left + Right );

	//Bi-directional anti-aliasing using HORIZONTAL & VERTICAL blur and horizontal edge detection
	//Slide information triped me up here. Read slide 43.
	//Edge detection
	float4 CenterDiffH = abs( combH - 4.0 * Center ) / 4.0;
	float4 CenterDiffV = abs( combV - 4.0 * Center ) / 4.0;

	//Blur
	float4 blurredH    = (combH + 2.0 * Center) / 6.0;
	float4 blurredV    = (combV + 2.0 * Center) / 6.0;

	//Edge detection
	float LumH         = LI( CenterDiffH.rgb );
	float LumV         = LI( CenterDiffV.rgb );

	float LumHB        = LI(blurredH.xyz);
	float LumVB        = LI(blurredV.xyz);

	//t
	float satAmountH   = saturate( ( lambda * LumH - epsilon ) / LumVB ) > 0.5;
	float satAmountV   = saturate( ( lambda * LumV - epsilon ) / LumHB ) > 0.5;

	//color = lerp(color,blur,sat(Edge/blur)
	//Re-blend Short Edge Done
	DLAA = lerp( Center, blurredH, satAmountV );
	DLAA = lerp( DLAA,   blurredV, satAmountH );

	DLAA =  lerp(DLAA, Center, Text_Detection(texcoord) );	
	DLAA =  lerp(DLAA, Center, Blacks_Detection(texcoord) );
	  
	float4  HNeg, HNegA, HNegB, HNegC, HNegD, HNegE,
			HPos, HPosA, HPosB, HPosC, HPosD, HPosE,
			VNeg, VNegA, VNegB, VNegC,
			VPos, VPosA, VPosB, VPosC;

	// Long Edges
	//16 bi-linear samples cross, added extra bi-linear samples in each direction.
    HNeg    = SLP( texcoord,-1.5 , 0.0 , 0.0 );
    HNegA   = SLP( texcoord,-3.5 , 0.0 , 0.0 );
    HNegB   = SLP( texcoord,-5.5 , 0.0 , 0.0 );
    HNegC   = SLP( texcoord,-7.5 , 0.0 , 0.0 );

    HPos    = SLP( texcoord, 1.5 , 0.0 , 0.0 );
    HPosA   = SLP( texcoord, 3.5 , 0.0 , 0.0 );
    HPosB   = SLP( texcoord, 5.5 , 0.0 , 0.0 );
    HPosC   = SLP( texcoord, 7.5 , 0.0 , 0.0 );

    VNeg    = SLP( texcoord, 0.0 ,-1.5 , 0.0 );
    VNegA   = SLP( texcoord, 0.0 ,-3.5 , 0.0 );
    VNegB   = SLP( texcoord, 0.0 ,-5.5 , 0.0 );
    VNegC   = SLP( texcoord, 0.0 ,-7.5 , 0.0 );

    VPos    = SLP( texcoord, 0.0 , 1.5 , 0.0 );
    VPosA   = SLP( texcoord, 0.0 , 3.5 , 0.0 );
    VPosB   = SLP( texcoord, 0.0 , 5.5 , 0.0 );
    VPosC   = SLP( texcoord, 0.0 , 7.5 , 0.0 );

	//Long Edge detection H & V
	float4 AvgBlurH = ( HNeg + HNegA + HNegB + HNegC + HPos + HPosA + HPosB + HPosC ) / 8;
	float4 AvgBlurV = ( VNeg + VNegA + VNegB + VNegC + VPos + VPosA + VPosB + VPosC ) / 8;
	float EAH = saturate( AvgBlurH.w * HoizVert - 1 );
	float EAV = saturate( AvgBlurV.w * HoizVert - 1 );

	float longEdge = abs( EAH - EAV ) > 0.25;//abs( EAH - EAV ) > Edge_Trim ;

    if ( longEdge )
    {
		//Merge for BlurSamples.
		//Long Blur H
		float LongBlurLumH = LI( AvgBlurH.rgb );//8 samples
		//Long Blur V
		float LongBlurLumV = LI( AvgBlurV.rgb );//8 samples

		float centerLI = LI( Center.rgb);
		float upLI     = LI( Up.rgb    );
		float downLI   = LI( Down.rgb  );
		float leftLI   = LI( Left.rgb  );
		float rightLI  = LI( Right.rgb );

		float blurUp   = saturate( 0.0 + ( LongBlurLumH - upLI     ) / (centerLI - upLI   ) );
		float blurDown = saturate( 1.0 + ( LongBlurLumH - centerLI ) / (centerLI - downLI ) );
		float blurLeft = saturate( 0.0 + ( LongBlurLumV - leftLI   ) / (centerLI - leftLI ) );
		float blurRight= saturate( 1.0 + ( LongBlurLumV - centerLI ) / (centerLI - rightLI) );
	  
		UDLR = float4( blurLeft, blurRight, blurUp, blurDown );

		UDLR = UDLR == 0.0 ? 1.0 : UDLR;

	    V = lerp( Left , Center, UDLR.x );
   	 V = lerp( Right, V	 , UDLR.y );
		H = lerp( Up   , Center, UDLR.z );
		H = lerp( Down , H	 , UDLR.w );
	  float4 StoreDLAA = DLAA;
      DLAA = lerp( DLAA , V , EAV);
	  DLAA = lerp( DLAA , H , EAH);

	  DLAA =  lerp(DLAA, StoreDLAA, Text_Detection(texcoord) );
	  DLAA =  lerp(DLAA, StoreDLAA, Blacks_Detection(texcoord));
    }
    
	EAV = lerp(0,EAV,longEdge); EAH = lerp(0,EAH,longEdge);

	return float4(DLAA.rgb,CB_Pattern(texcoord) ? View_Mode == 1 ? satAmountV : EAV : View_Mode == 1 ? satAmountH : EAH);
	
}

float4 AA_Out(float2 texcoord)
{
	float4 DLAA = DLAA(texcoord);

	if (View_Mode == 1 || View_Mode == 2)
		DLAA = lerp(DLAA,1,float4(CB_Pattern(texcoord) ? 0 : DLAA.w, CB_Pattern(texcoord) ? DLAA.w : 0,0,1));
	
	if (View_Mode == 3)
		DLAA =  lerp(DLAA,float4(1,1,0,1),Text_Detection(texcoord));

	return DLAA;
}

// Text rendering code Modded from https://www.shadertoy.com/view/4dtGD2 by Hamneggs
////////////////////////////////////////////////////////Logo/////////////////////////////////////////////////////////////////////////
static const float CH_D    = 0x79997, CH_E    = 0xf171f, CH_F    = 0xf1711, CH_H    = 0x99f99, CH_I    = 0xf444f, CH_N    = 0x9bd99, 
				   CH_O    = 0x69996, CH_P    = 0x79971, CH_T    = 0xf4444, CH_3    = 0x69496, CH_FSTP = 0x00002;
		
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

float Information(float2 TC)
{		//Size
		float D3D_Size_A = 1.375,D3D_Size_B = 0.75, Out;
		float2 charSize_A = float2(.00875, .0125) * D3D_Size_A, charSize_B = float2(.00875, .0125) * D3D_Size_B, WebCharPos = float2( 0.862, 0.018);
		[branch] if(SetInfo().x <= SetInfo().y)
		{   Out += drawChar( CH_D, WebCharPos, charSize_A, TC); WebCharPos.x += .01 * D3D_Size_A;
			Out += drawChar( CH_E, WebCharPos, charSize_A, TC); WebCharPos.x += .01 * D3D_Size_A;
			Out += drawChar( CH_P, WebCharPos, charSize_A, TC); WebCharPos.x += .01 * D3D_Size_A;
			Out += drawChar( CH_T, WebCharPos, charSize_A, TC); WebCharPos.x += .01 * D3D_Size_A;
			Out += drawChar( CH_H, WebCharPos, charSize_A, TC); WebCharPos.x += .01 * D3D_Size_A;
			Out += drawChar( CH_3, WebCharPos, charSize_A, TC); WebCharPos.x += .01 * D3D_Size_A;
			Out += drawChar( CH_D, WebCharPos, charSize_A, TC); WebCharPos.x += 0.008 * D3D_Size_A;
			Out += drawChar( CH_FSTP, WebCharPos, charSize_A, TC); WebCharPos.x += 0.01 * D3D_Size_A;
			WebCharPos = float2( 0.963, 0.018);
			Out += drawChar( CH_I, WebCharPos, charSize_B, TC); WebCharPos.x += .01 * D3D_Size_B;
			Out += drawChar( CH_N, WebCharPos, charSize_B, TC); WebCharPos.x += .01 * D3D_Size_B;
			Out += drawChar( CH_F, WebCharPos, charSize_B, TC); WebCharPos.x += .01 * D3D_Size_B;
			Out += drawChar( CH_O, WebCharPos, charSize_B, TC);
		}
		
	return Out;
}

float4 Out(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float PosX = 0.9525f*BUFFER_WIDTH*pix.x,PosY = 0.975f*BUFFER_HEIGHT*pix.y,DBlending = (1-texcoord.y*50.0+48.85)*texcoord.y-0.500;
	float2 TC = float2(texcoord.x,1-texcoord.y);
	float3 Color = AA_Out(texcoord).rgb;

	return float4(Information(TC) > SetInfo().z ? DBlending : Color,1.0f);
}

///////////////ReShade.fxh/////////////////////////////////////////////////////////////

// Vertex shader generating a triangle covering the entire screen
void PostProcessVS(in uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD)
{
	texcoord.x = (id == 2) ? 2.0 : 0.0;
	texcoord.y = (id == 1) ? 2.0 : 0.0;
	position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

//*Rendering passes*//
technique Directionally_Localized_Anti_Aliasing
{
	pass Pre_Filter
	{
		VertexShader = PostProcessVS;
		PixelShader = PreFilter;
		RenderTarget = SLPtex;
	}
	pass DLAA_Plus
	{
		VertexShader = PostProcessVS;
		PixelShader = Out;
	}
}
