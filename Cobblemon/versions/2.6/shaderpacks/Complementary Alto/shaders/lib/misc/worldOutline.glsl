vec2 worldOutlineOffset[4] = vec2[4] (
    vec2(-1.0, 1.0),
    vec2( 0,   1.0),
    vec2( 1.0, 1.0),
    vec2( 1.0, 0)
);

void DoWorldOutline(inout vec3 color, float linearZ0, vec3 playerPos, float fresnel, float dither) {
    #ifdef ENTITIES_ARE_LIGHT
        #define WORLD_OUTLINE_THICKNESS_M 4
    #else
        #define WORLD_OUTLINE_THICKNESS_M WORLD_OUTLINE_THICKNESS
    #endif

    #ifndef WORLD_OUTLINE_SCALED
        vec2 scale = vec2(1.0 / view);
    #else
        float scm = 0.005;
        float fovScale = gbufferProjection[1][1];
        float distScale = max((far - near) * linearZ0 + near, 3.0);
        vec2 scale = vec2(scm / aspectRatio, scm) * fovScale / distScale;
        scale *= 0.99 + 0.2 * dither;
    #endif

    // Fix screen edges
    vec2 texCoordDirection = sign(texCoord - vec2(0.5));
    vec2 checkCoord = texCoord + scale * vec2(texCoordDirection.x * WORLD_OUTLINE_THICKNESS_M, texCoordDirection.y * WORLD_OUTLINE_THICKNESS_M);
    vec2 absCheckCoord = abs(checkCoord - vec2(0.5));
    float outlineMult = max0(0.5 - max(absCheckCoord.x, absCheckCoord.y));
          outlineMult = min1(outlineMult * 0.1 / (scale.x * WORLD_OUTLINE_THICKNESS_M));

    #if defined DISTANT_HORIZONS || defined VOXY
        float horizontalDistance = length(playerPos.xz);
        float verticalDistance = abs(playerPos.y);
        float fadeEndistance = max(horizontalDistance, verticalDistance);

        #ifdef DISTANT_HORIZONS
            float farM = far * 0.8;
        #else
            float farM = far * 0.95;
        #endif
        float fade = smoothstep(far * 0.4, farM, fadeEndistance);

        outlineMult *= 1.0 - fade;
    #endif

    if (outlineMult < 0.0001) return;

    #ifdef PBR_REFLECTIONS
        outlineMult *= 0.25;

        float d0 = GetLinearDepth(texture2D(depthtex0, texCoord + vec2(-WORLD_OUTLINE_THICKNESS_M, -WORLD_OUTLINE_THICKNESS_M) * scale).r);
        float d1 = GetLinearDepth(texture2D(depthtex0, texCoord + vec2(-WORLD_OUTLINE_THICKNESS_M,  WORLD_OUTLINE_THICKNESS_M) * scale).r);
        float d2 = GetLinearDepth(texture2D(depthtex0, texCoord + vec2( WORLD_OUTLINE_THICKNESS_M, -WORLD_OUTLINE_THICKNESS_M) * scale).r);
        float d3 = GetLinearDepth(texture2D(depthtex0, texCoord + vec2( WORLD_OUTLINE_THICKNESS_M,  WORLD_OUTLINE_THICKNESS_M) * scale).r);
        float dA = 0.25 * (d0 + d1 + d2 + d3);
        float slope = dA - linearZ0;

        float threshold = linearZ0 / 2000.0 * WORLD_OUTLINE_THICKNESS_M;

        outlineMult *= 1.0 - 0.9 * pow2(fresnel);

        float outline = clamp(slope / threshold, 0.0, 1.0) * WORLD_OUTLINE_I;
    #else
        float outlines[2] = float[2] (0.0, 0.0);
        float outlined = 1.0;
        float z = linearZ0 * far;
        float totalz = 0.0;
        float maxz = 0.0;
        float sampleza = 0.0;
        float samplezb = 0.0;

        #if PIXELATED_SCREEN_SIZE > 0
            int sampleCount = WORLD_OUTLINE_THICKNESS_M * 4 + abs(9 - int(PIXELATED_SCREEN_SIZE_INTERNAL * 0.1));
        #else
            int sampleCount = WORLD_OUTLINE_THICKNESS_M * 4;
        #endif

        for (int i = 0; i < sampleCount; i++) {
            vec2 offset = (1.0 + floor(i / 4.0)) * scale * worldOutlineOffset[int(mod(float(i), 4))];
            float depthCheckP = GetLinearDepth(texture2D(depthtex0, texCoord + offset).r) * far;
            float depthCheckN = GetLinearDepth(texture2D(depthtex0, texCoord - offset).r) * far;

            outlined *= clamp(1.0 - ((depthCheckP + depthCheckN) - z * 2.0) * 32.0 / z, 0.0, 1.0);

            if (i <= 4) maxz = max(maxz, max(depthCheckP, depthCheckN));
            totalz += depthCheckP + depthCheckN;
        }

        float outlinea = 1.0 - clamp((z * 8.0 - totalz) * 64.0 / z, 0.0, 1.0) * clamp(1.0 - ((z * 8.0 - totalz) * 32.0 - 1.0) / z, 0.0, 1.0);
        float outlineb = clamp(1.0 + 8.0 * (z - maxz) / z, 0.0, 1.0);
        float outlinec = clamp(1.0 + 64.0 * (z - maxz) / z, 0.0, 1.0);

        float outline = (0.35 * (outlinea * outlineb) + 0.65) * (0.75 * (1.0 - outlined) * outlinec + 1.0);
        outline -= 1.0;

        outline *= WORLD_OUTLINE_I / WORLD_OUTLINE_THICKNESS_M;
        if (outline < 0.0) outline = -outline * 0.25;
    #endif

    outline *= outlineMult;

    #if RETRO_LOOK == 1
        color = outline * 10.0 * vec3(RETRO_LOOK_R, RETRO_LOOK_G, RETRO_LOOK_B) * RETRO_LOOK_I;
    #elif RETRO_LOOK == 2
        color = mix(color, outline * 10.0 * vec3(RETRO_LOOK_R, RETRO_LOOK_G, RETRO_LOOK_B) * RETRO_LOOK_I, nightVision);
    #else
        color += min(color * outline, vec3(outline));
    #endif
}
