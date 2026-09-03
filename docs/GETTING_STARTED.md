# Getting Started in Xcode

## 1. Clone the repo

```
git clone https://github.com/jobitz2/ex-velo-app.git
cd ex-velo-app
git checkout claude/baseball-swing-app-assessment-3g3va5
```

(This branch is currently the repo's default branch, so a plain `git clone` +
`cd ex-velo-app` already lands you on it — the `checkout` line above is just
a safety net if that ever changes.)

## 2. Open the project

```
open ExVelo.xcodeproj
```

Or launch Xcode and use **File > Open...** to pick `ExVelo.xcodeproj` inside the
cloned folder.

## 3. Requirements

- **Xcode 16 or newer** (the project file uses `objectVersion = 77`, which needs
  Xcode 16+). This was built and tested against an Xcode 27 beta with the iOS 27 SDK.
- **iOS 17.0+** deployment target (already set on the target).
- A **physical iPhone** to actually test the camera/capture pipeline — the
  Simulator has no real camera, so `CaptureKit`/`VisionPipeline` can't be
  exercised there beyond confirming the app builds and launches. Running on a
  device the first time will prompt you to select your own Team under
  **Signing & Capabilities** (the project currently points at team
  `26B63JGT35`, from an earlier build on this machine — change it in Xcode if
  you're building under a different Apple ID/team).

## 4. Build & run

Pick the **ExVelo** scheme, choose your iPhone as the destination, and hit Run.
On first launch you'll be asked for camera permission — required to track the
ball.

## 5. Run the unit tests

The **ExVeloTests** target covers `PhysicsEngine` (speed regression from
tracked points) with synthetic inputs, so it runs on the Simulator without
needing a device:

```
xcodebuild -project ExVelo.xcodeproj -scheme ExVelo \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Or press **Cmd+U** in Xcode with the ExVelo scheme selected.

## What to try first

1. Point the camera at whoever's throwing or hitting, per the on-screen
   framing guide — the app is a live radar gun, not a recorder.
2. It's always scanning: as soon as a ball crosses the frame with enough
   tracked points to fit a trajectory, its speed (mph) appears as a big
   readout and holds until the next ball is tracked.
3. No tap, no clip, no history — this is a single continuous live reading,
   like a real radar gun.

Note: `docs/ASSESSMENT.md` and `docs/CLI_PROMPT.md` describe the original
batted-ball exit-velocity/launch-angle/distance MVP this app was built from
before it was rescoped into a live speed-only radar gun — the capture, Vision
tracking, and monocular-calibration rationale in `docs/ASSESSMENT.md` still
applies, but the calibration strategy is now known-object-size only, and
launch angle, distance, clip capture/review, and swing history no longer
exist in the app.
