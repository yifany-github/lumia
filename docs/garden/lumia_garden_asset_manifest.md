# Lumia Garden Asset Manifest

Date: 2026-05-29

This is the working asset table for rebuilding Garden as a layered, visible memory world rather than a task dashboard.

## Layer Order

| Layer | Runtime Order | Purpose | Rule |
| --- | ---: | --- | --- |
| Base world | 1 | The stable garden place | Opaque full-screen image with fixed anchors. |
| Season tint / foreground | 2 and 8 | Seasonal plants, frost, leaves, depth | Must not move anchors. |
| Sunlight / time | 3 | Morning, noon, golden hour, lantern hour | Prefer SwiftUI opacity/offset unless frame sequence is clearly better. |
| Weather | 4 | Rain, mist, pollen, snow, leaves, fireflies | Atmosphere only; never blocks trace inspection. |
| Ground shadows | 5 | Makes objects and visitors sit in the scene | Shared alpha shadows by depth and scale. |
| Trace / keepsake objects | 6 | Visible memory layer | No reward, badge, XP, or checklist visual language. |
| Visitors / keeper | 7 | Gentle presence and motion | Low-amplitude animation, no mascot bounce. |
| Minimal UI | 9 | Navigation and light controls | World first, dashboard second. |

## Generated Now: Batch 2

| Asset ID | Path | Format | Status | Use |
| --- | --- | --- | --- | --- |
| `GardenWorldSpringDay` | `docs/garden/batch-2-world-foundation/GardenWorldSpringDay.png` | 1290x2796 PNG, opaque | Candidate production | Main spring Garden background. |
| `GardenWorldSpringDepthGuide` | `docs/garden/batch-2-world-foundation/GardenWorldSpringDepthGuide.png` | 1290x2796 PNG | Internal reference | Placement/depth guide. |
| `GardenWorldSpringAnchorMap` | `docs/garden/batch-2-world-foundation/GardenWorldSpringAnchorMap.json` | JSON | Internal reference | Normalized scene anchors. |
| `GardenGroundShadowSoft01-06` | `docs/garden/batch-2-world-foundation/ground-shadows/` | 256x128 PNG, alpha | Candidate production | Shared contact shadows. |
| `GardenSeasonSpringForeground` | `docs/garden/batch-2-world-foundation/foreground/GardenSeasonSpringForeground.png` | 1290x2796 PNG, alpha | Candidate production | Spring foreground depth layer. |
| `GardenWorldSpringForegroundPreview` | `docs/garden/batch-2-world-foundation/GardenWorldSpringForegroundPreview.png` | 1290x2796 PNG | QA only | Composite preview. |
| `Batch2WorldFoundationContactSheet` | `docs/garden/batch-2-world-foundation/Batch2WorldFoundationContactSheet.png` | PNG | QA only | Visual review sheet. |

Rejected/raw sources:

| Asset | Reason |
| --- | --- |
| `foreground/GardenSeasonSpringForeground.keyed.png` | Magenta key contaminated flower and leaf edges. Keep only as reference, do not ship. |
| `foreground/GardenSeasonSpringForeground.alpha.raw.png` | Derived from rejected magenta key. Do not ship. |

## Generated Now: Batch 3 Quiet V2

| Asset ID | Path | Format | Status | Use |
| --- | --- | --- | --- | --- |
| `GardenWorldSpringQuietV2` | `docs/garden/batch-3-quiet-v2/GardenWorldSpringQuietV2.png` | 1290x2796 PNG, opaque | Candidate production | Cleaner low-flower Garden background. |
| `GardenTraceMemoryStoneV2` | `docs/garden/batch-3-quiet-v2/normalized/GardenTraceMemoryStoneV2.png` | 1024x1024 PNG, alpha | Candidate production | More readable carved stone. |
| `GardenTracePaperPageV2` | `docs/garden/batch-3-quiet-v2/normalized/GardenTracePaperPageV2.png` | 1024x1024 PNG, alpha | Candidate production | More readable paper/page prop. |
| `GardenTraceLanternV2` | `docs/garden/batch-3-quiet-v2/normalized/GardenTraceLanternV2.png` | 1024x1024 PNG, alpha | Candidate production | Warm glowing lantern. |
| `GardenTraceLeafBowlV2` | `docs/garden/batch-3-quiet-v2/normalized/GardenTraceLeafBowlV2.png` | 1024x1024 PNG, alpha | Candidate production | Quiet bowl for Sanctuary/body-return traces. |
| `GardenTraceWindCharmV2` | `docs/garden/batch-3-quiet-v2/normalized/GardenTraceWindCharmV2.png` | 1024x1024 PNG, alpha | Candidate production | Wind charm/root charm replacement. |
| `GardenKeeperV2` | `docs/garden/batch-3-quiet-v2/normalized/GardenKeeperV2.png` | 1024x1024 PNG, alpha | Candidate production | New calmer keeper character. |
| `GardenVisitorV2` | `docs/garden/batch-3-quiet-v2/normalized/GardenVisitorV2.png` | 1024x1024 PNG, alpha | Candidate production | New calmer visitor character. |

Batch 3 intentionally removes the dense spring foreground layer from runtime. Any future foreground layer must be sparse enough that it does not read as a floral border.

## Required Production Assets

### World And Seasons

| Asset ID | Count | Size | Status | Notes |
| --- | ---: | --- | --- | --- |
| `GardenWorldSpringDay` | 1 | 1290x2796 | Generated | Use as current foundation. |
| `GardenWorldSummerDay` | 1 | 1290x2796 | Needed | Same camera and anchors; fuller canopy, warmer green. |
| `GardenWorldAutumnDay` | 1 | 1290x2796 | Needed | Same anchors; gold leaves, not brown/orange dominant. |
| `GardenWorldWinterDay` | 1 | 1290x2796 | Needed | Same anchors; frost/snow edges, still warm and safe. |
| `GardenSeasonSpringForeground` | 1 | 1290x2796 alpha | Generated | Edge flowers and moss. |
| `GardenSeasonSummerForeground` | 1 | 1290x2796 alpha | Needed | Taller grasses, denser leaves, few flowers. |
| `GardenSeasonAutumnForeground` | 1 | 1290x2796 alpha | Needed | Fallen leaves and amber accents. |
| `GardenSeasonWinterForeground` | 1 | 1290x2796 alpha | Needed | Frost caps and quiet snow edges. |

### Sunlight And Time

| Asset ID | Count | Size | Status | Motion |
| --- | ---: | --- | --- | --- |
| `GardenLightMorningRays01-12` | 12 | 1290x2796 alpha | Needed | Slow diagonal drift, low opacity. |
| `GardenLightNoonDapple01-12` | 12 | 1290x2796 alpha | Needed | Leaf shadows breathing gently. |
| `GardenLightGoldenHour01-12` | 12 | 1290x2796 alpha | Needed | Warm side glow and longer soft shadows. |
| `GardenLightLanternHour01-12` | 12 | 1290x2796 alpha | Needed | Darker vignette, warm lantern pockets, firefly compatibility. |
| `GardenLightCloudShadow01-12` | 12 | 1290x2796 alpha | Needed | Very soft cloud pass over scene. |

Implementation note: generate static overlays first, then animate offset/opacity in SwiftUI. Only ship frame sequences if visual quality justifies bundle size.

### Weather

| Asset ID | Count | Size | Status | Use |
| --- | ---: | --- | --- | --- |
| `GardenWeatherSoftRain01-16` | 16 | 1290x2796 alpha | Needed | Stress/careful state; thin rain, not gloomy warning. |
| `GardenWeatherQuietMist01-12` | 12 | 1290x2796 alpha | Needed | Low mood or slow return; light depth haze. |
| `GardenWeatherClearPollen01-16` | 16 | 1290x2796 alpha | Needed | Calm/clear day; subtle drifting specks. |
| `GardenWeatherFireflies01-16` | 16 | 1290x2796 alpha | Needed | Lantern hour; sparse warm points. |
| `GardenWeatherSnowDrift01-16` | 16 | 1290x2796 alpha | Needed | Winter; slow sparse flakes. |
| `GardenWeatherFallingLeaves01-16` | 16 | 1290x2796 alpha | Needed | Autumn; leaves fall behind trace objects. |

### Characters

| Character | Animation | Frames | Size Per Frame | Status | Notes |
| --- | --- | ---: | --- | --- | --- |
| Keeper | Idle | 6 | 512x512 alpha | Needed | Breathing, blink, tiny head movement. |
| Keeper | Walk | 8 | 512x512 alpha | Needed | Slow path roaming. |
| Keeper | Inspect | 8 | 512x512 alpha | Needed | Looks at or touches trace. |
| Keeper | Place | 8 | 512x512 alpha | Needed | Places keepsake without reward burst. |
| Mira | Idle | 6 | 512x512 alpha | Needed | Companion presence near left nook. |
| Mira | Arrive | 10 | 512x512 alpha | Needed | Enters from path edge. |
| Mira | Gift | 8 | 512x512 alpha | Needed | Offers keepsake gently. |
| Sol | Idle | 6 | 512x512 alpha | Needed | Lantern-side visitor. |
| Sol | Arrive | 10 | 512x512 alpha | Needed | Enters near glade. |
| Sol | Light Lantern | 8 | 512x512 alpha | Needed | Small warm interaction. |
| Nori | Idle | 6 | 512x512 alpha | Needed | Archive/memory visitor. |
| Nori | Arrive | 10 | 512x512 alpha | Needed | Careful small steps. |
| Nori | Catalog | 8 | 512x512 alpha | Needed | Holds book/seed memory. |

### Trace And Keepsake Objects

| Asset ID | Count | Size | Status | Notes |
| --- | ---: | --- | --- | --- |
| `GardenTracePaperPage` | 1 | 1024x1024 alpha | Existing generated | Needs scene scale test. |
| `GardenTraceEnvelope` | 1 | 1024x1024 alpha | Existing prototype | Regenerate or retouch to match paper scale. |
| `GardenTraceMemoryStone` | 1 | 1024x1024 alpha | Existing prototype | Reduce height; strengthen ground contact. |
| `GardenTraceLeafBowl` | 1 | 1024x1024 alpha | Existing prototype | Add water highlight variant later. |
| `GardenTraceWindChime` | 1 | 1024x1024 alpha | Existing prototype | Hanging placement only. |
| `GardenTraceLantern` | 2 | 1024x1024 alpha | Existing prototype | Needs lit and unlit states. |
| `GardenTraceRootCharm` | 1 | 1024x1024 alpha | Existing prototype | Improve silhouette at small size. |
| `GardenTraceTouchGlow01-08` | 8 | 512x512 alpha | Needed | Acknowledgement pulse, not reward burst. |
| `GardenTraceNewGlimmer01-08` | 8 | 512x512 alpha | Needed | Newly visible trace shimmer. |

## Generation Order

1. Batch 2: world foundation. Done as candidate production.
2. Batch 3: characters and visitor animation frames.
3. Batch 4: sunlight and weather overlays.
4. Batch 5: summer/autumn/winter worlds and foregrounds.
5. Batch 6: trace object retouch and touch/new-state effects.

## Prompt Constraints

- No readable text, pseudo-text, UI, logos, watermarks, counters, badges, coins, trophies, checklists, missions, or task boards.
- Keep camera angle and anchor map identical across seasons.
- Keep character motion small and emotionally quiet.
- Transparent assets must be real alpha PNGs, not baked checkerboards.
- Every object needs a contact shadow or anchor rule.
- Garden must read first as a place to look at, not a dashboard to manage.
