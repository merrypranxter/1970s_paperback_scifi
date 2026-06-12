import * as THREE from 'three';
import { DEFAULTS } from './palettes.js';

// ── Shader sources (raw text via Vite ?raw imports) ───────────────────────────
import fossSource      from './shaders/foss_flagship.frag.glsl?raw';
import berkeySource    from './shaders/berkey_epic.frag.glsl?raw';
import gasGiantSource  from './shaders/gas_giant_encounter.frag.glsl?raw';
import deepSpaceSource from './shaders/deep_space_transit.frag.glsl?raw';
import dockingSource   from './shaders/docking_sequence.frag.glsl?raw';
import sunriseSource   from './shaders/sunrise_chrome.frag.glsl?raw';
import fleetSource     from './shaders/fleet_formation.frag.glsl?raw';
import orbitalSource   from './shaders/orbital_approach.frag.glsl?raw';

// ── Regime registry ───────────────────────────────────────────────────────────
const REGIMES = [
  { id: 'FOSS_FLAGSHIP',       label: 'Foss Flagship',       source: fossSource      },
  { id: 'BERKEY_EPIC',         label: 'Berkey Epic',         source: berkeySource    },
  { id: 'GAS_GIANT_ENCOUNTER', label: 'Gas Giant Encounter', source: gasGiantSource  },
  { id: 'DEEP_SPACE_TRANSIT',  label: 'Deep Space Transit',  source: deepSpaceSource },
  { id: 'DOCKING_SEQUENCE',    label: 'Docking Sequence',    source: dockingSource   },
  { id: 'SUNRISE_CHROME',      label: 'Sunrise Chrome',      source: sunriseSource   },
  { id: 'FLEET_FORMATION',     label: 'Fleet Formation',     source: fleetSource     },
  { id: 'ORBITAL_APPROACH',    label: 'Orbital Approach',    source: orbitalSource   },
];

// ── Uniform parameter descriptors ─────────────────────────────────────────────
const PARAM_DEFS = [
  { key: 'u_chrome_intensity',   label: 'Chrome Intensity',   min: 0.0,  max: 1.0,    step: 0.01 },
  { key: 'u_scale_bias',         label: 'Scale Bias',         min: 1.0,  max: 1000.0, step: 1.0  },
  { key: 'u_gas_giant_fill',     label: 'Gas Giant Fill',     min: 0.0,  max: 1.0,    step: 0.01 },
  { key: 'u_exhaust_brightness', label: 'Exhaust Brightness', min: 0.0,  max: 3.0,    step: 0.05 },
  { key: 'u_atmosphere_haze',    label: 'Atmosphere Haze',    min: 0.0,  max: 1.0,    step: 0.01 },
  { key: 'u_stripe_frequency',   label: 'Stripe Frequency',   min: 1.0,  max: 20.0,   step: 0.5  },
];

// ── Three.js setup ─────────────────────────────────────────────────────────────
const scene    = new THREE.Scene();
const camera   = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
document.getElementById('canvas-container').appendChild(renderer.domElement);

const vertexShader = `void main() { gl_Position = vec4(position, 1.0); }`;

const geometry = new THREE.PlaneGeometry(2, 2);

// Build initial uniforms from first regime defaults
function makeUniforms(regimeId) {
  const def = DEFAULTS[regimeId] || DEFAULTS['FOSS_FLAGSHIP'];
  return {
    u_time:               { value: 0 },
    u_resolution:         { value: new THREE.Vector2(window.innerWidth, window.innerHeight) },
    u_chrome_intensity:   { value: def.u_chrome_intensity },
    u_scale_bias:         { value: def.u_scale_bias },
    u_gas_giant_fill:     { value: def.u_gas_giant_fill },
    u_exhaust_brightness: { value: def.u_exhaust_brightness },
    u_star_color:         { value: new THREE.Vector3(...def.u_star_color) },
    u_atmosphere_haze:    { value: def.u_atmosphere_haze },
    u_stripe_frequency:   { value: def.u_stripe_frequency },
  };
}

let currentRegimeIndex = 0;
let currentUniforms = makeUniforms(REGIMES[0].id);

let material = new THREE.ShaderMaterial({
  vertexShader,
  fragmentShader: REGIMES[0].source,
  uniforms: currentUniforms,
});

const mesh = new THREE.Mesh(geometry, material);
scene.add(mesh);

// ── Regime switching ──────────────────────────────────────────────────────────
function switchRegime(index) {
  currentRegimeIndex = ((index % REGIMES.length) + REGIMES.length) % REGIMES.length;
  const regime = REGIMES[currentRegimeIndex];
  const def = DEFAULTS[regime.id];

  // Preserve current time/resolution but snap params to regime defaults
  const oldTime = currentUniforms.u_time.value;

  currentUniforms = makeUniforms(regime.id);
  currentUniforms.u_time.value = oldTime;

  material.dispose();
  material = new THREE.ShaderMaterial({
    vertexShader,
    fragmentShader: regime.source,
    uniforms: currentUniforms,
  });
  mesh.material = material;

  updateRegimeLabel();
  syncSliders();
}

// ── UI: regime selector buttons ───────────────────────────────────────────────
const regimeList = document.getElementById('regime-list');
REGIMES.forEach((r, i) => {
  const btn = document.createElement('button');
  btn.className = 'regime-btn';
  btn.textContent = r.label;
  btn.dataset.index = i;
  btn.addEventListener('click', () => switchRegime(i));
  regimeList.appendChild(btn);
});

function updateRegimeLabel() {
  document.querySelectorAll('.regime-btn').forEach((btn, i) => {
    btn.classList.toggle('active', i === currentRegimeIndex);
  });
  document.getElementById('current-regime').textContent = REGIMES[currentRegimeIndex].label;
}

// ── UI: parameter sliders ─────────────────────────────────────────────────────
const paramsContainer = document.getElementById('params');

PARAM_DEFS.forEach(p => {
  const row = document.createElement('div');
  row.className = 'param-row';

  const label = document.createElement('label');
  label.textContent = p.label;
  label.htmlFor = `slider-${p.key}`;

  const slider = document.createElement('input');
  slider.type = 'range';
  slider.id = `slider-${p.key}`;
  slider.min  = p.min;
  slider.max  = p.max;
  slider.step = p.step;
  slider.value = currentUniforms[p.key].value;

  const valDisplay = document.createElement('span');
  valDisplay.id = `val-${p.key}`;
  valDisplay.textContent = slider.value;

  slider.addEventListener('input', () => {
    const v = parseFloat(slider.value);
    if (currentUniforms[p.key]) currentUniforms[p.key].value = v;
    valDisplay.textContent = v.toFixed(p.step < 1 ? 2 : 0);
  });

  row.appendChild(label);
  row.appendChild(slider);
  row.appendChild(valDisplay);
  paramsContainer.appendChild(row);
});

function syncSliders() {
  PARAM_DEFS.forEach(p => {
    const slider = document.getElementById(`slider-${p.key}`);
    const valDisplay = document.getElementById(`val-${p.key}`);
    if (slider && currentUniforms[p.key] !== undefined) {
      slider.value = currentUniforms[p.key].value;
      valDisplay.textContent = parseFloat(slider.value).toFixed(p.step < 1 ? 2 : 0);
    }
  });
}

// ── Keyboard navigation ───────────────────────────────────────────────────────
window.addEventListener('keydown', e => {
  if (e.key === 'ArrowRight' || e.key === ']') switchRegime(currentRegimeIndex + 1);
  if (e.key === 'ArrowLeft'  || e.key === '[') switchRegime(currentRegimeIndex - 1);
});

// ── Sidebar toggle ────────────────────────────────────────────────────────────
document.getElementById('toggle-sidebar').addEventListener('click', () => {
  document.getElementById('sidebar').classList.toggle('collapsed');
});

// ── Render loop ───────────────────────────────────────────────────────────────
function animate(time) {
  currentUniforms.u_time.value = time * 0.001;
  renderer.render(scene, camera);
  requestAnimationFrame(animate);
}
requestAnimationFrame(animate);

// ── Resize ────────────────────────────────────────────────────────────────────
window.addEventListener('resize', () => {
  renderer.setSize(window.innerWidth, window.innerHeight);
  currentUniforms.u_resolution.value.set(window.innerWidth, window.innerHeight);
});

// ── Initialize UI ─────────────────────────────────────────────────────────────
updateRegimeLabel();
syncSliders();
