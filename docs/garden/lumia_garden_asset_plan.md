# Lumia Garden Asset Plan

Date: 2026-05-29

This document replaces ad-hoc asset generation for Garden. The goal is to build a coherent visual system before generating more images.

## What Is Wrong In The Current Screenshot

1. The background is beautiful but not structured for gameplay/UI placement.
   The open moss platforms are vague, so objects and characters look pasted on top instead of belonging to the world.

2. Object scale is inconsistent.
   The carved stone appears too large for a trace object, the paper page reads as a tiny sticker, and contact shadows do not share the same perspective.

3. Character style does not fully match the world.
   The chibi sprites are charming, but the current background is painterly realism. We either need a more storybook background or richer character frames that bridge the style.

4. There is no asset layer plan.
   Sunlight, weather, season, foreground foliage, ground shadows, visitor motion, and trace state all need defined layers.

5. The UI is still too dashboard-like.
   The header and bottom shelf can remain lightweight, but the first read should be the world, not counters.

## Visual System Decision

Garden should use a layered world asset system:

1. Base world background: one coherent Garden composition with fixed anchor zones.
2. Season layer: changes foliage, ground color, flowers, frost, leaves.
3. Time/light layer: changes sunlight, golden hour, night lantern warmth.
4. Weather layer: rain, mist, snow, pollen, drifting leaves, fireflies.
5. Ground contact layer: shadows and small moss contact marks that make objects sit in the world.
6. Object layer: trace objects and keepsakes.
7. Character layer: keeper and visitors with sprite frames.
8. Minimal UI layer: translucent chips only when needed.

Do not generate isolated pretty images unless they map to one of these layers.

## Existing Production Assets

| Asset Group | Current Assets | Keep? | Problem |
| --- | --- | --- | --- |
| Background | `LuminaGardenBackground` | Temporary | Too generic, no explicit anchor map, objects float. |
| Keeper | `GardenKeeperIdle01-04`, `Walk01-04`, `Water01-04`, `Inspect01-04` | Keep as prototype | Needs richer animation and style alignment. |
| Visitors | `GardenVisitorMira01-02`, `Sol01-02`, `Nori01-02` | Keep as prototype | Only idle blink/pose; no arrival, greet, leave, carry gift. |
| Trace Objects | Envelope, Lantern, LeafBowl, MemoryStone, PaperPage, RootCharm, WindChime | Keep as prototype | Need consistent scale, contact shadow, selected/touched states. |
| Props | Board, Drop, Lamp, WateringCan | Partial | Some still imply game/tool UI. |
| Plants | Seed, Sprout, Flower, Tree | Reevaluate | Garden is moving away from routine/task growth. |

## Required Anchor Map

Before final background generation, the Garden world needs fixed zones:

| Zone | Screen Position | Purpose | Asset Requirement |
| --- | --- | --- | --- |
| Foreground path | Bottom center, above tab bar | Keeper walking, entrance, quiet return | Clear walking path, no dense object clutter. |
| Left lower nook | 22% x, 58% y | Visitor arrival and small traces | Ground plane with stable shadow direction. |
| Right lower water edge | 68% x, 58% y | Bowl, letter, dew, water reflection | Water-safe object placement. |
| Left mid stone | 28% x, 44% y | Carved stone, root charm | Stone/moss pad with visible contact. |
| Right mid glade | 70% x, 40% y | Lantern, wind chime, visitor gift | Warm light hotspot. |
| Upper path | 52% x, 28% y | Depth, future season/weather signals | Keep uncluttered; no tap targets. |
| Top canopy | Top 0-18% | Sun shafts, rain origin, leaves | Should not fight status bar. |

The app should use this anchor map for object positions instead of arbitrary scattered coordinates.

## Production Assets To Generate

### P0: Visual Foundation

| Asset ID | Type | Count | Size | Purpose | Generation Notes |
| --- | --- | ---: | --- | --- | --- |
| `GardenWorldBaseSpringDay` | Opaque background | 1 | 1290x2796 PNG | Main coherent Garden world with fixed anchor zones. | Storybook painterly, not photoreal. Leave bottom path clear. No UI/text. |
| `GardenWorldBaseSpringDepthGuide` | Reference only | 1 | 1290x2796 PNG | Annotated internal guide for anchors/depth. | Can be made manually from base; not shipped. |
| `GardenGroundShadowSoft01-06` | Transparent PNG | 6 | 256x128 | Shared contact shadows for objects/characters. | Ellipse shadows matched to world perspective. |
| `GardenTraceScaleSheet` | Reference sheet | 1 | 1600x1200 PNG | Object scale/style comparison. | Put trace objects beside keeper/visitor silhouettes. |
| `GardenKeeperStyleSheet` | Reference sheet | 1 | 1600x1200 PNG | Lock character style before animating. | Keeper + Mira + Sol + Nori in same lighting. |

### P0: Trace Object Production Set

| Asset ID | Type | Count | Size | State | Notes |
| --- | --- | ---: | --- | --- | --- |
| `GardenTracePaperPage` | Transparent PNG | 1 | 1024x1024 | Base | Already generated; needs scale test in scene. |
| `GardenTraceEnvelope` | Transparent PNG | 1 | 1024x1024 | Base | Regenerate or retouch to match paper scale. |
| `GardenTraceMemoryStone` | Transparent PNG | 1 | 1024x1024 | Base | Reduce perceived height; stronger ground contact. |
| `GardenTraceLeafBowl` | Transparent PNG | 1 | 1024x1024 | Base | Add water highlight variant later. |
| `GardenTraceWindChime` | Transparent PNG | 1 | 1024x1024 | Base | Needs hanging placement rules, not ground placement. |
| `GardenTraceLantern` | Transparent PNG | 1 | 1024x1024 | Base | Needs lit/unlit variants. |
| `GardenTraceRootCharm` | Transparent PNG | 1 | 1024x1024 | Base | Needs clearer readable silhouette at small size. |
| `GardenTraceTouchGlow01-08` | Transparent frame sequence | 8 | 512x512 | Touched | Soft pulse, no reward burst. |
| `GardenTraceNewGlimmer01-08` | Transparent frame sequence | 8 | 512x512 | Newly visible | Subtle shimmer for newly created trace. |

### P0: Character Animation Set

Use transparent PNG frame sequences. Generate as sprite sheets first, then cut into frames.

| Character | Animation | Frames | Size Per Frame | Purpose |
| --- | --- | ---: | --- | --- |
| Keeper | Idle | 6 | 512x512 | Breathing/blink, calm loop. |
| Keeper | Walk | 8 | 512x512 | Foreground path roaming. |
| Keeper | Touch / Inspect | 8 | 512x512 | When user taps trace. |
| Keeper | Place | 8 | 512x512 | When placing keepsake/object. |
| Mira | Idle | 6 | 512x512 | Visitor presence. |
| Mira | Arrive | 10 | 512x512 | Enters from left path. |
| Mira | Gift | 8 | 512x512 | Offers keepsake gently. |
| Sol | Idle | 6 | 512x512 | Lantern visitor. |
| Sol | Arrive | 10 | 512x512 | Enters near glade. |
| Sol | Light Lantern | 8 | 512x512 | Soft lantern interaction. |
| Nori | Idle | 6 | 512x512 | Archive visitor. |
| Nori | Arrive | 10 | 512x512 | Small careful steps. |
| Nori | Catalog | 8 | 512x512 | Holds book/seed memory. |

Character constraints:

- No exaggerated bounce.
- Motion should be low amplitude.
- Same palette and line weight across all characters.
- Strong silhouette at 48-76 pt on device.
- Right-facing frames can be mirrored in code; no need to generate both directions unless asymmetry matters.

### P1: Sunlight And Time

| Asset ID | Type | Count/Frames | Size | Trigger |
| --- | --- | ---: | --- | --- |
| `GardenLightMorningRays01-12` | Transparent frame sequence | 12 | 1290x2796 | Morning / first open. |
| `GardenLightNoonDapple01-12` | Transparent frame sequence | 12 | 1290x2796 | Clear / active daytime. |
| `GardenLightGoldenHour01-12` | Transparent frame sequence | 12 | 1290x2796 | Evening or reflective return. |
| `GardenLightLanternHour01-12` | Transparent frame sequence | 12 | 1290x2796 | Night / low mood / quiet return. |
| `GardenLightCloudShadow01-12` | Transparent frame sequence | 12 | 1290x2796 | Soft weather transitions. |

Runtime note:

These can be shipped as compressed frame sequences only if performance is acceptable. Otherwise generate 2-3 static overlays and animate opacity/offset in SwiftUI.

### P1: Weather

| Asset ID | Type | Count/Frames | Size | Mood/State Mapping |
| --- | --- | ---: | --- | --- |
| `GardenWeatherSoftRain01-16` | Transparent frame sequence | 16 | 1290x2796 | High stress, careful state. |
| `GardenWeatherQuietMist01-12` | Transparent frame sequence | 12 | 1290x2796 | Low mood, slow return. |
| `GardenWeatherClearPollen01-16` | Transparent frame sequence | 16 | 1290x2796 | Calm/clear day, active traces. |
| `GardenWeatherFireflies01-16` | Transparent frame sequence | 16 | 1290x2796 | Lantern hour. |
| `GardenWeatherSnowDrift01-16` | Transparent frame sequence | 16 | 1290x2796 | Winter season. |
| `GardenWeatherFallingLeaves01-16` | Transparent frame sequence | 16 | 1290x2796 | Autumn season. |

Weather constraints:

- Weather is atmosphere, not warning.
- Rain and mist must not look like UI strips or opaque overlays.
- Every weather state must leave trace objects inspectable.

### P1: Seasons

Approach: keep the same spatial composition and anchor map across seasons.

| Asset ID | Type | Count | Size | Notes |
| --- | --- | ---: | --- | --- |
| `GardenWorldSpringDay` | Opaque background | 1 | 1290x2796 | Blossoms, fresh green, soft flowers. |
| `GardenWorldSummerDay` | Opaque background | 1 | 1290x2796 | Fuller canopy, stronger greens, warm sun. |
| `GardenWorldAutumnDay` | Opaque background | 1 | 1290x2796 | Amber leaves, gentler light, no brown dominance. |
| `GardenWorldWinterDay` | Opaque background | 1 | 1290x2796 | Frost/snow edges, still warm safe tones. |
| `GardenSeasonSpringForeground` | Transparent PNG | 1 | 1290x2796 | Blossoms near edges. |
| `GardenSeasonSummerForeground` | Transparent PNG | 1 | 1290x2796 | Tall flowers and dense leaves. |
| `GardenSeasonAutumnForeground` | Transparent PNG | 1 | 1290x2796 | Fallen leaves and gold accents. |
| `GardenSeasonWinterForeground` | Transparent PNG | 1 | 1290x2796 | Snow caps/frost on foreground only. |

Season trigger:

- Start with calendar season.
- Later, allow Garden season to drift from usage rhythm, but do not expose this as a control panel.

### P1: Area Growth

| Area | Stage Assets | Count | Purpose |
| --- | --- | ---: | --- |
| Path Nook | sign, stepping stones, small bench | 3 | Repeated grounded returns. |
| Lantern Glade | small lantern, lantern cluster, warm glade | 3 | Therapy/support traces. |
| Archive Corner | box, shelves, tiny archive table | 3 | Remembered insights and keepsakes. |

Each stage should be a transparent PNG with contact shadow. Current SwiftUI-drawn stage marks can remain temporary.

### P2: Extra Detail

| Asset ID | Type | Count | Purpose |
| --- | --- | ---: | --- |
| `GardenWaterRipple01-12` | Transparent frame sequence | 12 | Bowl/stream subtle motion. |
| `GardenWindChimeSway01-10` | Transparent frame sequence | 10 | Wind chime micro-animation. |
| `GardenLanternFlame01-8` | Transparent frame sequence | 8 | Lantern flame. |
| `GardenVisitorShadow01-03` | Transparent PNG | 3 | Character grounding by depth. |
| `GardenTraceAgedOverlay` | Transparent PNG | 1 | Older traces become softer, not obsolete. |

## Generation Batches

### Batch 1: Style Lock

Generate:

1. `GardenTraceScaleSheet`
2. `GardenKeeperStyleSheet`
3. One improved base scene: `GardenWorldBaseSpringDay`

Do not implement until the style sheet and base scene work together.

### Batch 2: World Foundation

Generate:

1. Final `GardenWorldSpringDay`
2. Ground shadow set
3. Foreground spring layer
4. Anchor/depth guide

Then update code to use fixed anchor map and remove floating arbitrary positions.

### Batch 3: Character Frames

Generate:

1. Keeper idle/walk/touch/place
2. Mira idle/arrive/gift
3. Sol idle/arrive/light
4. Nori idle/arrive/catalog

Then replace current two-frame visitor loops.

### Batch 4: Weather And Sunlight

Generate:

1. Morning rays
2. Golden hour
3. Lantern hour
4. Soft rain
5. Quiet mist
6. Fireflies/pollen

Then map weather to `GardenAtmosphereKind`.

### Batch 5: Seasons

Generate:

1. Summer world and foreground
2. Autumn world and foreground
3. Winter world and foreground
4. Snow/leaves overlays

Then map season to calendar or derived Garden state.

## Prompt Rules For All Future Generation

- No readable text.
- No pseudo-text.
- No UI panels.
- No logos or watermarks.
- No coins, trophies, XP, badges, checklists, task boards.
- Keep the same camera angle and anchor zones.
- Keep objects inspectable at small mobile size.
- Transparent assets must actually have alpha, not a baked checkerboard.
- Backgrounds must reserve safe space for iOS status bar and bottom tab bar.

## Immediate Next Step

Generate Batch 1 only:

1. `GardenTraceScaleSheet`
2. `GardenKeeperStyleSheet`
3. `GardenWorldBaseSpringDay`

After that, compare against the current screenshot before writing more code.
