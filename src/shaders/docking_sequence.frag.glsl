// DOCKING_SEQUENCE — Interior/exterior threshold
// Two ships at civilization-scale engineering, docking lights in sequence
// Palette: FOSS_CHROME + BERKEY_WARM — interior warm, exterior cold
// u_chrome_intensity: 0.90 | u_scale_bias: 600.0 | u_exhaust_brightness: 0.5

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
    for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.1; a *= 0.5; }
    return v;
}

// Docking light pulse — sequential along approach vector
float dockLight(vec2 uv, vec2 pos, float size, float phase, float t) {
    float d = length(uv - pos) - size;
    float pulse = smoothstep(1.0, -1.0, sin(t * 3.0 - phase));
    return smoothstep(0.0, -0.006, d) * pulse;
}

// Interior light grid — rows of warm lit portholes/windows
vec3 interiorLights(vec2 p, vec2 hullBounds, float t) {
    vec3 col = vec3(0.0);
    // Grid of portholes
    vec2 g = fract(p * vec2(22.0, 8.0)) - 0.5;
    float porthole = smoothstep(0.2, 0.12, length(g));
    // Each porthole has independent flicker probability
    float lightID = hash21(floor(p * vec2(22.0, 8.0)));
    float on = step(0.15, lightID); // 85% lit
    float flicker = 0.92 + 0.08 * sin(t * (3.0 + lightID * 5.0) + lightID * 6.28);
    // Warm interior light — #DAA520 / #FF6347 mix
    vec3 warmLight = mix(vec3(0.855, 0.647, 0.125), vec3(1.0, 0.388, 0.278), lightID);
    col += warmLight * porthole * on * flicker * 1.5;
    return col;
}

// Main hull SDF — large station/carrier
float stationHullSDF(vec2 p) {
    // Main body: wide rectangular slab
    vec2 b = vec2(0.8, 0.22);
    vec2 q = abs(p) - b;
    float body = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);

    // Docking collar: protruding cylinder on right side
    vec2 collarP = p - vec2(0.75, 0.0);
    float collar = length(collarP) - 0.07;

    // Upper tower
    vec2 towerP = p - vec2(0.1, 0.22);
    vec2 tb = vec2(0.15, 0.12);
    vec2 tq = abs(towerP) - tb;
    float tower = length(max(tq, 0.0)) + min(max(tq.x, tq.y), 0.0);

    return min(min(body, collar), tower);
}

// Approaching ship SDF
float approachShipSDF(vec2 p) {
    float d = length(vec2(max(abs(p.x) - 0.09, 0.0), p.y)) - 0.025;
    return d;
}

// Panel lines and surface detail
float surfaceDetail(vec2 p, float density) {
    float d = 0.0;
    // Horizontal lines (hull plating rows)
    d += step(fract(p.y * density), 0.05) * 0.4;
    // Vertical dividers (less frequent)
    d += step(fract(p.x * density * 0.3), 0.04) * 0.2;
    return d * 0.12;
}

void main() {
    vec2 uv = gl_FragCoord.xy / u_resolution;
    uv = uv * 2.0 - 1.0;
    uv.x *= u_resolution.x / u_resolution.y;

    float t = u_time;

    // Cold space background — #000010 to #191970
    vec3 space = mix(vec3(0.0, 0.0, 0.063), vec3(0.04, 0.04, 0.12),
                     smoothstep(-1.0, 1.0, uv.x));

    // Stars — slightly denser near station (reflected light scatter)
    float s1 = step(0.993, hash21(floor(uv * 55.0)));
    float s2 = step(0.980, hash21(floor(uv * 180.0)));
    space += vec3(0.88, 0.90, 0.95) * s1 * hash21(uv * 55.0 + 7.0);
    space += vec3(0.65, 0.68, 0.75) * s2 * hash21(uv * 180.0 + 8.0) * 0.4;

    // Station — fills left-center of frame (very large)
    vec2 stationPos = vec2(-0.15, 0.0);
    vec2 sp = uv - stationPos;
    float stationHull = stationHullSDF(sp);
    float stationMask = smoothstep(0.006, -0.006, stationHull);

    vec3 stationCol = vec3(0.0);
    if (stationMask > 0.0) {
        // Exterior: cold chrome lit by distant star
        vec3 L = normalize(vec3(0.5, 0.7, 0.4));
        vec2 N2 = normalize(sp + 0.001);
        float diff = max(0.0, N2.x * L.x + N2.y * L.y);
        stationCol = mix(vec3(0.08, 0.08, 0.12), vec3(0.78, 0.77, 0.75),
                        smoothstep(-0.1, 0.7, diff));

        // Racing stripe — horizontal band
        float stripe = step(fract((sp.y + 0.1) * u_stripe_frequency * 0.8), 0.22);
        stationCol = mix(stationCol, vec3(1.0, 0.549, 0.0), stripe * diff * 0.4);

        // Surface engineering detail
        float detail = surfaceDetail(sp, 22.0 * clamp(u_scale_bias * 0.001, 0.5, 3.0));
        stationCol -= detail;

        // Interior lights visible through portholes
        vec3 interior = interiorLights(sp + vec2(0.15, 0.22), vec2(0.8, 0.22), t);
        // Only on dark (shadow) side — interior more visible when hull in shadow
        stationCol += interior * smoothstep(0.5, 0.1, diff) * 0.8;
        // Warm interior bleed onto hull edge near windows
        stationCol += interior * 0.15;

        // Cool blue fill from space side
        stationCol += vec3(0.06, 0.08, 0.18) * max(0.0, 1.0 - diff) * 0.5;
    }

    // Docking collar glow — warm amber lit interior
    vec2 collarCenter = stationPos + vec2(0.75, 0.0);
    float collarGlow = exp(-length(uv - collarCenter) * 12.0);
    vec3 collarLight = vec3(0.855, 0.647, 0.125) * collarGlow * 0.6;

    // Sequential docking guide lights along approach vector
    vec3 dockLights = vec3(0.0);
    // Lights arranged in a line pointing right from collar
    for (int i = 0; i < 8; i++) {
        float fi = float(i);
        vec2 lightPos = collarCenter + vec2(0.08 + fi * 0.075, 0.0);
        float phase = fi * 0.8; // sequential pulse delay
        float lit = dockLight(uv, lightPos, 0.006, phase, t);
        // Color: green then white then amber approaching collar
        vec3 lightCol = mix(vec3(0.3, 1.0, 0.4), vec3(1.0, 0.90, 0.70), fi / 7.0);
        dockLights += lightCol * lit * 1.5;
        // Glow halo around each light
        dockLights += lightCol * exp(-length(uv - lightPos) * 40.0) * 0.3 *
                      smoothstep(1.0, -1.0, sin(t * 3.0 - phase));
    }

    // Approaching ship — right side, aimed at docking collar
    vec2 approachPos = vec2(1.1, 0.0);
    float approachOffset = sin(t * 0.15) * 0.005; // micro-correction
    approachPos.y += approachOffset;
    vec2 aUV = uv - approachPos;
    // Rotate ship to point left toward collar
    float aHull = approachShipSDF(vec2(-aUV.x, aUV.y));
    float aMask = smoothstep(0.004, -0.004, aHull);

    vec3 approachCol = vec3(0.0);
    if (aMask > 0.0) {
        float diff2 = max(0.0, dot(normalize(aUV + 0.001), normalize(vec2(0.5, 0.7))));
        approachCol = mix(vec3(0.10, 0.10, 0.15), vec3(0.82, 0.80, 0.78), diff2);
        // Collar glow reflected on approach ship nose
        approachCol += vec3(0.35, 0.22, 0.05) * (1.0 - diff2) * 0.4;
        // Racing stripe
        float aStripe = step(fract(aUV.y * u_stripe_frequency * 4.0), 0.25);
        approachCol = mix(approachCol, vec3(1.0, 0.549, 0.0), aStripe * 0.45);
    }

    // Approach ship exhaust (tiny — station approach is slow)
    vec2 aExP = uv - (approachPos + vec2(0.09, 0.0));
    float aEx = smoothstep(0.06, 0.0, length(vec2(max(aExP.x, 0.0), aExP.y * 4.0)));
    vec3 aExCol = vec3(0.8, 0.42, 0.12) * aEx * u_exhaust_brightness * 0.4;

    // Compose
    vec3 col = space;
    col = mix(col, stationCol, stationMask * u_chrome_intensity);
    col += collarLight;
    col += dockLights;
    col = mix(col, approachCol, aMask * u_chrome_intensity);
    col += aExCol;

    // Atmosphere haze — station so large it creates a faint gas cloud from venting
    float stationHaze = u_atmosphere_haze * fbm(uv * 3.0 + t * 0.003) * 0.08;
    col += vec3(0.04, 0.05, 0.08) * stationHaze * stationMask;

    // Tonemap
    col = col / (col + 1.0);
    col = pow(col, vec3(1.0 / 2.2));

    gl_FragColor = vec4(col, 1.0);
}
