// 1970s Paperback Sci-Fi — Fragment Shader Stub
// Chrome BRDF, racing stripes, gas giant bands, exhaust plume, star field
// All uniforms defined — swap main() body for regime-specific implementation

precision highp float;
uniform float u_time;
uniform vec2 u_resolution;
uniform float u_chrome_intensity;   // 0.0–1.0
uniform float u_scale_bias;         // 1.0–1000.0
uniform float u_gas_giant_fill;     // 0.0–1.0
uniform float u_exhaust_brightness; // 0.0–3.0  (HDR)
uniform vec3 u_star_color;          // star color temperature
uniform float u_atmosphere_haze;    // 0.0–1.0
uniform float u_stripe_frequency;   // hull stripe density

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) { v += a * hash(p); p *= 2.0; a *= 0.5; }
    return v;
}

void main() {
    vec2 uv = gl_FragCoord.xy / u_resolution;
    uv = uv * 2.0 - 1.0;
    uv.x *= u_resolution.x / u_resolution.y;

    // Space background — #000010
    vec3 space = vec3(0.0, 0.0, 0.063);
    float stars = step(0.98, hash(floor(uv * 80.0))) * hash(uv * 100.0 + 1.0);
    space += vec3(0.9, 0.95, 1.0) * stars;

    // Gas giant — centered lower frame
    float planet_r = length(uv - vec2(0.0, -0.3));
    float planet = smoothstep(0.5, 0.48, planet_r);
    float bands = fbm(vec2(uv.x * 20.0, u_time * 0.01)) * 0.5 + 0.5;
    vec3 planet_col = mix(vec3(0.85, 0.65, 0.2), vec3(0.55, 0.35, 0.15), bands);

    // Chrome ship — left of center
    vec2 ship_uv = uv - vec2(-0.5, 0.0);
    float ship = smoothstep(0.15, 0.14, length(ship_uv));
    float stripe = step(fract(dot(ship_uv, vec2(1.0, 0.0)) * u_stripe_frequency), 0.3);
    float spec = pow(max(0.0, dot(normalize(ship_uv), vec2(0.707, 0.707))), 16.0);
    vec3 chrome = mix(vec3(0.9, 0.88, 0.85), vec3(0.95, 0.93, 0.88), spec);
    chrome = mix(chrome, vec3(1.0, 0.55, 0.0), stripe * 0.3);

    // Exhaust — #FF4500 + #FF8C00
    float exhaust = smoothstep(0.3, 0.0, length(ship_uv - vec2(-0.18, 0.0))) *
                    smoothstep(0.0, 0.2, ship_uv.x + 0.15);
    chrome += vec3(1.0, 0.4, 0.1) * exhaust * u_exhaust_brightness;

    vec3 col = mix(space, planet_col, planet * u_gas_giant_fill);
    col = mix(col, chrome * u_chrome_intensity, ship);
    col += vec3(0.3, 0.2, 0.1) * u_atmosphere_haze * planet * (1.0 - planet_r);

    gl_FragColor = vec4(col, 1.0);
}
