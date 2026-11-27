!!ARBfp1.0
OPTION ARB_precision_hint_fastest;

# Depth-aware screen-space filtering of the stencil visibility mask.
# texture[0] = luminance visibility mask (1 = lit, 0 = shadow)
# texture[1..6] = standard interaction textures
# texture[7] = captured scene depth
# texture[8] = repeating 128x128 two-channel blue-noise tile
# env[18] = (1/viewportWidth, 1/viewportHeight, -viewportX/width, -viewportY/height)
# env[19] = (viewportWidth/depthTextureWidth, viewportHeight/depthTextureHeight,
#            depth edge threshold, unused)
# env[20] = (filterRadius/viewportWidth, filterRadius/viewportHeight, 0, 0)
# env[22] = (1/128, 1/128, 0, 0), blue-noise tile scale
# env[23] = (halfRadius/viewportWidth, halfRadius/viewportHeight, 0, 0)
# ARB_fragment_program guarantees 24 environment parameters (0..23).

TEMP light, color, R1, R2, localNormal, specular;
TEMP uv, duv, dc, d, acc, w, vis, suv, sdv, noise, noiseUV;

PARAM subOne = { -1, -1, -1, -1 };
PARAM scaleTwo = { 2, 2, 2, 2 };
PARAM one = { 1, 1, 1, 1 };
PARAM halfValue = { 0.5, 0.5, 0.5, 0.5 };

# Half-angle normalization is arithmetic, as in dhewm3's current shader.
DP3 specular, fragment.texcoord[6], fragment.texcoord[6];
RSQ specular, specular.x;
MUL specular, specular.x, fragment.texcoord[6];

# Normalize the tangent-space light vector arithmetically; texture unit 0 is
# therefore available for the screen-space stencil mask.
DP3 light, fragment.texcoord[0], fragment.texcoord[0];
RSQ light, light.x;
MUL light, light.x, fragment.texcoord[0];

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

# Window coordinates -> viewport-local mask UVs. The captured depth texture
# starts at texel (0,0), so scale viewport UVs by its POT allocation ratio.
MAD uv.xy, fragment.position, program.env[18], program.env[18].zwzw;
MAD noiseUV.xy, fragment.position, program.env[22], program.env[22].zwzw;
TEX noise, noiseUV, texture[8], 2D;
SUB noise.xy, noise, halfValue;
MAD uv.xy, noise, program.env[23], uv;
MUL duv.xy, uv, program.env[19].xyxy;
TEX dc, duv, texture[7], 2D;
TEX d, uv, texture[0], 2D;
MOV acc.x, d.x;
MOV acc.y, one.x;

# +X tap: compare depth, then accumulate mask visibility.
ADD suv.xy, uv, program.env[20].xxxx;
MUL sdv.xy, suv, program.env[19].xyxy;
TEX d, sdv, texture[7], 2D;
SUB w.x, d.x, dc.x;
ABS w.x, w.x;
SLT w.x, w.x, program.env[19].z;
TEX d, suv, texture[0], 2D;
MAD acc.x, d.x, w.x, acc.x;
ADD acc.y, acc.y, w.x;

# -X tap.
SUB suv.xy, uv, program.env[20].xxxx;
MUL sdv.xy, suv, program.env[19].xyxy;
TEX d, sdv, texture[7], 2D;
SUB w.x, d.x, dc.x;
ABS w.x, w.x;
SLT w.x, w.x, program.env[19].z;
TEX d, suv, texture[0], 2D;
MAD acc.x, d.x, w.x, acc.x;
ADD acc.y, acc.y, w.x;

# +Y tap.
ADD suv.xy, uv, program.env[20].yyyy;
MUL sdv.xy, suv, program.env[19].xyxy;
TEX d, sdv, texture[7], 2D;
SUB w.x, d.x, dc.x;
ABS w.x, w.x;
SLT w.x, w.x, program.env[19].z;
TEX d, suv, texture[0], 2D;
MAD acc.x, d.x, w.x, acc.x;
ADD acc.y, acc.y, w.x;

# -Y tap.
SUB suv.xy, uv, program.env[20].yyyy;
MUL sdv.xy, suv, program.env[19].xyxy;
TEX d, sdv, texture[7], 2D;
SUB w.x, d.x, dc.x;
ABS w.x, w.x;
SLT w.x, w.x, program.env[19].z;
TEX d, suv, texture[0], 2D;
MAD acc.x, d.x, w.x, acc.x;
ADD acc.y, acc.y, w.x;

RCP vis.x, acc.y;
MUL vis.x, vis.x, acc.x;
MUL color, color, vis.x;
MUL result.color, color, fragment.color;
END
