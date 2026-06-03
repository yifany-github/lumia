# Lumia Garden Batch 2 Review: World Foundation

Date: 2026-05-29

## Outcome

Batch 2 is the first usable world-foundation pass. It replaces the earlier floating-object direction with a fixed scene, clear anchor map, shared shadows, and a seasonal foreground layer.

Contact sheet:

![Batch 2 world foundation contact sheet](Batch2WorldFoundationContactSheet.png)

## Accepted Assets

| Asset | Path | Status | Notes |
| --- | --- | --- | --- |
| Spring world base | `GardenWorldSpringDay.png` | Candidate production | Opaque 1290x2796 background with clearer object/visitor zones and bottom tab safe darkness. |
| Anchor/depth guide | `GardenWorldSpringDepthGuide.png` | Internal guide | Not shipped. Used to align object placement and depth scale. |
| Anchor map | `GardenWorldSpringAnchorMap.json` | Internal data | Normalized coordinates for scene placement. |
| Ground shadows | `ground-shadows/GardenGroundShadowSoft01-06.png` | Candidate production | Shared RGBA contact shadows for trace objects and characters. |
| Spring foreground | `foreground/GardenSeasonSpringForeground.png` | Candidate production | Transparent botanical edge layer for depth and seasonal variation. |
| Composite preview | `GardenWorldSpringForegroundPreview.png` | QA preview | Shows the world and foreground together at full app size. |

## QA Notes

- The final background has stable placement zones: left visitor nook, right water edge, left stone pad, right lantern glade, foreground path, and upper depth path.
- Ground shadows are true alpha PNGs and intentionally generic so trace objects can sit in the world without hand-painted shadows per object.
- The first foreground attempt used magenta chroma key and produced visible color pollution. It remains only as a rejected raw source.
- The accepted foreground was regenerated with cyan keying, then converted to alpha. The composite looks clean enough for the next implementation pass.
- The foreground should still receive a final art pass before release if the shipped scene uses heavy zoom or very dark night overlays.

## Next Implementation Move

1. Add the candidate production assets to `Assets.xcassets`.
2. Replace arbitrary Garden object coordinates with the anchor map.
3. Draw the Garden as layered scene: base world, light/weather, objects, characters, foreground, minimal UI.
4. Use shared ground shadows under every object and visitor.
5. Keep metrics and explanations out of the first read; put them in sheets.

