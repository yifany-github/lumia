# Lumia Garden Batch 3 Review: Quiet V2

Date: 2026-05-29

## Outcome

Batch 3 replaces the noisy spring scene with a quieter, more readable Garden direction.

Preview:

![Garden quiet V2 preview](GardenQuietV2ScenePreview.png)

## What Changed

| Problem In Screenshot | Change |
| --- | --- |
| Background had too many tiny flowers and high-frequency detail | Generated `GardenWorldSpringQuietV2` with fewer flowers, wider moss pads, and more open water/path space. |
| Foreground flower layer made the whole screen feel cluttered | Removed the foreground flower layer from runtime. |
| Bottom tab area looked masked/dark | Removed Garden-specific hidden tab-bar styling and removed the bottom dark atmosphere gradient. |
| Trace props were too small and hard to notice | Generated larger V2 props and increased runtime sizes. |
| Character frame animation felt strange | Replaced old frame animation with new single-frame characters plus subtle SwiftUI breathing. |
| Props had no life | Added low-amplitude breathing/glow/sway on trace assets, respecting Reduce Motion and Low Power Mode. |

## Accepted Assets

| Asset | Path | Status |
| --- | --- | --- |
| Quiet spring world | `GardenWorldSpringQuietV2.png` | Candidate production |
| Memory stone | `normalized/GardenTraceMemoryStoneV2.png` | Candidate production |
| Paper page | `normalized/GardenTracePaperPageV2.png` | Candidate production |
| Lantern | `normalized/GardenTraceLanternV2.png` | Candidate production |
| Quiet bowl | `normalized/GardenTraceLeafBowlV2.png` | Candidate production |
| Wind charm | `normalized/GardenTraceWindCharmV2.png` | Candidate production |
| Keeper | `normalized/GardenKeeperV2.png` | Candidate production |
| Visitor | `normalized/GardenVisitorV2.png` | Candidate production |

## Runtime Notes

- The V2 background should ship without a foreground flower overlay for now.
- Props should remain prominent: roughly 70-92 pt depending on object type.
- Visitor badges should not show a large question bubble before the user interacts.
- Weather and sunlight should stay sparse; avoid adding particle density that recreates the old clutter.

