// ORBITAL_APPROACH — Descent arc
// Ship silhouetted against terminator, atmosphere glows amber at limb
// Scale: city grid visible through cloud cover below
// Palette: FOSS_CHROME + GAS_GIANT atmosphere
// u_chrome_intensity: 0.75 | u_scale_bias: 1000.0 | u_atmosphere_haze: 0.8

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
    for (int i = 0; i < 6; i++) { v += a * noise(p); p *= 2.1; a *= 0.5; }
    return v;
}

// Planet surface texture — continents, cloud cover, city lights
vec3 planetSurface(vec2 sUV, float z, float t) {
    // Land/ocean base from fbm
    float landMask = fbm(sUV * 2.5 + vec2(0.3, 0.1));
    vec3 ocean = vec3(0.05, 0.12, 0.28);
    vec3 land  = vec3(0.22, 0.28, 0.12);
    vec3 desert = vec3(0.45, 0.38, 0.18);
    vec3 surface = mix(ocean, land, smoothstep(0.42, 0.52, landMask));
    surface = mix(surface, desert, smoothstep(0.58, 0.68, landMask) *
                  step(0.0, abs(sUV.y) - 0.15));

    // Cloud cover — bright white, drifting
    float clouds = fbm(sUV * 5.0 + vec2(t * 0.008, 0.0)) * 0.6 +
                   fbm(sUV * 10.0 + vec2(0.5, t * 0.005)) * 0.4;
    float cloudMask = smoothstep(0.55, 0.75, clouds);
    surface = mix(surface, vec3(0.9, 0.90, 0.88), cloudMask);

    // City lights — small bright dots on dark side
    float cityGrid = step(0.985, hash21(floor(sUV * 60.0))) *
                     step(0.5, landMask) * (1.0 - cloudMask) * 0.6;
    // Only visible on dark side (where sun doesn't hit)
    surface += vec3(1.0, 0.85, 0.50) * cityGrid * max(0.0, 1.0 - z * 3.0);

    // Sunlit ice caps
    float poleCap = smoothstep(0.65, 0.78, abs(sUV.y));
    surface = mix(surface, vec3(0.95, 0.96, 0.98), poleCap * cloudMask * 0.5);

    return surface;
}

// Atmosphere scattering — Rayleigh-ish
vec3 atmosphereColor(float cosAngle, float altitude) {
    // Sun direction from upper-right
    vec3 sunColor = vec3(1.0, 0.90, 0.75);
    // Blue sky + amber limb
    vec3 sky = mix(vec3(0.15, 0.35, 0.75), sunColor * vec3(0.95, 0.60, 0.15),
                   smoothstep(0.0, 0.3, cosAngle));
    sky = mix(sky, vec3(0.95, 0.60, 0.15), pow(max(0.0, cosAngle), 3.0));
    return sky * exp(-altitude * 2.0);
}

// Ship — angled for reentry approach
float shipHullSDF(vec2 p) {
    float body = length(vec2(max(abs(p.x) - 0.10, 0.0), p.y)) - 0.028;
    // Heat shield belly (wider bottom)
    float belly = length(p - vec2(0.0, 0.025)) - 0.035;
    return max(body, belly - 0.01);
}

void main() {
    vec2 uv = gl_FragCoord.xy / u_resolution;
    uv = uv * 2.0 - 1.0;
    uv.x *= u_resolution.x / u_resolution.y;

    float t = u_time;

    // Planet geometry — fills lower ~65% of frame
    float planetRadius = 0.75 + u_gas_giant_fill * 0.3;
    vec2 planetCenter = vec2(0.0, -0.85);
    float pDist = length(uv - planetCenter);
    bool onPlanet = pDist < planetRadius;

    // Space — upper portion, stars
    vec3 space = vec3(0.0, 0.0, 0.05);
    float starMask = onPlanet ? 0.0 : 1.0;
    float s1 = step(0.992, hash21(floor(uv * 65.0))) * starMask;
    space += vec3(0.92, 0.95, 1.0) * s1 * hash21(uv * 65.0 + 1.0);

    // Sun glow — off upper right
    vec2 sunPos = vec2(1.3, 0.9);
    float sunDist = length(uv - sunPos);
    space += vec3(1.0, 0.90, 0.70) * exp(-sunDist * 3.5) * 0.25;

    // Planet surface
    vec3 planetCol = vec3(0.0);
    vec3 atmCol = vec3(0.0);

    if (onPlanet) {
        vec2 pUV = (uv - planetCenter) / planetRadius;
        float z = sqrt(max(0.0, 1.0 - dot(pUV, pUV)));
        vec3 sphN = normalize(vec3(pUV, z));

        // Surface UV for texture
        vec2 sUV = vec2(atan(pUV.x, z) / 3.14159, pUV.y);

        // Sun lighting
        vec3 sunDir = normalize(vec3(sunPos - planetCenter, 0.6));
        float cosAngle = dot(sphN, sunDir);
        float diffuse = max(cosAngle, 0.0);

        // Surface
        vec3 surf = planetSurface(sUV, z, t);
        // Terminator — smooth transition to dark side
        float terminator = smoothstep(-0.08, 0.15, cosAngle);
        surf *= mix(0.02, 1.0, terminator);

        // Atmosphere scatter
        float limbAngle = 1.0 - z;
        vec3 atmScatter = atmosphereColor(cosAngle, limbAngle) *
                          pow(limbAngle, 2.5) * u_atmosphere_haze;
        surf += atmScatter * 0.8;

        planetCol = surf;

        // Thick atmosphere limb — external glow
        float limb = smoothstep(planetRadius, planetRadius * 0.93, pDist) *
                     smoothstep(planetRadius * 0.90, planetRadius * 0.96, pDist);
        atmCol = mix(vec3(0.15, 0.35, 0.75), vec3(0.90, 0.55, 0.12),
                     smoothstep(-0.3, 0.5, cosAngle)) * limb * 1.8;
    }

    // Atmosphere halo (outside planet disc)
    float halo = smoothstep(planetRadius * 1.06, planetRadius * 0.99, pDist) *
                 smoothstep(planetRadius * 0.95, planetRadius * 1.04, pDist);
    vec3 haloCol = mix(vec3(0.12, 0.28, 0.65), vec3(0.85, 0.50, 0.10),
                       smoothstep(0.6, 1.4, pDist / planetRadius)) * halo;

    // Ship — silhouetted against terminator zone, upper center
    // Angled for orbital approach: nose tilted down
    float entryAngle = -0.4; // steep descent
    float c = cos(entryAngle), s = sin(entryAngle);
    vec2 shipPos = vec2(0.05, 0.35);
    vec2 sp = uv - shipPos;
    sp = vec2(sp.x * c + sp.y * s, -sp.x * s + sp.y * c);

    float hullMask_f = smoothstep(0.004, -0.004, shipHullSDF(sp));

    vec3 shipCol = vec3(0.0);
    if (hullMask_f > 0.0) {
        // Mostly silhouette — sun is behind ship in this view
        // Only rim light from planetary atmosphere
        vec3 rimLight = vec3(0.65, 0.40, 0.12) * 0.5; // amber atmosphere bounce
        // Hot reentry glow on belly leading edge
        float reentryHeat = smoothstep(0.015, 0.0, sp.y - 0.015) *
                            smoothstep(0.10, 0.0, abs(sp.x + 0.05));
        vec3 heatColor = mix(vec3(1.0, 0.55, 0.05), vec3(1.0, 0.90, 0.60), reentryHeat);

        // Base: dark silhouette
        shipCol = vec3(0.08, 0.07, 0.09);
        shipCol += rimLight * (1.0 - max(0.0, sp.y));
        shipCol += heatColor * reentryHeat * 2.0;

        // Racing stripe visible via reflected atmo light
        float stripe = step(fract(sp.x * u_stripe_frequency * 3.0), 0.22);
        shipCol = mix(shipCol, vec3(0.45, 0.20, 0.04), stripe * 0.3);
    }

    // Reentry plasma trail
    // Plasma cone trailing behind ship (opposite to direction of motion)
    float trailAngle = entryAngle + 3.14159;
    float tc = cos(trailAngle), ts = sin(trailAngle);
    vec2 trailP = vec2((uv - shipPos).x * tc + (uv - shipPos).y * ts,
                       -(uv - shipPos).x * ts + (uv - shipPos).y * tc);
    float trailLen = max(trailP.x, 0.0);
    float trailW = smoothstep(trailLen * 0.25 + 0.025, 0.0, abs(trailP.y));
    float trailFade = exp(-trailLen * 4.0);
    float trailFlicker = 0.8 + 0.2 * noise(vec2(trailLen * 12.0 - t * 6.0, t * 4.0));
    vec3 plasma = mix(vec3(0.8, 0.30, 0.08), vec3(1.0, 0.65, 0.25), trailLen * 3.0);
    plasma += vec3(1.0, 0.90, 0.70) * smoothstep(0.01, 0.0, abs(trailP.y)) * trailFade * 2.0;
    vec3 trailCol = plasma * trailW * trailFade * trailFlicker * u_exhaust_brightness;

    // Compose
    vec3 col = space;
    col = mix(col, planetCol, float(onPlanet));
    col += atmCol * float(onPlanet);
    col += haloCol;
    col = mix(col, shipCol, hullMask_f * u_chrome_intensity);
    col += trailCol;

    // Overall atmosphere haze grade
    float sceneHaze = u_atmosphere_haze * fbm(uv * 1.5 + t * 0.002) * 0.08;
    col += vec3(0.05, 0.04, 0.02) * sceneHaze;

    // Tonemap
    col = col / (col + 1.0);
    col = pow(col, vec3(1.0 / 2.2));

    gl_FragColor = vec4(col, 1.0);
}
