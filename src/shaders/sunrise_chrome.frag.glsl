// SUNRISE_CHROME — Dawn on the hull
// Ships in full orange sunrise light, chrome surfaces blazing
// Palette: SUNRISE_CHROME — #FF4500, #FF8C00, #FFD700, #FFFACD, #C0C0C0
// u_chrome_intensity: 1.00 | u_exhaust_brightness: 2.2 | u_stripe_frequency: 7.0

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

// Fresnel-Schlick for F0
vec3 fresnel(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

// Blown-out specular smear — anisotropic along horizontal axis
// This is the Foss signature: a horizontal smear, not a point
float specularSmear(vec2 p, vec2 L2, float roughness) {
    vec2 H = normalize(L2 + vec2(0.0, 1.0));
    // Anisotropy: wide along x, tight along y
    float ax = roughness * 4.0;
    float ay = roughness * 0.5;
    float spec = exp(-(H.x * H.x / (ax * ax) + H.y * H.y / (ay * ay)));
    return spec;
}

// Ship hull SDF
float shipHullSDF(vec2 p, float len, float rad) {
    // Capsule hull
    float d = length(vec2(max(abs(p.x) - len, 0.0), p.y)) - rad;
    // Nose taper: chamfer the bow
    float noseTaper = p.x - len * 1.1 - p.y * p.y * 3.0;
    return max(d, noseTaper * 0.3);
}

// Racing stripes — SUNRISE_CHROME: orange + gold
vec3 racingStripes(vec2 p, float freq) {
    float s = fract(p.x * freq);
    float s1 = step(s, 0.20);  // #FF4500 stripe
    float s2 = step(0.25, s) * step(s, 0.38); // #FFD700 stripe
    vec3 col = vec3(0.0);
    col += vec3(1.0, 0.271, 0.0) * s1;   // #FF4500
    col += vec3(1.0, 0.843, 0.0) * s2;   // #FFD700
    return col;
}

// Panel detail at high-scale
float panelGrid(vec2 p, float freq) {
    vec2 g = fract(p * freq) - 0.5;
    return 1.0 - smoothstep(0.44, 0.42, max(abs(g.x), abs(g.y)));
}

// Sunrise gradient background
vec3 sunriseBackground(vec2 uv, float t) {
    // Star (off right edge, low — a rising sun)
    vec2 sunPos = vec2(1.6, -0.6);
    float sunDist = length(uv - sunPos);

    // Sky gradient: black → deep red → orange → gold at horizon
    vec3 voidCol = vec3(0.0, 0.0, 0.04);
    vec3 fireCol = vec3(1.0, 0.271, 0.0);   // #FF4500
    vec3 amberCol = vec3(1.0, 0.549, 0.0);  // #FF8C00
    vec3 goldCol  = vec3(1.0, 0.843, 0.0);  // #FFD700

    float horizonDist = length(uv - sunPos) / 2.5;
    vec3 bg = mix(goldCol, amberCol, smoothstep(0.0, 0.4, horizonDist));
    bg = mix(bg, fireCol, smoothstep(0.3, 0.8, horizonDist));
    bg = mix(bg, voidCol, smoothstep(0.6, 1.4, horizonDist));

    // Solar disc — blown out
    float disc = exp(-sunDist * 8.0);
    bg += vec3(1.0, 0.98, 0.90) * disc * 2.0;

    // God rays / volumetric light
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float angle = fi * 0.6 + 0.3;
        vec2 rayDir = normalize(uv - sunPos);
        vec2 refDir = vec2(cos(angle), sin(angle));
        float ray = max(0.0, 1.0 - abs(dot(rayDir, normalize(refDir))) * 4.0);
        ray = pow(ray, 3.0) * exp(-sunDist * 1.5);
        bg += vec3(1.0, 0.65, 0.15) * ray * 0.15;
    }

    // Sparse stars only in upper-left void
    float starMask = smoothstep(0.5, 1.2, horizonDist);
    float stars = step(0.994, hash21(floor(uv * 60.0))) * starMask;
    bg += vec3(0.9, 0.95, 1.0) * stars * hash21(uv * 60.0 + 3.0) * 0.6;

    return bg;
}

// Chrome material lit by sunrise
vec3 sunriseChrome(vec2 hullUV, vec2 surfUV, float t) {
    vec2 sunPos = vec2(1.6, -0.6);
    vec2 L2 = normalize(sunPos - hullUV);

    // Base chrome — #C0C0C0
    vec3 F0 = vec3(0.95, 0.93, 0.88);
    float cosTheta = max(dot(normalize(surfUV + 0.001), L2), 0.0);
    vec3 F = fresnel(cosTheta, F0);

    // Diffuse + ambient
    float diff = max(0.0, cosTheta);
    vec3 chrome = mix(vec3(0.06, 0.04, 0.03), vec3(0.78, 0.76, 0.74),
                      smoothstep(0.0, 0.8, diff));

    // Sunrise color bleeds onto chrome — this is the money shot
    // Lit face picks up #FFD700 / #FF8C00
    vec3 sunTint = mix(vec3(1.0, 0.843, 0.0), vec3(1.0, 0.549, 0.0),
                       smoothstep(0.3, 0.8, diff));
    chrome = mix(chrome, chrome * sunTint * 1.4, diff * diff);

    // Specular smear — blown-out horizontal streak (#FFFACD)
    float smear = specularSmear(surfUV, L2, 0.12);
    chrome += vec3(1.0, 0.98, 0.90) * smear * 2.5; // #FFFACD → blown out

    // Shadow side: deep red-black (#FF4500 reflected from space glow)
    chrome += vec3(0.25, 0.06, 0.01) * max(0.0, 1.0 - diff) * 0.5;

    return chrome;
}

void main() {
    vec2 uv = gl_FragCoord.xy / u_resolution;
    uv = uv * 2.0 - 1.0;
    uv.x *= u_resolution.x / u_resolution.y;

    float t = u_time;

    vec3 col = sunriseBackground(uv, t);

    // Primary ship — large, center-left
    vec2 ship1Pos = vec2(-0.3, 0.1);
    float ship1Scale = 0.95;
    vec2 s1UV = (uv - ship1Pos) / ship1Scale;
    float h1 = shipHullSDF(s1UV, 0.25, 0.065);
    float m1 = smoothstep(0.005, -0.005, h1);

    if (m1 > 0.0) {
        vec3 ch = sunriseChrome(uv - ship1Pos, s1UV, t);
        // Racing stripes — #FF4500 + #FFD700
        vec3 stripes = racingStripes(s1UV, u_stripe_frequency);
        ch = mix(ch, mix(ch, stripes * 1.3, 0.6), step(0.01, length(stripes)));
        // Panel detail
        float pd = panelGrid(s1UV * 30.0, 1.0) * 0.1 * max(0.0, dot(normalize(s1UV + 0.001), normalize(vec2(1.6, -0.6) - (uv - ship1Pos))));
        ch -= pd;
        col = mix(col, ch, m1 * u_chrome_intensity);
    }

    // Exhaust — #FF4500 HDR (brighter than background sunrise)
    vec2 ex1P = uv - (ship1Pos + vec2(-0.25 * ship1Scale, 0.0));
    float ex1Cone = smoothstep(0.3, 0.0, length(vec2(max(-ex1P.x, 0.0), ex1P.y * 3.5)));
    float ex1Core = smoothstep(0.1, 0.0, length(ex1P));
    float ex1Flicker = 0.85 + 0.15 * noise(vec2(ex1P.x * 10.0 + t * 5.0, t * 4.0));
    col += vec3(1.0, 0.50, 0.12) * ex1Cone * ex1Flicker * u_exhaust_brightness;
    col += vec3(1.0, 0.90, 0.60) * ex1Core * u_exhaust_brightness * 1.5;

    // Second ship — smaller, upper right, in hot light
    vec2 ship2Pos = vec2(0.6, 0.35);
    float ship2Scale = 0.42;
    vec2 s2UV = (uv - ship2Pos) / ship2Scale;
    // Slight rotation
    float c2 = cos(0.15), ss2 = sin(0.15);
    s2UV = vec2(s2UV.x * c2 + s2UV.y * ss2, -s2UV.x * ss2 + s2UV.y * c2);
    float h2 = shipHullSDF(s2UV, 0.25, 0.065);
    float m2 = smoothstep(0.005, -0.005, h2);

    if (m2 > 0.0) {
        vec3 ch2 = sunriseChrome(uv - ship2Pos, s2UV, t);
        vec3 stripes2 = racingStripes(s2UV, u_stripe_frequency);
        ch2 = mix(ch2, mix(ch2, stripes2 * 1.3, 0.6), step(0.01, length(stripes2)));
        col = mix(col, ch2, m2 * u_chrome_intensity);
    }

    // Atmospheric scattering haze from planet-reflected light (warm)
    float haze = u_atmosphere_haze * fbm(uv * 2.0 + t * 0.004) * 0.12;
    col += vec3(0.4, 0.15, 0.02) * haze;

    // Tonemap — allow sunrise to bloom slightly
    col = col / (col + 0.9);
    col = pow(col, vec3(1.0 / 2.2));

    gl_FragColor = vec4(col, 1.0);
}
