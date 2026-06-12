// DEEP_SPACE_TRANSIT — Cold, sparse, distant
// Near-black void, very sparse stars, small ship, exhaust glow the brightest thing
// Palette: DEEP_SPACE — #000010, #191970, #C0C0C0, #FF6B35
// u_exhaust_brightness: 2.8 | u_gas_giant_fill: 0.0 | u_chrome_intensity: 0.70

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
float hash11(float p) { return fract(sin(p * 127.1) * 43758.5453); }

float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1,0)), f.x),
               mix(hash21(i + vec2(0,1)), hash21(i + vec2(1,1)), f.x), f.y);
}

// Very sparse starfield — not evenly distributed, slight clustering
vec3 deepStarfield(vec2 uv) {
    vec3 col = vec3(0.0);

    // Layer 1: large bright sparse stars
    vec2 g1 = floor(uv * 35.0);
    float s1 = step(0.996, hash21(g1));
    float b1 = hash21(g1 + 0.5) * 0.7 + 0.3;
    // Slight twinkle
    float tw1 = 0.9 + 0.1 * sin(u_time * (2.0 + hash21(g1) * 3.0) + hash21(g1 + 1.0) * 6.28);
    col += vec3(0.92, 0.95, 1.0) * s1 * b1 * tw1;

    // Layer 2: medium dim stars
    vec2 g2 = floor(uv * 90.0);
    float s2 = step(0.985, hash21(g2 + 10.0));
    float b2 = hash21(g2 + 11.0) * 0.4;
    col += vec3(0.75, 0.80, 0.85) * s2 * b2;

    // Layer 3: barely visible dust (galactic plane hint)
    float dust = noise(uv * 1.5 + vec2(0.3, 0.1)) * 0.025;
    col += vec3(0.05, 0.06, 0.10) * dust;

    return col;
}

// HDR exhaust plume — cone SDF + noise displacement + multiple layers
vec3 exhaustHDR(vec2 p, float t, float brightness) {
    // Cone extends in -x direction from ship tail
    float coneLen = -p.x;
    if (coneLen < 0.0) return vec3(0.0);

    float coneSpread = coneLen * 0.28;
    float coneWidth = smoothstep(coneSpread + 0.015, coneSpread - 0.005, abs(p.y));

    // Noise displacement for turbulence
    float turb = noise(vec2(coneLen * 12.0 - t * 5.0, abs(p.y) * 8.0 + t * 3.0));
    coneWidth *= 0.7 + 0.3 * turb;

    // Core — #FFFACD / white-hot inner
    float core = smoothstep(0.025, 0.0, abs(p.y)) *
                 smoothstep(0.18, 0.0, coneLen);
    core *= (0.85 + 0.15 * noise(vec2(t * 8.0, p.y * 15.0)));

    // Inner glow — #FFD700
    float inner = smoothstep(0.06, 0.0, abs(p.y) - coneLen * 0.08) *
                  smoothstep(0.35, 0.0, coneLen);
    inner *= (0.8 + 0.2 * noise(vec2(coneLen * 6.0 - t * 4.0, t)));

    // Outer envelope — #FF6B35
    float outer = coneWidth * smoothstep(0.5, 0.0, coneLen);
    outer *= (0.7 + 0.3 * turb);

    // Far diffuse glow haze
    float diffuse = exp(-length(p) * 3.0) * smoothstep(-0.02, 0.0, p.x);

    vec3 col = vec3(0.0);
    col += vec3(1.0, 0.98, 0.95) * core * 4.0;
    col += vec3(1.0, 0.90, 0.50) * inner * 2.5;
    col += vec3(1.0, 0.420, 0.208) * outer;
    col += vec3(0.8, 0.28, 0.05) * diffuse * 0.4;

    return col * brightness;
}

// Navigation lights — blinking
vec3 navLight(vec2 uv, vec2 pos, vec3 color, float phase, float t) {
    float d = length(uv - pos);
    float blink = step(0.5, sin(t * 2.5 + phase) * 0.5 + 0.5);
    float glow = exp(-d * 80.0) * blink;
    float point = smoothstep(0.008, 0.0, d) * blink;
    return (glow * 0.3 + point * 2.0) * color;
}

// Hull with panel detail
float hullSDF(vec2 p) {
    float hull = length(vec2(max(abs(p.x) - 0.12, 0.0), p.y)) - 0.035;
    return hull;
}

float panelLine(vec2 p, float freq) {
    vec2 g = fract(p * freq) - 0.5;
    return 1.0 - smoothstep(0.46, 0.44, max(abs(g.x), abs(g.y)));
}

void main() {
    vec2 uv = gl_FragCoord.xy / u_resolution;
    uv = uv * 2.0 - 1.0;
    uv.x *= u_resolution.x / u_resolution.y;

    float t = u_time;

    // Near-black void — #000010
    vec3 col = vec3(0.0, 0.0, 0.063);

    // Very faint nebular background in one corner
    float nebula = noise(uv * 0.8 + vec2(0.5, 0.2)) * noise(uv * 1.6) * 0.06;
    col += vec3(0.04, 0.02, 0.08) * nebula;

    // Starfield
    col += deepStarfield(uv);

    // Very distant sun — just a bright point + corona off-screen
    vec2 sunPos = vec2(1.8, 1.3);
    float sunDist = length(uv - sunPos);
    col += vec3(1.0, 0.90, 0.75) * exp(-sunDist * 2.5) * 0.12;

    // Ship — small, centered slightly right
    vec2 shipPos = vec2(0.1, 0.02);
    vec2 sp = uv - shipPos;
    float hull = hullSDF(sp);
    float hullMask = smoothstep(0.004, -0.004, hull);

    vec3 shipCol = vec3(0.0);
    if (hullMask > 0.0) {
        // Very dark — only sunlight hits upper edge
        vec2 sunDir = normalize(sunPos - shipPos);
        float lit = max(0.0, dot(normalize(sp + 0.001), sunDir));
        shipCol = mix(vec3(0.05, 0.05, 0.07), vec3(0.75, 0.73, 0.72), smoothstep(0.0, 0.6, lit));

        // Cold blue-grey from void fill (almost nothing)
        shipCol += vec3(0.05, 0.06, 0.10) * max(0.0, -lit) * 0.3;

        // Panel lines
        float panels = panelLine(sp * 35.0, 1.0) * 0.08;
        shipCol -= panels * smoothstep(0.3, 0.8, lit);

        // Racing stripe — subtle in deep space
        float stripe = step(fract(sp.x * u_stripe_frequency * 3.0), 0.25);
        shipCol = mix(shipCol, vec3(1.0, 0.271, 0.0) * lit, stripe * 0.4);
    }

    // Exhaust — the brightest thing in the scene
    vec2 exhaustOrigin = shipPos + vec2(-0.12, 0.0);
    vec2 exP = uv - exhaustOrigin;
    vec3 exhaust = exhaustHDR(exP, t, u_exhaust_brightness);

    // Navigation lights
    col += navLight(uv, shipPos + vec2(0.12, 0.035), vec3(0.3, 0.6, 1.0),  0.0, t);  // port — blue
    col += navLight(uv, shipPos + vec2(0.12, -0.035), vec3(1.0, 0.3, 0.3), 1.57, t); // starboard — red
    col += navLight(uv, shipPos + vec2(-0.11, 0.0),   vec3(1.0, 1.0, 0.8), 3.14, t); // aft — white

    // Compose
    col = mix(col, shipCol, hullMask * u_chrome_intensity);
    col += exhaust;

    // Tiny reflected exhaust glow on hull underside
    float exHullGlow = exp(-length(sp - vec2(-0.08, 0.0)) * 15.0) * u_exhaust_brightness * 0.3;
    if (hullMask > 0.0) col += vec3(0.8, 0.3, 0.05) * exHullGlow;

    // Very subtle atmosphere haze in void (u_atmosphere_haze near 0 for this regime)
    col += vec3(0.02, 0.02, 0.04) * u_atmosphere_haze * 0.2;

    // Tonemap — deep space stays very dark, exhaust stays HDR
    col = col / (col + 0.8);
    col = pow(col, vec3(1.0 / 2.2));

    gl_FragColor = vec4(col, 1.0);
}
