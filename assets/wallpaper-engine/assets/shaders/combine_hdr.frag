
varying vec2 v_TexCoord;

uniform sampler2D g_Texture0;
uniform sampler2D g_Texture1;

uniform vec2 g_TexelSize;

#if DISPLAYHDR == 1
uniform vec4 g_RenderVar0;
#endif

// Proper gamma conversion http://chilliant.blogspot.com/2012/08/srgb-approximations-for-hlsl.html
vec3 lin(vec3 v)
{
	vec3 c = step(0.04045, v);
	return c * (pow((v + 0.055) / 1.055, CAST3(2.4))) + (1.0 - c) * (v / 12.92);
}

void main()
{
	vec3 albedo = texSample2D(g_Texture0, v_TexCoord).rgb;
	vec3 bloom1 = texSample2D(g_Texture1, v_TexCoord + g_TexelSize).rgb +
				texSample2D(g_Texture1, v_TexCoord - g_TexelSize).rgb +
				texSample2D(g_Texture1, v_TexCoord + vec2(g_TexelSize.x, -g_TexelSize.y)).rgb +
				texSample2D(g_Texture1, v_TexCoord + vec2(-g_TexelSize.x, g_TexelSize.y)).rgb;
	bloom1 *= 0.25;

#if DISPLAYHDR == 1
	albedo = saturate(albedo);
	albedo += bloom1;
	vec3 hdrFactors = g_RenderVar0.y * smoothstep(CAST3(1.0), CAST3(2.0), albedo) + g_RenderVar0.x;
	gl_FragColor = vec4(lin((max(CAST3(0.0), albedo))) * hdrFactors, 1.0);
#else
#if COMBINEDBG == 1
	albedo = mix(albedo + bloom1, bloom1, step(0.5, v_TexCoord.x) * step(v_TexCoord.y, 0.5));
#else
	albedo += bloom1;
#endif

#if LINEAR == 1
	gl_FragColor = vec4(saturate(albedo), 1.0);
#else
	gl_FragColor = vec4(lin(saturate(albedo)), 1.0);
#endif
#endif

#if 0
	float maxWhite = g_RenderVar0.x;
	float maxBloom = g_RenderVar0.x + g_RenderVar0.y;
	float lum = max(gl_FragColor.r, max(gl_FragColor.g, gl_FragColor.b));
	
	float blendGreen = smoothstep(maxWhite, maxBloom - 0.5, lum);
	float blendRed = smoothstep(maxBloom - 0.5, maxBloom, lum);
	gl_FragColor.rgb = CAST3(lum);
	gl_FragColor.rgb = mix(gl_FragColor.rgb, vec3(0, maxBloom - 0.5, 0), saturate(blendGreen));
	gl_FragColor.rgb = mix(gl_FragColor.rgb, vec3(maxBloom, 0, 0), saturate(blendRed));

	// remap to SDR whitelevel
	//gl_FragColor.rgb /= g_RenderVar0.x + g_RenderVar0.y;
	//gl_FragColor.rgb = saturate(gl_FragColor.rgb) * g_RenderVar0.x;
#endif
}
