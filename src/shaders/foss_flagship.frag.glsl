// FOSS_FLAGSHIP — Chris Foss chrome armada
// Multiple chrome ships with racing stripe livery, warm starlight, cold space
// Palette: FOSS_CHROME — #C0C0C0, #FF8C00, #1C1C5E, #FF4500, #FFD700
// u_chrome_intensity: 0.95 | u_stripe_frequency: 8.0 | u_exhaust_brightness: 1.8

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

// ── Noise & FBM ──────────────────────────────────────────────────────────────
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float hash11(float p) { return fract(sin(p * 127.1) * 43758.5453); }

float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1,0)), f.x),
               mix(hash21(i + vec2(0,1)), hash21(i + vec2(1,1)), f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.1; a *= 0.5; }
    return v;
}

// ── GGX Chrome BRDF ──────────────────────────────────────────────────────────
// F0 = vec3(0.95, 0.93, 0.88) for silver-chrome
vec3 fresnel(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

float ggx_d(float NdotH, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float d = NdotH * NdotH * (a2 - 1.0) + 1.0;
    return a2 / (3.14159 * d * d);
}

float smith_g(float NdotV, float NdotL, float roughness) {
    float a = roughness;
    float gv = NdotV / (NdotV * (1.0 - a) + a);
    float gl = NdotL / (NdotL * (1.0 - a) + a);
    return gv * gl;
}

vec3 chrome_brdf(vec3 N, vec3 V, vec3 L, vec3 F0, float roughness) {
    vec3 H = normalize(V + L);
    float NdotH = max(dot(N, H), 0.0);
    float NdotV = max(dot(N, V), 0.001);
    float NdotL = max(dot(N, L), 0.001);
    float D = ggx_d(NdotH, roughness);
    float G = smith_g(NdotV, NdotL, roughness);
    vec3  F = fresnel(max(dot(H, V), 0.0), F0);
    return (D * G * F) / (4.0 * NdotV * NdotL);
}

// ── Star field ───────────────────────────────────────────────────────────────
vec3 starfield(vec2 uv) {
    vec3 col = vec3(0.0);
    // Two layers: bright sparse + dim dense
    float s1 = step(0.992, hash21(floor(uv * 60.0)));
    float s2 = step(0.975, hash21(floor(uv * 200.0)));
    float b1 = hash21(uv * 60.0 + 3.7);
    float b2 = hash21(uv * 200.0 + 1.3) * 0.4;
    col += vec3(0.95, 0.97, 1.0) * s1 * b1;
    col += vec3(0.8, 0.85, 0.9) * s2 * b2;
    return col;
}

// ── Ship SDF: elongated hull ──────────────────────────────────────────────────
float shipSDF(vec2 p, float len, float rad) {
    float d = length(vec2(max(abs(p.x) - len, 0.0), p.y)) - rad;
    // nose taper
    d = max(d, p.x - len * 1.3);
    return d;
}

// ── Racing stripe + panel detail ─────────────────────────────────────────────
float racingStripe(vec2 uv, float freq) {
    return step(fract(uv.x * freq), 0.28);
}

float panelDetail(vec2 uv, float scale) {
    vec2 g = fract(uv * scale) - 0.5;
    return smoothstep(0.48, 0.45, max(abs(g.x), abs(g.y)));
}

// ── Exhaust plume ─────────────────────────────────────────────────────────────
vec3 exhaustPlume(vec2 p, float t, float brightness) {
    float cone = smoothstep(0.12, 0.0, abs(p.y) - max(0.0, -p.x) * 0.35);
    float core = smoothstep(0.05, 0.0, abs(p.y) + p.x * 0.1);
    float flicker = 0.85 + 0.15 * noise(vec2(p.x * 8.0 + t * 4.0, t * 6.0));
    vec3 outer = vec3(1.0, 0.42, 0.08) * cone * flicker;
    vec3 inner = vec3(1.0, 0.85, 0.6) * core * flicker * 2.0;
    return (outer + inner) * brightness;
}

// ── Single ship at position ────────────────────────────────────────────────────
vec3 renderShip(vec2 uv, vec2 pos, float scale, float rot, float t, float brightness, float stripeFreq) {
    float c = cos(rot), s = sin(rot);
    vec2 p = uv - pos;
    p = vec2(p.x * c + p.y * s, -p.x * s + p.y * c);
    p /= scale;

    float hull = shipSDF(p, 0.22, 0.06);
    if (hull > 0.1) return vec3(0.0);

    float mask = smoothstep(0.005, -0.005, hull);

    // Normal approximation from SDF gradient
    vec2 eps = vec2(0.001, 0.0);
    vec2 N2 = normalize(vec2(
        shipSDF(p + eps.xy, 0.22, 0.06) - shipSDF(p - eps.xy, 0.22, 0.06),
        shipSDF(p + eps.yx, 0.22, 0.06) - shipSDF(p - eps.yx, 0.22, 0.06)
    ));
    vec3 N3 = normalize(vec3(N2, 0.5));
    vec3 V = normalize(vec3(0.0, 0.0, 1.0));
    vec3 L = normalize(vec3(0.6, 0.8, 0.4));

    // Chrome BRDF — roughness 0.08 for near-mirror
    vec3 F0 = vec3(0.95, 0.93, 0.88);
    vec3 spec = chrome_brdf(N3, V, L, F0, 0.08);
    float diff = max(dot(N3, L), 0.0);

    // Base chrome color + airbrush shadow
    vec3 chrome = mix(vec3(0.15, 0.16, 0.22), vec3(0.88, 0.87, 0.85), smoothstep(-0.3, 0.5, dot(N3, L)));
    chrome += spec * 3.0;

    // Racing stripes — #FF8C00 + #FF4500
    float stripe = racingStripe(p, stripeFreq);
    vec3 stripeCol = mix(vec3(1.0, 0.549, 0.0), vec3(1.0, 0.271, 0.0), p.x * 0.5 + 0.5);
    chrome = mix(chrome, stripeCol, stripe * 0.55);

    // Panel detail
    float panels = panelDetail(p * 40.0, 1.0) * 0.12;
    chrome -= panels;

    // Planet-reflected fill (cool blue-grey from below)
    chrome += vec3(0.1, 0.13, 0.25) * max(0.0, -N3.y) * 0.4;

    // Exhaust
    vec2 exP = p - vec2(-0.22, 0.0);
    vec3 ex = exhaustPlume(exP, t, brightness);
    chrome += ex;

    return chrome * mask;
}

// ── Main ──────────────────────────────────────────────────────────────────────
void main() {
    vec2 uv = gl_FragCoord.xy / u_resolution;
    uv = uv * 2.0 - 1.0;
    uv.x *= u_resolution.x / u_resolution.y;

    float t = u_time;

    // Space — #000010 → #1C1C5E gradient toward star
    vec3 space = mix(vec3(0.0, 0.0, 0.063), vec3(0.11, 0.11, 0.369), smoothstep(-1.2, 0.8, uv.y));
    space += starfield(uv) * vec3(u_star_color);

    // Distant nebula wisp
    float neb = fbm(uv * 1.8 + vec2(0.3, t * 0.003)) * 0.07;
    space += vec3(0.12, 0.08, 0.25) * neb;

    // Fleet — five ships: flagship center-left, four escorts
    // Ships move very slowly (parallax drift)
    vec3 fleet = vec3(0.0);
    float drift = sin(t * 0.04) * 0.015;

    // Flagship — largest, center-left
    fleet += renderShip(uv, vec2(-0.35 + drift, 0.05), 1.0, 0.0, t, u_exhaust_brightness, u_stripe_frequency);
    // Escort 1 — upper right
    fleet += renderShip(uv, vec2(0.5 + drift * 0.7, 0.35), 0.45, 0.08, t, u_exhaust_brightness * 0.7, u_stripe_frequency);
    // Escort 2 — lower right, further away (smaller)
    fleet += renderShip(uv, vec2(0.65 + drift * 0.5, -0.2), 0.3, -0.05, t, u_exhaust_brightness * 0.6, u_stripe_frequency);
    // Escort 3 — far upper left, tiny
    fleet += renderShip(uv, vec2(-0.75 + drift * 0.8, 0.55), 0.22, 0.12, t, u_exhaust_brightness * 0.5, u_stripe_frequency);
    // Escort 4 — far right, very small
    fleet += renderShip(uv, vec2(0.9 + drift * 0.3, 0.1), 0.18, -0.03, t, u_exhaust_brightness * 0.4, u_stripe_frequency);

    // Starlight tint — warm orange-yellow from upper right (#FFD700 direction)
    vec3 starTint = u_star_color * smoothstep(0.6, 1.4, length(uv - vec2(1.2, 1.0)) * (-1.0) + 1.4);
    space += starTint * 0.04;

    vec3 col = space;
    col += fleet * u_chrome_intensity;

    // Atmospheric haze across fleet (implied scale)
    float haze = u_atmosphere_haze * fbm(uv * 2.5 + t * 0.005) * 0.15;
    col += vec3(0.05, 0.04, 0.08) * haze;

    // Tonemap (Reinhard)
    col = col / (col + 1.0);
    col = pow(col, vec3(1.0 / 2.2));

    gl_FragColor = vec4(col, 1.0);
}
