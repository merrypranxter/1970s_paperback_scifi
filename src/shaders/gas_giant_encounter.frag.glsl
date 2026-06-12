// GAS_GIANT_ENCOUNTER — The planet fills the frame
// Gas giant 50–70% of frame, ring system, moon shadow, small ship
// Palette: GAS_GIANT — #DAA520, #CD853F, #8B4513, #DEB887, #F5DEB3
// u_gas_giant_fill: 0.65 | u_atmosphere_haze: 0.6 | u_chrome_intensity: 0.85

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

// Gas giant atmospheric bands — latitude-driven, time-drifting
vec3 gasBands(vec2 p, float t) {
    float lat = p.y; // -1..1 maps to pole..pole
    // Zonal flow — each latitude zone drifts at different rate
    float zone = floor(lat * 7.0);
    float zoneOffset = hash21(vec2(zone, 0.5)) * 2.0 - 1.0;
    float bandUV = p.x + zoneOffset * t * 0.008;

    // Fine band structure from fbm
    float b1 = fbm(vec2(bandUV * 3.0, lat * 12.0 + t * 0.002));
    float b2 = fbm(vec2(bandUV * 6.0 + 0.5, lat * 24.0 - t * 0.003));
    float b3 = noise(vec2(bandUV * 15.0, lat * 8.0 + t * 0.001));

    // Latitude band color — GAS_GIANT palette
    // Equatorial: #DAA520 / #DEB887; temperate: #CD853F; polar: #8B4513
    float latNorm = abs(lat);
    vec3 band_eq   = vec3(0.855, 0.647, 0.125); // #DAA520
    vec3 band_temp = vec3(0.804, 0.522, 0.247); // #CD853F
    vec3 band_pol  = vec3(0.545, 0.271, 0.075); // #8B4513
    vec3 band_hi   = vec3(0.961, 0.871, 0.702); // #F5DEB3 highlight bands

    vec3 baseCol = mix(band_eq, band_temp, smoothstep(0.2, 0.6, latNorm));
    baseCol = mix(baseCol, band_pol, smoothstep(0.5, 0.9, latNorm));

    // Dark/light band modulation
    float modulator = b1 * 0.5 + b2 * 0.3 + b3 * 0.2;
    baseCol = mix(baseCol * 0.55, baseCol, smoothstep(0.3, 0.7, modulator));
    baseCol = mix(baseCol, band_hi, step(0.78, modulator) * 0.4);

    return baseCol;
}

// Great storm oval — oval SDF with animated wobble
float stormOval(vec2 p, float t) {
    vec2 center = vec2(-0.25, 0.18);
    vec2 d = p - center;
    d.x /= 1.8; // flatten into oval
    float r = length(d) - 0.08 - noise(vec2(t * 0.5)) * 0.01;
    return r;
}

// Sphere UV from flat UV
vec2 sphereUV(vec2 uv, vec2 center, float radius) {
    vec2 p = (uv - center) / radius;
    float r2 = dot(p, p);
    if (r2 >= 1.0) return vec2(-99.0);
    float z = sqrt(1.0 - r2);
    return vec2(atan(p.x, z) / 3.14159, p.y);
}

// Ring system — annular SDF with banding
float rings(vec2 uv, vec2 center, float innerR, float outerR, float t) {
    vec2 p = uv - center;
    float r = length(p);
    // Ring plane tilted ~15 deg (project y with shear)
    float tiltP = p.y / 0.22; // perspective flatten
    float ringR = length(vec2(p.x, tiltP));

    // Ring mask: annulus
    float mask = smoothstep(innerR - 0.005, innerR, ringR) *
                 smoothstep(outerR + 0.005, outerR, ringR);

    // Ring lanes: radial banding
    float lane = fbm(vec2(ringR * 40.0 + t * 0.001, 0.5)) * 0.6 + 0.4;
    return mask * lane;
}

// Atmospheric limb glow
vec3 limbGlow(vec2 uv, vec2 center, float radius) {
    float r = length(uv - center);
    float limb = smoothstep(radius * 1.08, radius * 0.95, r) *
                 smoothstep(radius * 0.92, radius, r);
    // Amber-gold limb — atmosphere catching starlight
    return vec3(0.95, 0.60, 0.15) * limb * 2.0;
}

// Ship SDF (small relative to planet)
float shipSDF(vec2 p) {
    float d = length(vec2(max(abs(p.x) - 0.07, 0.0), p.y)) - 0.02;
    return d;
}

void main() {
    vec2 uv = gl_FragCoord.xy / u_resolution;
    uv = uv * 2.0 - 1.0;
    uv.x *= u_resolution.x / u_resolution.y;

    float t = u_time;

    // Planet geometry — center-bottom, large
    float planetRadius = 0.55 + u_gas_giant_fill * 0.35;
    vec2 planetCenter = vec2(0.0, -0.25);
    float pDist = length(uv - planetCenter);
    float onPlanet = step(pDist, planetRadius);

    // Space — deep blue-black, with warm star glow from upper-right
    vec3 space = mix(vec3(0.0, 0.0, 0.05), vec3(0.06, 0.04, 0.02),
                     smoothstep(0.0, 2.0, length(uv - vec2(1.0, 1.2))));
    // Stars (hidden behind planet)
    float starMask = 1.0 - onPlanet;
    float s1 = step(0.99, hash21(floor(uv * 70.0))) * starMask;
    float s2 = step(0.978, hash21(floor(uv * 220.0))) * starMask;
    space += vec3(0.9, 0.93, 1.0) * s1 * hash21(uv * 70.0 + 4.0);
    space += vec3(0.7, 0.75, 0.8) * s2 * hash21(uv * 220.0 + 5.0) * 0.4;

    // Rings — behind planet
    float rMask = rings(uv, planetCenter, planetRadius * 1.18, planetRadius * 1.65, t);
    // Rings occluded by planet (lower half of ring goes behind planet)
    float rOcclude = step(0.0, (uv - planetCenter).y); // upper rings visible
    rMask *= (1.0 - onPlanet) * (rOcclude + (1.0 - rOcclude) * 0.0);
    vec3 ringCol = mix(vec3(0.804, 0.522, 0.247), vec3(0.961, 0.871, 0.702), rMask);
    space = mix(space, ringCol, rMask * 0.85);

    // Planet surface
    vec3 planetCol = vec3(0.0);
    if (onPlanet > 0.0) {
        // Sphere UV
        vec2 sUV = sphereUV(uv, planetCenter, planetRadius);
        if (sUV.x > -10.0) {
            planetCol = gasBands(sUV, t);

            // Storm oval
            vec2 sP = sUV;
            float storm = stormOval(sP, t);
            float stormMask = smoothstep(0.01, -0.01, storm);
            vec3 stormCol = mix(vec3(0.90, 0.72, 0.35), vec3(0.65, 0.35, 0.10), 0.6);
            stormCol += fbm(sP * 20.0 + t * 0.02) * vec3(0.1, 0.05, 0.0);
            planetCol = mix(planetCol, stormCol, stormMask * 0.7);

            // Lighting: star from upper-right
            vec2 nSP = (uv - planetCenter) / planetRadius;
            float z = sqrt(max(0.0, 1.0 - dot(nSP, nSP)));
            vec3 sphN = normalize(vec3(nSP, z));
            vec3 sunL = normalize(vec3(0.7, 0.6, 0.5));
            float diffuse = max(dot(sphN, sunL), 0.0);
            float terminator = smoothstep(-0.05, 0.2, diffuse);
            planetCol *= mix(0.08, 1.0, terminator);

            // Atmospheric limb scatter on dark side
            float limbGrad = 1.0 - z;
            planetCol += vec3(0.5, 0.25, 0.05) * pow(limbGrad, 4.0) * 0.4;

            // Atmosphere haze
            planetCol = mix(planetCol, vec3(0.70, 0.45, 0.15),
                           u_atmosphere_haze * pow(1.0 - z, 3.0) * 0.6);
        }
    }

    // Atmospheric limb glow — external halo
    vec3 limb = limbGlow(uv, planetCenter, planetRadius);

    // Moon shadow on planet (small dark disc)
    vec2 moonCenter = vec2(0.28, 0.12);
    float moonShadowR = 0.06;
    float moonShadow = smoothstep(moonShadowR + 0.01, moonShadowR - 0.01, length(uv - planetCenter - moonCenter));
    planetCol *= mix(1.0, 0.3, moonShadow * onPlanet);

    // Rings in front of planet (lower half)
    float rFront = rings(uv, planetCenter, planetRadius * 1.18, planetRadius * 1.65, t);
    float rFrontOcclude = 1.0 - rOcclude;
    rFront *= rFrontOcclude * onPlanet * 0.0 + rFrontOcclude * (1.0 - onPlanet);
    // Near rings partially in front
    float rNear = rings(uv, planetCenter, planetRadius * 1.18, planetRadius * 1.40, t);
    rNear *= rFrontOcclude * onPlanet;
    space = mix(space, ringCol, rNear * 0.5);

    // Ship — small against the giant
    vec2 shipPos = vec2(0.7, 0.45);
    vec2 shipUV = uv - shipPos;
    float hull = shipSDF(shipUV * 3.5) / 3.5;
    float hullMask = smoothstep(0.003, -0.003, hull);

    vec3 shipCol = vec3(0.0);
    if (hullMask > 0.0) {
        vec3 F0 = vec3(0.95, 0.93, 0.88);
        vec2 N2 = normalize(shipUV + 0.001);
        float diff = max(0.0, dot(N2, normalize(vec2(0.7, 0.6))));
        shipCol = mix(vec3(0.15, 0.15, 0.18), vec3(0.88, 0.87, 0.85), diff);
        // Stripe
        float stripe = step(fract(shipUV.x * u_stripe_frequency * 3.5), 0.28);
        shipCol = mix(shipCol, vec3(1.0, 0.549, 0.0), stripe * 0.5);
        // Planet-reflected amber fill
        shipCol += vec3(0.45, 0.28, 0.08) * 0.35;
    }

    // Exhaust plume from ship
    vec2 exP = shipUV - vec2(-0.025, 0.0);
    float ex = smoothstep(0.08, 0.0, length(vec2(max(-exP.x, 0.0), exP.y * 3.0)));
    vec3 exCol = vec3(1.0, 0.50, 0.12) * ex * u_exhaust_brightness;

    // Compose
    vec3 col = space;
    col = mix(col, planetCol, onPlanet);
    col += limb;
    col += rFront * ringCol * 0.4;
    col = mix(col, shipCol, hullMask * u_chrome_intensity);
    col += exCol;

    // Tonemap
    col = col / (col + 1.0);
    col = pow(col, vec3(1.0 / 2.2));

    gl_FragColor = vec4(col, 1.0);
}
