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
On first launch you'll be asked for camera and microphone permission — both
are required (camera for capture, microphone is prepped for the V1 auto-trim
feature described in `docs/ASSESSMENT.md`).

## 5. Run the unit tests

The **ExVeloTests** target covers `PhysicsEngine` (velocity/launch-angle
regression and the drag-based distance model) with synthetic inputs, so it
runs on the Simulator without needing a device:

```
xcodebuild -project ExVelo.xcodeproj -scheme ExVelo \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Or press **Cmd+U** in Xcode with the ExVelo scheme selected.

## What to try first

1. Point the camera at a tee or soft-toss setup per the on-screen framing guide.
2. Tap **Mark Hit** right after contact — the app keeps a rolling buffer, so
   you don't need to start recording ahead of time.
3. After a short pause (post-roll capture), it analyzes the clip and shows
   exit velocity / launch angle / estimated distance, then opens a review
   screen with the clip and tracked trajectory overlaid.
4. Check **History** (top-right) for past swings.

See `docs/ASSESSMENT.md` for the full technical rationale and
`docs/CLI_PROMPT.md` for the original build brief this MVP was built from.
