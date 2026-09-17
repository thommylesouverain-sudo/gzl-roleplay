float2 size = float2(100, 40);
float radius = 10;
float borderWidth = 1;
float4 fillColor = float4(0.1, 0.1, 0.1, 1);
float4 endColor = float4(0.1, 0.1, 0.1, 1);
float4 edgeColor = float4(1, 1, 1, 0.1);
float style = 0;
float direction = 0;
float dashLength = 8;
float dashGap = 5;
float intensity = 0.5;

// MTA supplies this matrix for both screen and render-target drawing.
// ps_3_0 needs an explicit matching vertex stage: do not rely on the
// fixed-function pipeline to populate its UV and COLOR interpolators.
float4x4 WorldViewProjection : WORLDVIEWPROJECTION;
struct SurfaceVertex {
    float3 Position : POSITION0;
    float4 Diffuse : COLOR0;
    float2 TexCoord : TEXCOORD0;
};
struct SurfacePixel {
    float4 Position : POSITION0;
    float4 Diffuse : COLOR0;
    float2 TexCoord : TEXCOORD0;
};
SurfacePixel surfaceVertex(SurfaceVertex input) {
    SurfacePixel output;
    output.Position = mul(float4(input.Position, 1), WorldViewProjection);
    output.Diffuse = input.Diffuse;
    output.TexCoord = input.TexCoord;
    return output;
}

float4 surface(float2 uv : TEXCOORD0, float4 diffuse : COLOR0) : COLOR0 {
    float2 q = abs((uv - 0.5) * size) - size * 0.5 + radius;
    float d = length(max(q, 0)) + min(max(q.x, q.y), 0) - radius;
    float coverage = 1 - smoothstep(-1, 0, d);
    float edge = borderWidth > 0 ? smoothstep(-borderWidth - 1, -borderWidth, d) : 0;
    float axis = lerp(uv.y, uv.x, direction);
    float4 base = lerp(fillColor, endColor, axis);
    if (style > 1.5 && style < 2.5) {
        base.rgb += (pow(saturate(1 - uv.y), 7) * 0.24 + exp(-abs(uv.y - 0.45) * 18) * 0.035) * intensity;
    }
    if (style > 3.5 && style < 4.5) {
        base.rgb += (1 - uv.x) * 0.09 * intensity;
    }
    if (style > 4.5 && style < 5.5) {
        float2 light = (uv - float2(0.5, 0.1)) * float2(1.2, 1.8);
        base.rgb += exp(-dot(light, light) * 5) * 0.32 * intensity;
    }
    float4 stroke = edgeColor;
    if (style > 5.5) {
        // Continuous perimeter coordinate, projected to the nearest straight edge.
        float2 p = uv * size;
        float horizontal = min(p.y, size.y-p.y) < min(p.x, size.x-p.x);
        float alongH = p.y < size.y*0.5 ? p.x : size.x+size.y+(size.x-p.x);
        float alongV = p.x > size.x*0.5 ? size.x+p.y : 2*size.x+size.y+(size.y-p.y);
        float along = lerp(alongV, alongH, horizontal);
        float dash = step(frac(along / max(1, dashLength+dashGap)), dashLength/max(1, dashLength+dashGap));
        stroke = lerp(base, stroke, dash);
    }
    float4 color = lerp(base, stroke, edge);
    color.a *= coverage;
    return color * diffuse;
}

technique RoundedSurface {
    pass P0 {
        ZEnable = false;
        ZWriteEnable = false;
        CullMode = None;
        AlphaTestEnable = false;
        AlphaBlendEnable = true;
        SrcBlend = SRCALPHA;
        DestBlend = INVSRCALPHA;
        VertexShader = compile vs_3_0 surfaceVertex();
        PixelShader = compile ps_3_0 surface();
    }
}
