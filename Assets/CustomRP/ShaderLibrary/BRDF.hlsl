#ifndef CUSTOM_BRDF_INCLUDED
#define CUSTOM_BRDF_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "UnityInput.hlsl"

struct BRDF {
	float3 diffuse;
	float3 specular;
	float roughness;
   float ao;
   float emission;
};

#define MIN_REFLECTIVITY 0.04
#define MEDIUMP_FLT_MAX    65504.0
#define saturateMediump(x) min(x, MEDIUMP_FLT_MAX)

float OneMinusReflectivity (float metallic) {
	float range = 1.0 - MIN_REFLECTIVITY;
	return range - metallic * range;
}

half3 EnvBRDFApprox( half3 SpecularColor, half Roughness, half NdV )
{
	// [ Lazarov 2013, "Getting More Physical in Call of Duty: Black Ops II" ]
	// Adaptation to fit our G term.
	const half4 c0 = { -1, -0.0275, -0.572, 0.022 };
	const half4 c1 = { 1, 0.0425, 1.04, -0.04 };
	half4 r = Roughness * c0 + c1;
	half a004 = min( r.x * r.x, exp2( -9.28 * NdV ) ) * r.x + r.y;
	half2 AB = half2( -1.04, 1.04 ) * a004 + r.zw;

	// Anything less than 2% is physically impossible and is instead considered to be shadowing
	// Note: this is needed for the 'specular' show flag to work, since it uses a SpecularColor of 0
	AB.y *= saturate( 50.0 * SpecularColor.g );

	return SpecularColor * AB.x + AB.y;
}

half GGX_Mobile(half Roughness, half NdH, half3 H, half3 N)
{
    // Walter et al. 2007, "Microfacet Models for Refraction through Rough Surfaces"

    // In mediump, there are two problems computing 1.0 - NoH^2
    // 1) 1.0 - NoH^2 suffers floating point cancellation when NoH^2 is close to 1 (highlights)
    // 2) NoH doesn't have enough precision around 1.0
    // Both problem can be fixed by computing 1-NoH^2 in highp and providing NoH in highp as well

    // However, we can do better using Lagrange's identity:
    //      ||a x b||^2 = ||a||^2 ||b||^2 - (a . b)^2
    // since N and H are unit vectors: ||N x H||^2 = 1.0 - NoH^2
    // This computes 1.0 - NoH^2 directly (which is close to zero in the highlights and has
    // enough precision).
    // Overall this yields better performance, keeping all computations in mediump

	float3 NxH = cross(N, H);
	float OneMinusNoHSqr = dot(NxH, NxH);


	half a = Roughness * Roughness;
	float n = NdH * a;
	float p = a / (OneMinusNoHSqr + n * n);
	float d = p * p;
	return saturateMediump(d);
}

half PhongApprox( half Roughness, half RdL )
{
	half a = Roughness * Roughness;			// 1 mul
	//!! Ronin Hack?
	a = max(a, 0.008);						// avoid underflow in FP16, next sqr should be bigger than 6.1e-5
	half a2 = a * a;						// 1 mul
	half rcp_a2 = rcp(a2);					// 1 rcp
	//half rcp_a2 = exp2( -6.88886882 * Roughness + 6.88886882 );

	// Spherical Gaussian approximation: pow( x, n ) ~= exp( (n + 0.775) * (x - 1) )
	// Phong: n = 0.5 / a2 - 0.5
	// 0.5 / ln(2), 0.275 / ln(2)
	half c = 0.72134752 * rcp_a2 + 0.39674113;	// 1 mad
	half p = rcp_a2 * exp2(c * RdL - c);		// 2 mad, 1 exp2, 1 mul
	// Total 7 instr
	return min(p, rcp_a2);						// Avoid overflow/underflow on Mali GPUs
}

half CalcSpecular(half Roughness, float NdH, float3 H, float3 N)
{
	return (Roughness*0.25 + 0.25) * GGX_Mobile(Roughness, NdH, H, N);
}



BRDF GetBRDF (Surface surface, float4 PBRParams) {
	BRDF brdf;


   float oneMinusReflectivity = OneMinusReflectivity(surface.metallic);
	brdf.diffuse = surface.color * oneMinusReflectivity;

   half DielectricSpecular = 0.08 * surface.specular;
	brdf.specular = DielectricSpecular * oneMinusReflectivity + surface.color * surface.metallic;	

   half NdV = max( dot( surface.normal, surface.viewDirection ), 0 );

	float perceptualRoughness =
		PerceptualSmoothnessToPerceptualRoughness(surface.smoothness);
	brdf.roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

   brdf.specular = EnvBRDFApprox(brdf.specular, brdf.roughness, NdV);
   brdf.specular = PhongApprox(brdf.roughness, reflect(surface.viewDirection, surface.normal));
   //specular *= ImageBasedReflectionLighting;    ---->Environment Reflection
   brdf.ao = PBRParams.b;
   brdf.emission = PBRParams.a;

	return brdf;
}



#endif