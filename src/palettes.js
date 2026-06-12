// 1970s Paperback Sci-Fi — Named Color Palettes
// All hex values from context.manifest.json

export const PALETTES = {
  // Chris Foss chrome ships — silver hulls, orange stripe, cold space
  FOSS_CHROME: {
    chrome:     '#C0C0C0',  // vec3(0.753, 0.753, 0.753)
    stripe:     '#FF8C00',  // vec3(1.0,   0.549, 0.0)
    space:      '#1C1C5E',  // vec3(0.110, 0.110, 0.369)
    accent:     '#FF4500',  // vec3(1.0,   0.271, 0.0)
    highlight:  '#FFD700',  // vec3(1.0,   0.843, 0.0)
  },

  // John Berkey warm epics — amber/gold light, brown-black space
  BERKEY_WARM: {
    shadow:     '#8B4513',  // vec3(0.545, 0.271, 0.075)
    warm:       '#DAA520',  // vec3(0.855, 0.647, 0.125)
    space:      '#1C1C1C',  // vec3(0.110, 0.110, 0.110)
    glow:       '#FF6347',  // vec3(1.0,   0.388, 0.278)
  },

  // Gas giant atmospheres — Jupiter-analog bands
  GAS_GIANT: {
    band1:      '#DAA520',  // vec3(0.855, 0.647, 0.125)
    band2:      '#CD853F',  // vec3(0.804, 0.522, 0.247)
    band3:      '#8B4513',  // vec3(0.545, 0.271, 0.075)
    band4:      '#DEB887',  // vec3(0.871, 0.722, 0.529)
    highlight:  '#F5DEB3',  // vec3(0.961, 0.871, 0.702)
  },

  // Deep space — near-black void, cold stars, hot exhaust
  DEEP_SPACE: {
    void:       '#000010',  // vec3(0.0,   0.0,   0.063)
    midnight:   '#191970',  // vec3(0.098, 0.098, 0.439)
    star:       '#C0C0C0',  // vec3(0.753, 0.753, 0.753)
    exhaust:    '#FF6B35',  // vec3(1.0,   0.420, 0.208)
  },

  // Sunrise chrome — orange dawn blasting over chrome hulls
  SUNRISE_CHROME: {
    fire:       '#FF4500',  // vec3(1.0,   0.271, 0.0)
    amber:      '#FF8C00',  // vec3(1.0,   0.549, 0.0)
    gold:       '#FFD700',  // vec3(1.0,   0.843, 0.0)
    cream:      '#FFFACD',  // vec3(1.0,   0.980, 0.804)
    chrome:     '#C0C0C0',  // vec3(0.753, 0.753, 0.753)
  },
};

// GLSL vec3 equivalents — paste directly into shader source
export const GLSL = {
  FOSS_CHROME:    'vec3(0.753,0.753,0.753), vec3(1.0,0.549,0.0), vec3(0.110,0.110,0.369), vec3(1.0,0.271,0.0), vec3(1.0,0.843,0.0)',
  BERKEY_WARM:    'vec3(0.545,0.271,0.075), vec3(0.855,0.647,0.125), vec3(0.110,0.110,0.110), vec3(1.0,0.388,0.278)',
  GAS_GIANT:      'vec3(0.855,0.647,0.125), vec3(0.804,0.522,0.247), vec3(0.545,0.271,0.075), vec3(0.871,0.722,0.529), vec3(0.961,0.871,0.702)',
  DEEP_SPACE:     'vec3(0.0,0.0,0.063), vec3(0.098,0.098,0.439), vec3(0.753,0.753,0.753), vec3(1.0,0.420,0.208)',
  SUNRISE_CHROME: 'vec3(1.0,0.271,0.0), vec3(1.0,0.549,0.0), vec3(1.0,0.843,0.0), vec3(1.0,0.980,0.804), vec3(0.753,0.753,0.753)',
};

// Default uniform values per regime
export const DEFAULTS = {
  FOSS_FLAGSHIP:        { u_chrome_intensity: 0.95, u_scale_bias: 400.0,  u_gas_giant_fill: 0.3,  u_exhaust_brightness: 1.8, u_star_color: [1.0, 0.92, 0.8],  u_atmosphere_haze: 0.2, u_stripe_frequency: 8.0  },
  BERKEY_EPIC:          { u_chrome_intensity: 0.80, u_scale_bias: 800.0,  u_gas_giant_fill: 0.0,  u_exhaust_brightness: 0.8, u_star_color: [1.0, 0.85, 0.6],  u_atmosphere_haze: 0.4, u_stripe_frequency: 4.0  },
  GAS_GIANT_ENCOUNTER:  { u_chrome_intensity: 0.85, u_scale_bias: 200.0,  u_gas_giant_fill: 0.65, u_exhaust_brightness: 1.2, u_star_color: [1.0, 0.95, 0.85], u_atmosphere_haze: 0.6, u_stripe_frequency: 6.0  },
  DEEP_SPACE_TRANSIT:   { u_chrome_intensity: 0.70, u_scale_bias: 100.0,  u_gas_giant_fill: 0.0,  u_exhaust_brightness: 2.8, u_star_color: [0.8, 0.9,  1.0],  u_atmosphere_haze: 0.0, u_stripe_frequency: 5.0  },
  DOCKING_SEQUENCE:     { u_chrome_intensity: 0.90, u_scale_bias: 600.0,  u_gas_giant_fill: 0.1,  u_exhaust_brightness: 0.5, u_star_color: [1.0, 0.88, 0.75], u_atmosphere_haze: 0.1, u_stripe_frequency: 10.0 },
  SUNRISE_CHROME:       { u_chrome_intensity: 1.00, u_scale_bias: 300.0,  u_gas_giant_fill: 0.0,  u_exhaust_brightness: 2.2, u_star_color: [1.0, 0.55, 0.2],  u_atmosphere_haze: 0.3, u_stripe_frequency: 7.0  },
  FLEET_FORMATION:      { u_chrome_intensity: 0.92, u_scale_bias: 500.0,  u_gas_giant_fill: 0.2,  u_exhaust_brightness: 1.5, u_star_color: [1.0, 0.9,  0.75], u_atmosphere_haze: 0.2, u_stripe_frequency: 9.0  },
  ORBITAL_APPROACH:     { u_chrome_intensity: 0.75, u_scale_bias: 1000.0, u_gas_giant_fill: 0.55, u_exhaust_brightness: 1.0, u_star_color: [1.0, 0.9,  0.8],  u_atmosphere_haze: 0.8, u_stripe_frequency: 6.0  },
};
