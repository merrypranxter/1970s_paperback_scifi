// FLEET_FORMATION — Deep formation
// Five ships in holding pattern, varied scales, parallel exhaust trails
// Racing stripe livery consistent across fleet (FOSS_CHROME palette)
// u_chrome_intensity: 0.92 | u_stripe_frequency: 9.0 | u_exhaust_brightness: 1.5

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
    for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.0; a *= 0.5; }
    return v;
}

// Fresnel for chrome
vec3 fresnel(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

// Hull SDF — elongated with angled nacelles implied by surface
float hullSDF(vec2 p, float len) {
    float body = length(vec2(max(abs(p.x) - len, 0.0), p.y)) - 0.045;
    // Notch: secondary engine pods (upper/lower bumps)
    float pod1 = length(p - vec2(-len * 0.5, 0.045)) - 0.018;
    float pod2 = length(p - vec2(-len * 0.5, -0.045)) - 0.018;
    return min(body, min(pod1, pod2));
}

// Racing stripe — #FF8C00 primary + #FF4500 secondary (fleet livery)
float raceStripe(vec2 p, float freq) {
    float s = fract(p.x * freq);
    return step(s, 0.22) + step(0.26, s) * step(s, 0.32);
}

// Chrome color with directional light
vec3 chromeColor(vec2 surfN, vec2 lightDir, float roughness) {
    float diff = max(dot(normalize(surfN), lightDir), 0.0);
    vec3 F0 = vec3(0.95, 0.93, 0.88);

    // Base: dark #1C1C5E to bright chrome
    vec3 base = mix(vec3(0.06, 0.06, 0.14), vec3(0.86, 0.85, 0.83), smoothstep(0.0, 0.8, diff));

    // Specular smear
    vec3 H = normalize(normalize(surfN) + lightDir);
    float spec = pow(max(dot(H, normalize(vec2(0.0, 1.0))), 0.0), 1.0 / (roughness * roughness + 0.01));
    vec3 F = fresnel(max(dot(H, lightDir), 0.0), F0);
    base += F * spec * 1.5;

    // Star color temperature
    base *= mix(vec3(1.0), vec3(1.0, 0.92, 0.80), 0.4);

    return base;
}

// Exhaust trail — long trailing plume for formation ships
vec3 exhaustTrail(vec2 p, float t, float len, float brightness) {
    float trailLen = max(-p.x, 0.0);
    if (trailLen > len) return vec3(0.0);

    float fade = 1.0 - trailLen / len;
    float spread = trailLen * 0.12;
    float width = smoothstep(spread + 0.012, spread - 0.003, abs(p.y));
    float turb = noise(vec2(trailLen * 8.0 - t * 4.0, abs(p.y) * 6.0 + t * 2.5));

    float core = smoothstep(0.02, 0.0, abs(p.y)) * step(0.0, -p.x) * fade;
    float outer = width * (0.7 + 0.3 * turb) * fade;

    vec3 col = vec3(1.0, 0.50, 0.12) * outer;
    col += vec3(1.0, 0.85, 0.55) * core * 1.5;
    return col * brightness;
}

// Full ship render: hull + stripe + exhaust
vec3 renderShip(vec2 uv, vec2 pos, float scale, float rot, float t,
                float brightness, float stripeFreq, float trailLen) {
    float c = cos(rot), s = sin(rot);
    vec2 p = uv - pos;
    p = vec2(p.x * c + p.y * s, -p.x * s + p.y * c);
    p /= scale;

    float hull = hullSDF(p, 0.18);
    float mask = smoothstep(0.005, -0.005, hull);

    vec3 col = vec3(0.0);

    if (mask > 0.0) {
        // Normal from SDF gradient
        vec2 e = vec2(0.002, 0.0);
        vec2 N2 = normalize(vec2(
            hullSDF(p + e.xy, 0.18) - hullSDF(p - e.xy, 0.18),
            hullSDF(p + e.yx, 0.18) - hullSDF(p - e.yx, 0.18)
        ));

        vec3 chrome = chromeColor(N2, normalize(vec2(0.55, 0.70)), 0.10);

        // Fleet livery — consistent across all ships
        float stripe = raceStripe(p, stripeFreq);
        // Primary stripe: #FF8C00, secondary: #FF4500
        vec3 stripeCol = mix(vec3(1.0, 0.549, 0.0), vec3(1.0, 0.271, 0.0),
                            step(0.25, fract(p.x * stripeFreq)));
        chrome = mix(chrome, stripeCol, stripe * 0.55);

        // Panel detail (denser at larger scale bias)
        float panelDensity = clamp(u_scale_bias * 0.03, 1.0, 4.0);
        vec2 pg = fract(p * 28.0 * panelDensity) - 0.5;
        float panel = 1.0 - smoothstep(0.44, 0.42, max(abs(pg.x), abs(pg.y)));
        chrome -= panel * 0.08 * max(0.0, N2.y);

        col = chrome * mask;
    }

    // Exhaust trail
    vec2 tailP = p - vec2(-0.18, 0.0);
    col += exhaustTrail(tailP, t, trailLen, brightness);

    // Transform back to screen-space for trail
    return col;
}

void main() {
    vec2 uv = gl_FragCoord.xy / u_resolution;
    uv = uv * 2.0 - 1.0;
    uv.x *= u_resolution.x / u_resolution.y;

    float t = u_time;

    // Space — #000010 base, slight nebular warmth
    vec3 space = vec3(0.0, 0.0, 0.063);
    float neb = fbm(uv * 1.2 + vec2(0.2, t * 0.002)) * fbm(uv * 2.5) * 0.05;
    space += vec3(0.04, 0.03, 0.08) * neb;
    // Faint warm star region (#FFD700 temperature) off upper-left
    float starDist = length(uv - vec2(-1.5, 1.2));
    space += vec3(0.6, 0.5, 0.3) * exp(-starDist * 1.8) * 0.05;

    // Stars — varied distribution (not uniform)
    float s1 = step(0.993, hash21(floor(uv * 50.0)));
    float s2 = step(0.982, hash21(floor(uv * 160.0)));
    float s3 = step(0.975, hash21(floor(uv * 350.0)));
    space += vec3(0.95, 0.97, 1.0) * s1 * hash21(uv * 50.0 + 1.0);
    space += vec3(0.75, 0.80, 0.88) * s2 * hash21(uv * 160.0 + 2.0) * 0.5;
    space += vec3(0.45, 0.50, 0.55) * s3 * hash21(uv * 350.0 + 3.0) * 0.25;

    vec3 fleet = vec3(0.0);
    float slowDrift = sin(t * 0.03) * 0.008;

    // Formation positions — chevron/V-formation with flagship lead
    // Ship 1: Flagship — largest, center, slightly forward
    fleet += renderShip(uv, vec2(-0.05 + slowDrift, 0.0), 1.0, 0.0, t,
                        u_exhaust_brightness, u_stripe_frequency, 0.5);

    // Ship 2: Left wing — medium
    fleet += renderShip(uv, vec2(0.2 + slowDrift * 0.8, 0.28), 0.55, 0.06, t,
                        u_exhaust_brightness * 0.85, u_stripe_frequency, 0.42);

    // Ship 3: Right wing — medium
    fleet += renderShip(uv, vec2(0.2 + slowDrift * 0.8, -0.28), 0.55, -0.06, t,
                        u_exhaust_brightness * 0.85, u_stripe_frequency, 0.42);

    // Ship 4: Far left — small (distant)
    fleet += renderShip(uv, vec2(0.52 + slowDrift * 0.6, 0.52), 0.30, 0.10, t,
                        u_exhaust_brightness * 0.65, u_stripe_frequency, 0.35);

    // Ship 5: Far right — small (distant)
    fleet += renderShip(uv, vec2(0.52 + slowDrift * 0.6, -0.52), 0.30, -0.10, t,
                        u_exhaust_brightness * 0.65, u_stripe_frequency, 0.35);

    vec3 col = space;
    col += fleet * u_chrome_intensity;

    // Formation scale haze — implied by atmospheric depth
    float haze = u_atmosphere_haze * fbm(uv * 3.0 + t * 0.003) * 0.12;
    col += vec3(0.04, 0.03, 0.06) * haze;

    // Star color tint on scene
    col *= mix(vec3(1.0), u_star_color, 0.08);

    // Tonemap
    col = col / (col + 1.0);
    col = pow(col, vec3(1.0 / 2.2));

    gl_FragColor = vec4(col, 1.0);
}
