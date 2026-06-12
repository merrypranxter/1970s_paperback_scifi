// BERKEY_EPIC — John Berkey warm epic
// Single massive ship, warm amber/gold light, escorts tiny for scale
// Palette: BERKEY_WARM — #8B4513, #DAA520, #1C1C1C, #FF6347
// u_chrome_intensity: 0.80 | u_scale_bias: 800.0 | u_exhaust_brightness: 0.8

precision highp float;
uniform float u_time;
uniform vec2  u_resolution;
uniform float u_chrome_intensity;
uniform float u_scale_bias;
uniform float u_gas_giant_fill;
uniform float u_exhaust_brightness;
uniform vec3  u_star_color;
uniform float u_atmosphere_haze;
uniform float u_stripe_frequency;

float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1,0)), f.x),
               mix(hash21(i + vec2(0,1)), hash21(i + vec2(1,1)), f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 6; i++) { v += a * noise(p); p *= 2.0; a *= 0.5; }
    return v;
}

// Anisotropic specular — smear along ship long axis (Berkey style: wide highlight)
float anisoSpec(vec2 surfUV, vec3 lightDir) {
    vec2 t = normalize(vec2(1.0, 0.0)); // tangent = ship axis
    float sinTL = length(cross(vec3(t, 0.0), lightDir));
    return pow(max(0.0, 1.0 - sinTL), 6.0); // wide blown-out lobe
}

// Painterly stroke noise — slight texture to imply brushwork without showing it
float brushNoise(vec2 p) {
    float n = noise(p * 3.0) * 0.5 + noise(p * 7.0) * 0.3 + noise(p * 15.0) * 0.2;
    return n;
}

// Atmosphere haze depth cue on very large objects — exp falloff
float scaleHaze(float dist, float density) {
    return 1.0 - exp(-dist * density);
}

// SDF: massive rectangular-ish hull (slab ship Berkey style)
float shipSDF(vec2 p) {
    // Main slab
    vec2 b = vec2(0.65, 0.13);
    vec2 q = abs(p) - b;
    float slab = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);

    // Upper superstructure
    vec2 sp = p - vec2(0.15, 0.0);
    vec2 sb = vec2(0.25, 0.07);
    vec2 sq = abs(sp) - sb;
    float superstructure = length(max(sq, 0.0)) + min(max(sq.x, sq.y), 0.0);

    // Fore section taper
    float taper = p.x - 0.58;

    return min(slab, superstructure);
}

// Escort ship (tiny, implied scale)
float escortSDF(vec2 p) {
    float d = length(vec2(max(abs(p.x) - 0.04, 0.0), p.y)) - 0.015;
    return d;
}

// Docking bay rows — civilization-level engineering
float dockingBays(vec2 p, float freq) {
    vec2 g = fract(p * freq) - 0.5;
    float rows = smoothstep(0.48, 0.46, abs(g.y));
    float bays = smoothstep(0.45, 0.43, abs(g.x));
    return rows * bays * 0.3;
}

void main() {
    vec2 uv = gl_FragCoord.xy / u_resolution;
    uv = uv * 2.0 - 1.0;
    uv.x *= u_resolution.x / u_resolution.y;

    float t = u_time;

    // Black space — #1C1C1C
    vec3 space = vec3(0.07, 0.07, 0.07);
    // Very sparse stars (Berkey — dark palette)
    float stars = step(0.994, hash21(floor(uv * 80.0)));
    space += vec3(0.8, 0.82, 0.78) * stars * hash21(uv * 100.0 + 2.0) * 0.6;

    // Warm amber light source off upper-left — #DAA520 → #FF6347
    vec2 lightPos = vec2(-1.4, 1.1);
    float lightDist = length(uv - lightPos);
    vec3 ambientWarm = mix(vec3(0.855, 0.647, 0.125), vec3(1.0, 0.388, 0.278),
                          smoothstep(0.5, 2.5, lightDist)) * 0.08;
    space += ambientWarm;

    // Painterly volume light rays from off-screen star
    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        float angle = fi * 0.52 + 0.1;
        vec2 rayDir = normalize(uv - lightPos);
        float ray = smoothstep(0.04, 0.0, abs(dot(normalize(uv - lightPos), vec2(cos(angle + t*0.002), sin(angle + t*0.002)))) - 0.0);
        space += vec3(0.855, 0.647, 0.125) * ray * (1.0 / lightDist) * 0.015;
    }

    // Massive ship — roughly centered, slightly left
    vec2 shipCenter = vec2(-0.1, 0.0);
    float shipScale = 0.9;
    vec2 sp = (uv - shipCenter) / shipScale;

    float hull = shipSDF(sp);
    float hullMask = smoothstep(0.006, -0.006, hull);

    vec3 shipCol = vec3(0.0);
    if (hullMask > 0.0) {
        // Lit by warm amber from upper-left — #8B4513 shadow, #DAA520 lit face
        vec2 L2 = normalize(lightPos - (uv - shipCenter));
        float diff = smoothstep(-0.2, 0.8, L2.y * 0.6 + L2.x * 0.4);
        // Airbrush gradient — wide smoothstep knee, aching smoothness
        vec3 litFace   = mix(vec3(0.855, 0.647, 0.125), vec3(0.95, 0.80, 0.50), diff);
        vec3 shadowFace = vec3(0.18, 0.10, 0.05);
        vec3 baseCol = mix(shadowFace, litFace, smoothstep(0.1, 0.9, diff));

        // Painterly texture — brushNoise for slight surface variation
        float brush = brushNoise(sp * 6.0 + t * 0.002) * 0.08;
        baseCol += brush * 0.15 * vec3(1.0, 0.8, 0.5);

        // Anisotropic specular smear along hull axis
        vec3 Ld = normalize(vec3(L2, 0.6));
        float aSpec = anisoSpec(sp, Ld) * 2.5;
        baseCol += vec3(1.0, 0.92, 0.75) * aSpec;

        // Docking bays / surface engineering detail
        float bays = dockingBays(sp, 18.0 * u_scale_bias * 0.001 + 1.0);
        baseCol -= bays * 0.2;

        // Scale atmosphere haze (ship so large it hazes at edges)
        float edgeDist = abs(hull) / 0.15;
        float haze = scaleHaze(edgeDist, u_atmosphere_haze * 2.0);
        baseCol = mix(baseCol, space + ambientWarm, haze * u_atmosphere_haze * 0.5);

        shipCol = baseCol;
    }

    // Escort ships — very small, implies flagship scale
    vec3 escorts = vec3(0.0);
    vec2 e1pos = vec2(0.8, 0.28);
    vec2 e2pos = vec2(0.9, -0.15);
    float e1 = escortSDF(uv - e1pos);
    float e2 = escortSDF(uv - e2pos);
    escorts += smoothstep(0.002, -0.002, e1) * vec3(0.6, 0.5, 0.35);
    escorts += smoothstep(0.002, -0.002, e2) * vec3(0.6, 0.5, 0.35);

    // Exhaust from flagship — barely visible from this scale, just a warm glow
    float exLen = smoothstep(0.0, 0.4, -(uv.x - shipCenter.x + 0.72));
    float exWidth = smoothstep(0.04, 0.0, abs(uv.y - shipCenter.y) - exLen * 0.03);
    float exFlicker = 0.9 + 0.1 * noise(vec2(uv.x * 20.0 + t * 3.0, t * 4.0));
    vec3 exGlow = vec3(0.855, 0.50, 0.12) * exLen * exWidth * exFlicker * u_exhaust_brightness;

    vec3 col = space;
    col += escorts;
    col = mix(col, shipCol, hullMask * u_chrome_intensity);
    col += exGlow;

    // Final warm grade — Berkey's signature amber atmosphere
    col = mix(col, col * vec3(1.08, 0.92, 0.75), 0.3);

    // Tonemap
    col = col / (col + 1.0);
    col = pow(col, vec3(1.0 / 2.2));

    gl_FragColor = vec4(col, 1.0);
}
