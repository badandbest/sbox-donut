HEADER
{
	Description = "CRT Shader for S&box Donut";
}

FEATURES
{
	#include "common/features.hlsl"

	Feature( F_ENABLE_CURVE, 0..1 );
	Feature( F_ENABLE_OVERSCAN, 0..1 );
	Feature( F_ENABLE_BLOOM, 0..1 );
	Feature( F_ENABLE_BLUR, 0..1 );
	Feature( F_ENABLE_GRAYSCALE, 0..1 );
	Feature( F_ENABLE_BLACKLEVEL, 0..1 );
	Feature( F_ENABLE_REFRESHLINE, 0..1 );
	Feature( F_ENABLE_SCANLINES, 0..1 );
	Feature( F_ENABLE_TINT, 0..1 );
	Feature( F_ENABLE_GRAIN, 0..1 );
}

COMMON
{
	#include "common/shared.hlsl"
	
	// Settings - Curve
	#define CURVE_INTENSITY         1
	
	// Settings - Overscan
	#define OVERSCAN_PERCENTAGE     0.02
	
	// Settings - Bloom
	#define BLOOM_OFFSET            0.0015
	#define BLOOM_STRENGTH          0.8
	
	// Settings - Blur
	#define BLUR_MULTIPLIER         1.05
	#define BLUR_STRENGTH           0.2
	#define BLUR_OFFSET             0.003
	
	// Settings - Grayscale
	#define GRAYSCALE_INTENSITY     0
	#define GRAYSCALE_GLEAM         0
	#define GRAYSCALE_LUMINANCE     1
	#define GRAYSCALE_LUMA          0
	
	// Settings - Blacklevel
	#define BLACKLEVEL_FLOOR        TINT_COLOR / 40
	
	// Settings - Tint
	// Colors variations from https://superuser.com/a/1206781
	#define TINT_COLOR              TINT_AMBER
	
	#define TINT_AMBER              float3(1.0, 0.7, 0.0) // P3 phosphor
	#define TINT_LIGHT_AMBER        float3(1.0, 0.8, 0.0)
	#define TINT_GREEN_1            float3(0.2, 1.0, 0.0)
	#define TINT_APPLE_II           float3(0.2, 1.0, 0.2) // P1 phosphor
	#define TINT_GREEN_2            float3(0.0, 1.0, 0.2)
	#define TINT_APPLE_IIc          float3(0.4, 1.0, 0.4) // P24 phpsphor
	#define TINT_GREEN_3            float3(0.0, 1.0, 0.4)
	#define TINT_WARM               float3(1.0, 0.9, 0.8)
	#define TINT_COOL               float3(0.8, 0.9, 1.0)
	
	// Settings - Grain
	#define GRAIN_INTENSITY         0.02
	
	// If you have Bloom enabled, it doesn't play well
	// with the way Gleam and Luma calculate grayscale
	// so fall back to Luminance
	#if S_ENABLE_BLOOM && (GRAYSCALE_GLEAM || GRAYSCALE_LUMA)
	#undef GRAYSCALE_INTENSITY
	#undef GRAYSCALE_GLEAM
	#undef GRAYSCALE_LUMINANCE
	#undef GRAYSCALE_LUMA
	#define GRAYSCALE_LUMINANCE 1
	#endif
	
	// Provide a reasonable Blacklevel even if Tint isn't enabled
	#if S_ENABLE_BLACKLEVEL && !S_ENABLE_TINT
	#undef BLACKLEVEL_FLOOR
	#define BLACKLEVEL_FLOOR float3(0.05, 0.05, 0.05)
	#endif
}

struct VertexInput
{
	#include "common/vertexinput.hlsl"
};

struct PixelInput
{
	#include "common/pixelinput.hlsl"
};

VS
{
	#include "common/vertex.hlsl"

	PixelInput MainVs( VertexInput i )
	{
		PixelInput o = ProcessVertex( i );
		return FinalizeVertex( o );
	}
}

PS
{
    #include "common/pixel.hlsl"

	StaticCombo( S_ENABLE_CURVE, F_ENABLE_CURVE, Sys( ALL ) );
	StaticCombo( S_ENABLE_OVERSCAN, F_ENABLE_OVERSCAN, Sys( ALL ) );
	StaticCombo( S_ENABLE_BLOOM, F_ENABLE_BLOOM, Sys( ALL ) );
	StaticCombo( S_ENABLE_BLUR, F_ENABLE_BLUR, Sys( ALL ) );
	StaticCombo( S_ENABLE_GRAYSCALE, F_ENABLE_GRAYSCALE, Sys( ALL ) );
	StaticCombo( S_ENABLE_BLACKLEVEL, F_ENABLE_BLACKLEVEL, Sys( ALL ) );
	StaticCombo( S_ENABLE_REFRESHLINE, F_ENABLE_REFRESHLINE, Sys( ALL ) );
	StaticCombo( S_ENABLE_SCANLINES, F_ENABLE_SCANLINES, Sys( ALL ) );
	StaticCombo( S_ENABLE_TINT, F_ENABLE_TINT, Sys( ALL ) );
	StaticCombo( S_ENABLE_GRAIN, F_ENABLE_GRAIN, Sys( ALL ) );
	
	#if S_ENABLE_CURVE
	float2 transformCurve( float2 uv ) {
		uv -= 0.5;				// offcenter screen

		float r = ( uv.x * uv.x + uv.y * uv.y ) * CURVE_INTENSITY; 	// get ratio

		uv *= 4.2 + r;				// apply ratio
		uv *= 0.25;				// zoom
		uv += 0.5;				// move back to center

		return uv;
	}
	#endif
	
	#if S_ENABLE_OVERSCAN
	// Modifies uv
	float4 overscan( float4 color, in float2 screenuv, out float2 uv )
	{
		// Overscan Region
		uv = screenuv;
		uv -= 0.5;
		uv *= 1 / ( 1 - OVERSCAN_PERCENTAGE );
		uv += 0.5;

		if ( uv.x < 0.000 | uv.y < 0.000 ) return saturate( float4( color.rgb, 0 ) * 0.1 );
		if ( uv.y > 1.000 | uv.y > 1.000 ) return saturate( float4( color.rgb, 0 ) * 0.1 );
		
		return float4( color );
	}
	#endif
	
	#if S_ENABLE_BLOOM
	float3 bloom( float3 color, float2 uv )
	{
		float3 bloom = color - g_tColor.Sample( g_sAniso, uv + float2( -BLOOM_OFFSET, 0 ) ).rgb;
		float3 bloom_mask = bloom * BLOOM_STRENGTH;

		return saturate( color + bloom_mask );
	}
	#endif
	
	#if S_ENABLE_BLUR
	static const float blurWeights[9] = { 0.0, 0.092, 0.081, 0.071, 0.061, 0.051, 0.041, 0.031, 0.021 };
	
	float3 blurH( float3 c, float2 uv )
	{
		float3 screen = g_tColor.Sample( g_sAniso, uv ).rgb * 0.102;
		
		for ( int i = 1; i < 9; i++ ) screen += g_tColor.Sample( g_sAniso, uv + float2( i * BLUR_OFFSET, 0 ) ).rgb * blurWeights[i];
		for ( int i = 1; i < 9; i++ ) screen += g_tColor.Sample( g_sAniso, uv + float2( -i * BLUR_OFFSET, 0 ) ).rgb * blurWeights[i];
		
		return screen * BLUR_MULTIPLIER;
	}
	
	float3 blurV( float3 c, float2 uv )
	{
		float3 screen = g_tColor.Sample( g_sAniso, uv ).rgb * 0.102;
		
		for ( int i = 1; i < 9; i++ ) screen += g_tColor.Sample( g_sAniso, uv + float2( 0, i * BLUR_OFFSET ) ).rgb * blurWeights[i];
		for ( int i = 1; i < 9; i++ ) screen += g_tColor.Sample( g_sAniso, uv + float2( 0, -i * BLUR_OFFSET ) ).rgb * blurWeights[i];
		
		return screen * BLUR_MULTIPLIER;
	}
	
	float3 blur( float3 color, float2 uv )
	{
		float3 blur = ( blurH( color, uv ) + blurV( color, uv ) ) / 2 - color;
		float3 blur_mask = blur * BLUR_STRENGTH;
		
		return saturate( color + blur_mask );
	}
	#endif
	
	#if S_ENABLE_GRAYSCALE
	// https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0029740
	float3 rgb2intensity( float3 c )
	{
		return ( c.r + c.g + c.b ) / 3.0;
	}
	
	#define GAMMA 2.2
	
	float3 gamma( float3 c )
	{
		return pow( c, GAMMA );
	}
	
	float3 invGamma( float3 c )
	{
		return pow( c, 1.0 / GAMMA );
	}
	
	float3 rgb2gleam( float3 c )
	{
		c = invGamma( c );
		c = rgb2intensity( c );
		
		return gamma( c );
	}
	
	float3 rgb2luminance( float3 c )
	{
		return 0.2989 * c.r + 0.5866 * c.g + 0.1145 * c.b;
	}
	
	float3 rgb2luma( float3 c )
	{
		c = invGamma( c );
		c = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
		
		return gamma( c );
	}
	
	float3 grayscale( float3 color )
	{
		#if GRAYSCALE_INTENSITY
		color.rgb = saturate( rgb2intensity( color.rgb ) );
		#elif GRAYSCALE_GLEAM
		color.rgb = saturate( rgb2gleam( color.rgb ) );
		#elif GRAYSCALE_LUMINANCE
		color.rgb = saturate( rgb2luminance( color.rgb ) );
		#elif GRAYSCALE_LUMA
		color.rgb = saturate( rgb2luma( color.rgb ) );
		#else // Error, strategy not defined
		color.rgb = float3( 1.0, 0.0, 1.0 ) - color.rgb;
		#endif
		
		return color;
	}
	#endif
	
	#if S_ENABLE_BLACKLEVEL
	float3 blacklevel( float3 color )
	{
		color.rgb -= BLACKLEVEL_FLOOR;
		color.rgb = saturate( color.rgb );
		color.rgb += BLACKLEVEL_FLOOR;
		
		return saturate( color );
	}
	#endif
	
	#if S_ENABLE_REFRESHLINE
	float3 refreshLines( float3 color, float2 uv )
	{
		float timeOver = fmod( g_flTime / 5, 1.5 ) - 0.5;
		float refreshLineColorTint = timeOver - uv.y;
		
		if ( uv.y > timeOver && uv.y - 0.03 < timeOver ) color.rgb += ( refreshLineColorTint * 2.0 );
		
		return saturate( color );
	}
	#endif

	#if S_ENABLE_SCANLINES
	// retro.hlsl
	#define SCANLINE_FACTOR 0.3
	
	float squareWave( float y )
	{
		return 1 - ( floor( y ) % 2 ) * SCANLINE_FACTOR;
	}
	
	float3 scanlines( float3 color, float2 pos )
	{
		float wave = squareWave( pos.y );
		
		// TODO:GH#3929 make this configurable.
		// Remove the && false to draw scanlines everywhere.
		if ( length( color.rgb ) < 0.2 && false )
		{
			return saturate( color + wave * 0.1 );
		}
		else
		{	
			return saturate( color * wave );
		}
	}
	// end - retro.hlsl
	#endif
	
	#if S_ENABLE_TINT
	float3 tint( float3 color )
	{
		color.rgb *= TINT_COLOR;
		
		return saturate( color );
	}
	#endif
	
	#if S_ENABLE_GRAIN
	// Grain Lookup Table
	#define a0  0.151015505647689
	#define a1 -0.5303572634357367
	#define a2  1.365020122861334
	#define b0  0.132089632343748
	#define b1 -0.7607324991323768
	
	float permute( float x )
	{
		x *= ( 34 * x + 1 );
		
		return 289 * frac( x * 1 / 289.0 );
	}
	
	float rand( inout float state )
	{
		state = permute( state );
		
		return frac( state / 41.0 );
	}
	
	float3 grain( float3 color, float2 uv )
	{
		float3 m = float3( uv, g_flTime % 5 / 5 ) + 1.0;
		float state = permute( permute( m.x ) + m.y ) + m.z;
		float p = 0.95 * rand( state ) + 0.025;
		float q = p - 0.5;
		float r2 = q * q;
		float grain = q * ( a2 + ( a1 * r2 + a0 ) / ( r2 * r2 + b1 * r2 + b0 ) );
		
		color.rgb += GRAIN_INTENSITY * grain;
		
		return saturate( color );
	}
	#endif

	float4 MainPs( PixelInput i ) : SV_Target0
	{
		Material m = Material::From( i );
		
		float4 pos = i.vPositionSs;
		float2 uv = i.vTextureCoords;
		
		#if S_ENABLE_CURVE
		uv = transformCurve( uv );
		
		// TODO: add monitor visuals and make colors static consts
		// Outer Box
		if ( uv.x <  -0.025 || uv.y <  -0.025 ) return float4( 0.00, 0.00, 0.00, 1.0 ); 
		if ( uv.x >   1.025 || uv.y >   1.025 ) return float4( 0.00, 0.00, 0.00, 1.0 ); 
		// Bezel
		if ( uv.x <  -0.015 || uv.y <  -0.015 ) return float4( 0.03, 0.03, 0.03, 1.0 );
		if ( uv.x >   1.015 || uv.y >   1.015 ) return float4( 0.03, 0.03, 0.03, 1.0 );
		// Screen Border
		if ( uv.x <  -0.001 || uv.y <  -0.001 ) return float4( 0.00, 0.00, 0.00, 1.0 );
		if ( uv.x >   1.001 || uv.y >   1.001 ) return float4( 0.00, 0.00, 0.00, 1.0 );
		#endif
		
		// Temporary color to be substituted
		float4 color = float4( 1, 0, 1, -1 );
		
		// We need to track two different uv's. The screen uv is effectively
		// the CRT glass. We also want to track uv for when we sample from the
		// texture.
		float2 screenuv = uv;

		#if S_ENABLE_OVERSCAN
		// Modifies uv while screenuv remains the same.
		color = overscan( color, screenuv, uv );
		#endif
		
		// If no options are selected, this will just display as normal.
		// This must come after we've adjusted the uv for OVERSCAN.
		if ( color.a < 0 ) {
			color = g_tColor.Sample( g_sAniso, uv );
		}
		
		#if S_ENABLE_BLOOM
		color.rgb = bloom( color.rgb, uv );
		#endif
		
		#if S_ENABLE_BLUR
		color.rgb = blur( color.rgb, uv );
		#endif
		
		#if S_ENABLE_GRAYSCALE
		color.rgb = grayscale( color.rgb );
		#endif
		
		#if S_ENABLE_BLACKLEVEL
		color.rgb = blacklevel( color.rgb );
		#endif
		
		#if S_ENABLE_REFRESHLINE
		color.rgb = refreshLines( color.rgb, screenuv );
		#endif
		
		#if S_ENABLE_SCANLINES
		color.rgb = scanlines( color.rgb, pos );
		#endif
		
		#if S_ENABLE_TINT
		color.rgb = tint( color.rgb );
		#endif
		
		#if S_ENABLE_GRAIN
		color.rgb = grain( color.rgb, screenuv );
		#endif

		return color;
	}
}