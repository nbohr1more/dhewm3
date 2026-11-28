!!ARBfp1.0
OPTION ARB_precision_hint_fastest;

# Ambient interaction shader with depth-based screen-space occlusion.
# texture 0 is the ambient normal cube map
# texture 1 is the per-surface bump map
# texture 2 is the light falloff texture
# texture 3 is the light projection texture
# texture 4 is the per-surface diffuse map
# texture 5 is the per-surface specular map
# texture 6 is the specular lookup table
# texture 7 is the captured scene depth
# texture 8 is the repeating 128x128 blue-noise tile
#
# env[0] is the diffuse modifier
# env[1] is the specular modifier
# env[18] = viewport-to-local-UV transform
# env[19] = depth UV scale, projection[10], projection[14]
# env[20] = radius UV, eye-space bias, strength
# env[22] = blue-noise UV scale

TEMP light, color, R1, R2, localNormal, specular;
TEMP uv, depthUV, noiseUV, noise, norm, direction, perpendicular, offset;
TEMP sampleUV, sampleDepthUV, depthSample, centerDepth, centerDistance, sampleDistance;
TEMP delta, occlusion, ao;

PARAM subOne = { -1, -1, -1, -1 };
PARAM scaleTwo = { 2, 2, 2, 2 };
PARAM one = { 1, 1, 1, 1 };
PARAM zero = { 0, 0, 0, 0 };
PARAM halfValue = { 0.5, 0.5, 0.5, 0.5 };
PARAM eighth = { 0.125, 0.125, 0.125, 0.125 };

# Normalize the specular half-angle vector.
DP3 specular, fragment.texcoord[6], fragment.texcoord[6];
RSQ specular, specular.x;
MUL specular, specular.x, fragment.texcoord[6];

# The ambient-normal cube map supplies the light direction.
TEX light, fragment.texcoord[0], texture[0], CUBE;
MAD light, light, scaleTwo, subOne;

TEX localNormal, fragment.texcoord[1], texture[1], 2D;
MOV localNormal.x, localNormal.a;
MAD localNormal, localNormal, scaleTwo, subOne;
DP3 light, light, localNormal;

TXP R1, fragment.texcoord[3], texture[3], 2D;
MUL light, light, R1;
TXP R1, fragment.texcoord[2], texture[2], 2D;
MUL light, light, R1;

TEX R1, fragment.texcoord[4], texture[4], 2D;
MUL color, R1, program.env[0];
DP3 specular, specular, localNormal;
TEX R1, specular, texture[6], 2D;
MUL R1, R1, program.env[1];
TEX R2, fragment.texcoord[5], texture[5], 2D;
ADD R2, R2, R2;
MAD color, R1, R2, color;
MUL color, light, color;

# Convert window coordinates into the viewport-local UV space used by the
# captured depth texture. Blue noise rotates the sampling directions per pixel.
MAD uv.xy, fragment.position, program.env[18], program.env[18].zwzw;
MAD noiseUV.xy, fragment.position, program.env[22], program.env[22].zwzw;
TEX noise, noiseUV, texture[8], 2D;
MAD noise.xy, noise, scaleTwo, subOne;
DP3 norm, noise, noise;
RSQ norm, norm.x;
MUL noise.xy, noise, norm.x;
MOV direction.xy, noise;
MOV perpendicular.x, -noise.y;
MOV perpendicular.y, noise.x;

# Linearize the center depth. The engine projection uses clip.w = -eyeZ,
# so eye distance = projection[14] / (2*depth - 1 + projection[10]).
MUL depthUV.xy, uv, program.env[19].xyxy;
TEX centerDepth, depthUV, texture[7], 2D;
MAD centerDistance.x, centerDepth.x, scaleTwo.x, subOne.x;
ADD centerDistance.x, centerDistance.x, program.env[19].z;
RCP centerDistance.x, centerDistance.x;
MUL centerDistance.x, centerDistance.x, program.env[19].w;
ABS centerDistance.x, centerDistance.x;

MOV occlusion.x, zero.x;
MUL offset.xy, direction, program.env[20].xyxy;

# Four full-radius taps, rotated by the blue-noise direction.
ADD sampleUV.xy, uv, offset;
MUL sampleDepthUV.xy, sampleUV, program.env[19].xyxy;
TEX depthSample, sampleDepthUV, texture[7], 2D;
MAD sampleDistance.x, depthSample.x, scaleTwo.x, subOne.x;
ADD sampleDistance.x, sampleDistance.x, program.env[19].z;
RCP sampleDistance.x, sampleDistance.x;
MUL sampleDistance.x, sampleDistance.x, program.env[19].w;
ABS sampleDistance.x, sampleDistance.x;
SUB delta.x, centerDistance.x, sampleDistance.x;
SUB delta.x, delta.x, program.env[20].z;
SLT delta.x, zero.x, delta.x;
ADD occlusion.x, occlusion.x, delta.x;

SUB sampleUV.xy, uv, offset;
MUL sampleDepthUV.xy, sampleUV, program.env[19].xyxy;
TEX depthSample, sampleDepthUV, texture[7], 2D;
MAD sampleDistance.x, depthSample.x, scaleTwo.x, subOne.x;
ADD sampleDistance.x, sampleDistance.x, program.env[19].z;
RCP sampleDistance.x, sampleDistance.x;
MUL sampleDistance.x, sampleDistance.x, program.env[19].w;
ABS sampleDistance.x, sampleDistance.x;
SUB delta.x, centerDistance.x, sampleDistance.x;
SUB delta.x, delta.x, program.env[20].z;
SLT delta.x, zero.x, delta.x;
ADD occlusion.x, occlusion.x, delta.x;

MUL offset.xy, perpendicular, program.env[20].xyxy;
ADD sampleUV.xy, uv, offset;
MUL sampleDepthUV.xy, sampleUV, program.env[19].xyxy;
TEX depthSample, sampleDepthUV, texture[7], 2D;
MAD sampleDistance.x, depthSample.x, scaleTwo.x, subOne.x;
ADD sampleDistance.x, sampleDistance.x, program.env[19].z;
RCP sampleDistance.x, sampleDistance.x;
MUL sampleDistance.x, sampleDistance.x, program.env[19].w;
ABS sampleDistance.x, sampleDistance.x;
SUB delta.x, centerDistance.x, sampleDistance.x;
SUB delta.x, delta.x, program.env[20].z;
SLT delta.x, zero.x, delta.x;
ADD occlusion.x, occlusion.x, delta.x;

SUB sampleUV.xy, uv, offset;
MUL sampleDepthUV.xy, sampleUV, program.env[19].xyxy;
TEX depthSample, sampleDepthUV, texture[7], 2D;
MAD sampleDistance.x, depthSample.x, scaleTwo.x, subOne.x;
ADD sampleDistance.x, sampleDistance.x, program.env[19].z;
RCP sampleDistance.x, sampleDistance.x;
MUL sampleDistance.x, sampleDistance.x, program.env[19].w;
ABS sampleDistance.x, sampleDistance.x;
SUB delta.x, centerDistance.x, sampleDistance.x;
SUB delta.x, delta.x, program.env[20].z;
SLT delta.x, zero.x, delta.x;
ADD occlusion.x, occlusion.x, delta.x;

# Repeat the same four directions at half radius to increase local coverage.
MUL offset.xy, direction, program.env[20].xyxy;
MUL offset.xy, offset, halfValue;
ADD sampleUV.xy, uv, offset;
MUL sampleDepthUV.xy, sampleUV, program.env[19].xyxy;
TEX depthSample, sampleDepthUV, texture[7], 2D;
MAD sampleDistance.x, depthSample.x, scaleTwo.x, subOne.x;
ADD sampleDistance.x, sampleDistance.x, program.env[19].z;
RCP sampleDistance.x, sampleDistance.x;
MUL sampleDistance.x, sampleDistance.x, program.env[19].w;
ABS sampleDistance.x, sampleDistance.x;
SUB delta.x, centerDistance.x, sampleDistance.x;
SUB delta.x, delta.x, program.env[20].z;
SLT delta.x, zero.x, delta.x;
ADD occlusion.x, occlusion.x, delta.x;

SUB sampleUV.xy, uv, offset;
MUL sampleDepthUV.xy, sampleUV, program.env[19].xyxy;
TEX depthSample, sampleDepthUV, texture[7], 2D;
MAD sampleDistance.x, depthSample.x, scaleTwo.x, subOne.x;
ADD sampleDistance.x, sampleDistance.x, program.env[19].z;
RCP sampleDistance.x, sampleDistance.x;
MUL sampleDistance.x, sampleDistance.x, program.env[19].w;
ABS sampleDistance.x, sampleDistance.x;
SUB delta.x, centerDistance.x, sampleDistance.x;
SUB delta.x, delta.x, program.env[20].z;
SLT delta.x, zero.x, delta.x;
ADD occlusion.x, occlusion.x, delta.x;

MUL offset.xy, perpendicular, program.env[20].xyxy;
MUL offset.xy, offset, halfValue;
ADD sampleUV.xy, uv, offset;
MUL sampleDepthUV.xy, sampleUV, program.env[19].xyxy;
TEX depthSample, sampleDepthUV, texture[7], 2D;
MAD sampleDistance.x, depthSample.x, scaleTwo.x, subOne.x;
ADD sampleDistance.x, sampleDistance.x, program.env[19].z;
RCP sampleDistance.x, sampleDistance.x;
MUL sampleDistance.x, sampleDistance.x, program.env[19].w;
ABS sampleDistance.x, sampleDistance.x;
SUB delta.x, centerDistance.x, sampleDistance.x;
SUB delta.x, delta.x, program.env[20].z;
SLT delta.x, zero.x, delta.x;
ADD occlusion.x, occlusion.x, delta.x;

SUB sampleUV.xy, uv, offset;
MUL sampleDepthUV.xy, sampleUV, program.env[19].xyxy;
TEX depthSample, sampleDepthUV, texture[7], 2D;
MAD sampleDistance.x, depthSample.x, scaleTwo.x, subOne.x;
ADD sampleDistance.x, sampleDistance.x, program.env[19].z;
RCP sampleDistance.x, sampleDistance.x;
MUL sampleDistance.x, sampleDistance.x, program.env[19].w;
ABS sampleDistance.x, sampleDistance.x;
SUB delta.x, centerDistance.x, sampleDistance.x;
SUB delta.x, delta.x, program.env[20].z;
SLT delta.x, zero.x, delta.x;
ADD occlusion.x, occlusion.x, delta.x;

# Average the eight binary horizon tests and attenuate ambient light only.
MUL ao.x, occlusion.x, eighth.x;
MAD ao.x, ao.x, -program.env[20].w, one.x;
MAX ao.x, ao.x, zero.x;
MUL color, color, ao.x;
MUL result.color, color, fragment.color;
END
