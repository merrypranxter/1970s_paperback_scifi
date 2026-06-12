# 1970s_paperback_scifi

chrome ships the size of continents. impossible light. the future as it was imagined before the future arrived.

The visual language of 1970s–1980s science fiction paperback cover art — Chris Foss, John Berkey, Peter Elson, Bob Pepper. Airbrush on board. Impossible scale. Chrome hulls with racing stripes. Gas giants filling half the frame. The light source is always more than one. Everything is chrome or it should be.

## What This Is

Visual grammar for the golden age of SF cover art — airbrush technique, scale relationships, the specific color signature of space depicted as a physical place rather than void.

## Quick Start

```bash
npm install
npm run dev
```

Open `http://localhost:5173` — use the shader selector to switch between regimes. Parameters update in real time.

## Visual DNA

**Core signatures:**
- Impossible scale: ships so large they create their own weather
- Chrome hulls: metallic surfaces with racing stripe detailing — Chris Foss signature
- Airbrush smooth: no visible brushstrokes, gradient so smooth it aches
- Gas giant backdrops: Jupiter-analogs with banded atmospheric color, taking up 40–60% of frame
- Hard light in void: directional sunlight (single distant star) + soft planet-reflected fill
- Exhaust trails: plumes and exhaust effects from drives — always brighter than they should be
- Color: amber+orange+red for engine glow; cool blue-grey for space shadow; warm orange-yellow for star light
- Panel geometry: hulls covered in surface detail — panels, vents, hatches, antennae at tiny scale

**Color palettes:**
- `FOSS_CHROME`: `#C0C0C0` (chrome), `#FF8C00` (dark orange), `#1C1C5E` (space blue), `#FF4500` (red-orange), `#FFD700`
- `BERKEY_WARM`: `#8B4513` (saddle), `#DAA520` (gold), `#1C1C1C` (black space), `#FF6347` (warm orange)
- `GAS_GIANT`: `#DAA520`, `#CD853F`, `#8B4513`, `#DEB887`, `#F5DEB3`
- `DEEP_SPACE`: `#000010` (near-black blue), `#191970` (midnight), `#C0C0C0` (star white), `#FF6B35`
- `SUNRISE_CHROME`: `#FF4500`, `#FF8C00`, `#FFD700`, `#FFFACD`, `#C0C0C0`

**Technique notes:**
- Airbrush gradient: extremely smooth luminance gradient on curved hull surfaces
- Specular highlight: blown-out white hotspot on chrome — NOT a point, a smear (anisotropic GGX)
- Shadow: deep blue-black (`#000010`) shadow sides of all objects
- Atmospheric haze: slight fog on very large objects to imply scale
- Star field: sparse, varied-size stars — NOT evenly distributed

## Aesthetic Regimes

### `FOSS_FLAGSHIP` — Chris Foss chrome armada
Multiple chrome ships with racing stripe livery. Warm star light. Cold space. Ships at impossible distances from each other but clearly part of a fleet. Surface detail at every scale.

### `BERKEY_EPIC` — John Berkey warm epic
Single massive ship. Warm amber/gold light. Painterly — you can almost see the brushstrokes but you can't. Scale established by tiny escort ships.

### `GAS_GIANT_ENCOUNTER` — The planet fills the frame
Gas giant taking up 50–70% of frame. Ship small against it. Banded atmospheric color. Ring system. Moon shadow. Scale is the subject.

### `DEEP_SPACE_TRANSIT` — Cold, sparse, distant
Near-black space. Very sparse stars. Small ship in middle distance. Exhaust glow the brightest thing. Cold and lonely and correct.

### `DOCKING_SEQUENCE` — Interior/exterior threshold
One ship with interior lights visible. Another approaching. Docking lights in sequence. Scale implies engineering at civilization level.

### `SUNRISE_CHROME` — Dawn on the hull
Ships in full orange sunrise light. Chrome surfaces blazing. Every highlight a smear of gold. The star is just off-frame.

### `FLEET_FORMATION` — Deep formation
Five ships in holding pattern. Varied scales imply flagship and escorts. Exhaust trails parallel. Racing stripe livery consistent across fleet.

### `ORBITAL_APPROACH` — Descent arc
Ship silhouetted against the terminator. Planet surface visible below. Atmosphere glows amber at the limb. Scale established by city grid visible beneath cloud cover.

## Shader Parameters

```glsl
uniform float u_chrome_intensity;   // 0.0–1.0, metallic surface fraction
uniform float u_scale_bias;         // 1.0–1000.0, scale implied by detail density
uniform float u_gas_giant_fill;     // 0.0–1.0, fraction of frame filled by planet
uniform float u_exhaust_brightness; // 0.0–3.0, engine plume intensity (HDR)
uniform vec3  u_star_color;         // primary star color temperature
uniform float u_atmosphere_haze;    // 0.0–1.0, scale atmosphere on large objects
uniform float u_stripe_frequency;   // hull racing stripe density
```

## Shaders

| File | Regime | Key Feature |
|---|---|---|
| `src/shaders/foss_flagship.frag.glsl` | FOSS_FLAGSHIP | Chrome fleet, racing stripes, GGX BRDF |
| `src/shaders/berkey_epic.frag.glsl` | BERKEY_EPIC | Massive ship, amber light, escorts |
| `src/shaders/gas_giant_encounter.frag.glsl` | GAS_GIANT_ENCOUNTER | Planet 60% frame, ring system |
| `src/shaders/deep_space_transit.frag.glsl` | DEEP_SPACE_TRANSIT | HDR exhaust, cold void |
| `src/shaders/docking_sequence.frag.glsl` | DOCKING_SEQUENCE | Interior lights, approach vector |
| `src/shaders/sunrise_chrome.frag.glsl` | SUNRISE_CHROME | Dawn light, blazing chrome |
| `src/shaders/fleet_formation.frag.glsl` | FLEET_FORMATION | Five-ship formation, parallel plumes |
| `src/shaders/orbital_approach.frag.glsl` | ORBITAL_APPROACH | Terminator arc, atmosphere limb glow |
| `shader_examples/preview.frag.glsl` | Mixed | Stub with all uniforms |

## Core Math

```
Chrome BRDF: Cook-Torrance GGX, roughness 0.05–0.15, F0=vec3(0.95,0.93,0.88)
Racing stripe: fract(dot(surface_uv, stripe_dir) * stripe_freq) < stripe_width
Airbrush gradient: smoothstep on luminance with wide knee (0.2–0.8 range), no clipping
Gas giant bands: fbm(vec2(uv.x * 20.0, time * 0.01)) for band wobble; hue shift per band
Specular smear: anisotropic specular along hull long axis, wide lobe
Atmosphere haze: exp(-distance * haze_density) * haze_color for large objects
Exhaust plume: cone SDF + noise displacement + HDR bloom kernel
```

## Ecosystem

Part of the [merrypranxter](https://github.com/merrypranxter) generative art pipeline.
RepoScripter2 context source. ShaderForge style module.

Use with: `retrofuturism`, `holography`, `structural_color`, `accretion_disk`, `nebula_formation`
