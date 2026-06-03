# Lumia Garden Character Motion Asset Spec

This batch replaces the rough low-resolution sprite set with a refined character system.

## Immediate Runtime Decision

- Use extracted refined keeper frames in the app now:
  - `GardenKeeperRefinedIdle01`
  - `GardenKeeperRefinedIdle02`
  - `GardenKeeperWalkSmooth01...06`
  - `GardenKeeperInspectSmooth01...08`
  - `GardenKeeperPlaceSmooth01...08`
  - `GardenKeeperRefinedWave01`
- Use extracted refined visitor frames in the app now:
  - `GardenVisitorRefinedIdle01`
  - `GardenVisitorRefinedLook01`
  - `GardenVisitorRefinedWalk01`
  - `GardenVisitorRefinedWalk02`
  - `GardenVisitorRefinedOffer01`
  - `GardenVisitorRefinedWave01`
- Disable the rough 256 px frame animations in production.
- Use state-driven frame sequences with no transform drift on character bodies.
- Idle and walking loops repeat. Inspect, tend, and place play once, then hold the last pose.
- The extracted keeper frames are a runtime improvement, but the source reference had a baked checkerboard. Replace them with direct true-alpha production frames when available.

## Production Sprite Requirements

| Character | Action | Frames | Canvas | Baseline | Notes |
| --- | ---: | ---: | --- | --- | --- |
| Keeper | Idle blink / breathe | 6 | 1024x1024 alpha | identical foot baseline | Same outfit, no size drift. |
| Keeper | Slow walk | 8 | 1024x1024 alpha | identical foot baseline | Small steps, no bounce. |
| Keeper | Inspect trace | 8 | 1024x1024 alpha | identical foot baseline | Gentle lean/crouch toward object. |
| Keeper | Place keepsake | 8 | 1024x1024 alpha | identical foot baseline | Places paper/stone, no reward pose. |
| Keeper | Wave / acknowledge | 6 | 1024x1024 alpha | identical foot baseline | Subtle greeting only. |
| Visitor | Idle | 6 | 1024x1024 alpha | identical foot baseline | Calm companion presence. |
| Visitor | Arrive | 8 | 1024x1024 alpha | identical foot baseline | Enters from path edge. |
| Visitor | Offer keepsake | 8 | 1024x1024 alpha | identical foot baseline | Warm but restrained. |

## Acceptance Criteria

- Real transparent PNG alpha, not a baked checkerboard.
- Same character proportions across every frame.
- Same camera angle, outfit, face, and lighting across a full action.
- Feet stay on the same baseline unless a step explicitly moves forward.
- No purple fringe, pixelated outline, badge, UI, text, logo, or reward language.
- Motion reads as quiet and therapeutic, not mascot bounce.

## Reference

`GardenKeeperRefinedMotionReference.png` is a visual direction reference only. It is not production-ready because it has a baked checkerboard background.

`GardenKeeperRefinedExtractedContact.png` shows the extracted runtime frames with a shared baseline for visual QA.

`GardenKeeperWalkSmoothContact.png`, `GardenKeeperInspectSmoothContact.png`, and `GardenKeeperPlaceSmoothContact.png` document the current runtime motion sets.

`GardenVisitorRefinedMotionReference.png` and `GardenVisitorRefinedExtractedContact.png` document the same treatment for the visitor.
