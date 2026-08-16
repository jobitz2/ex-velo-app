# Ex-Velo — iOS App Feature & Capability Assessment

**Goal:** iOS app (Swift, Xcode) that observes a baseball swing and the resulting hit, and reports:
1. Exit velocity (ball speed immediately after bat contact)
2. Launch angle (vertical angle of the ball off the bat)
3. Estimated hit distance (derived from #1 and #2)

Camera + on-device compute only — no external radar/sensor hardware for the MVP.

---

## 1. Feasibility check — this has been done before

Camera-only exit velocity / launch angle capture on iPhone is a proven, shipping category, not a research bet:

- **Blast Vision** (Blast Motion) — uses an iPhone/iPad camera alone to output launch angle, exit velocity, and estimated carry distance; recommends the phone be placed 10+ ft from contact.
- **b4 App** — swing analysis, launch angle, exit velocity, bat path from iPhone video.
- **SmartScout Baseball** — AI analysis of exit velocity/launch angle from a recorded iPhone clip.
- **SmartPitch** — exit velocity, launch angle, and hit distance from ordinary smartphones.
- **Rapsodo** (dedicated hardware) — combines a high-speed camera with radar: detects contact, then analyzes slow-motion footage of the ball's initial flight to derive exit speed, launch angle, and spin from the seams. Their consumer MLM1 unit pairs Doppler radar with an iPhone/iPad camera. This confirms the standard approach even for "real" hardware is: **detect contact → analyze only the first few frames of ball flight → extrapolate physics**, not track the ball to landing.
- **HitTrax / Trackman** — same category (camera/radar fusion), validating that exit velo + launch angle + distance is the standard stat trio for this whole product category.

Conclusion: a phone-camera-only MVP is realistic and matches how even professional-grade systems bootstrap their measurement (short observation window + physics extrapolation, not full-flight tracking).

## 2. Core technical approach

### 2.1 Ball detection & tracking — use `VNDetectTrajectoriesRequest`, not a custom model first

Apple's Vision framework ships a request built specifically for this problem: **`VNDetectTrajectoriesRequest`** (iOS 14+). It detects shapes moving along a parabolic path across a video frame sequence and returns `VNTrajectoryObservation` objects — a series of tracked points plus a fitted parabolic equation. Apple's own WWDC20 sample app, **"Action & Vision,"** demonstrates this exact use case: tracking a thrown/shot ball's trajectory and classifying the action with a Core ML action classifier. This is the correct starting point instead of training a custom ball-detector model — it's on-device, free, requires no training data, and is designed for "ball moving through a scene, ignore everything else" style noise filtering.

Fallback/upgrade path: if `VNDetectTrajectoriesRequest` struggles with cluttered backgrounds (batting cages with ball buckets, nets, multiple balls), a custom Core ML object detector (e.g., a small YOLO model fine-tuned on baseballs via Create ML) can replace or supplement it later — this is a V2 item, not MVP-blocking.

### 2.2 Capture — high frame rate via AVFoundation

- Use `AVCaptureSession` with a custom (non-default) configuration, `sessionPreset = .inputPriority`, and explicitly select an `AVCaptureDevice.Format` supporting the highest available frame rate (many iPhones support 720p/1080p @ 240 fps on the rear camera; front camera does not support 240 fps).
- Lock `activeVideoMinFrameDuration` / `activeVideoMaxFrameDuration` to the chosen rate after locking device configuration.
- At 100 mph exit velocity (~44.7 m/s), the ball crosses a narrow field of view in a handful of frames — 240 fps (vs. 30/60 fps default video) is what makes accurate speed/angle extraction possible at all. Frame rate capability should be detected at runtime and the app should warn when a device can't hit at least ~120 fps.
- Lock exposure/focus during capture (motion blur and autofocus hunting on a fast small object are the two biggest practical failure modes).

### 2.3 Contact-event detection (auto-trim)

Two viable approaches, can ship one now and add the other later:
- **MVP:** rolling capture buffer + manual "I just hit it" trim (record continuously into a short circular buffer, save/trim around the tap), same UX pattern used by golf swing apps.
- **V1:** audio onset detection via `AVAudioEngine` tap on the mic buffer, looking for the "crack of the bat" transient (amplitude/spectral-flux spike) to auto-trigger trimming — removes user friction entirely.

### 2.4 The monocular scale problem (this is the crux of the whole app)

A single 2D camera has no inherent sense of real-world scale — pixel displacement per frame isn't speed until you know distance-to-subject. This needs a deliberate **CalibrationEngine**, not an afterthought. Three tiers, in increasing accuracy/complexity, designed as swappable strategies behind one protocol:

1. **Known-object-size calibration (MVP):** a baseball's diameter is fixed (~2.9 in / 7.35 cm). Combined with the camera's focal length (available from capture device intrinsics), the ball's apparent pixel diameter in each frame gives distance-to-ball per frame — which converts pixel displacement into real-world velocity. This is very likely what Blast Vision / SmartPitch use, since it requires no extra hardware and works from a single fixed camera.
2. **Fixed/guided placement calibration (MVP fallback):** user places the phone at an app-specified distance/height/angle (onboarding "framing guide" with a live level indicator via `CoreMotion`), and the app uses that known geometry directly as a sanity check / second estimate against #1.
3. **LiDAR depth calibration (V2, Pro devices only):** iPhone Pro models expose true per-pixel depth (`AVDepthData` / ARKit scene depth). Where available, this removes the scale ambiguity entirely and should be auto-selected as the preferred strategy.

### 2.5 Velocity & launch angle extraction

Once real-world 3D (or scaled-2D) ball positions are known for several frames immediately after contact:
- Fit those points to a parabolic model via least-squares regression to recover the initial velocity vector `(vx, vy)` at the moment of contact.
- **Exit velocity** = `sqrt(vx² + vy²)`.
- **Launch angle** = `atan2(vy, vx)` (relative to horizontal, using the `CoreMotion`-derived level as the horizontal reference).

### 2.6 Distance — do not use vacuum-physics range formula

The naive projectile-range formula (`R = v²·sin(2θ)/g`) ignores air drag and will overestimate real batted-ball distance by a large margin (drag matters a lot for baseballs at these speeds). The standard, publicly documented approach (used across the Statcast/sabermetrics community, originating from physicist Alan Nathan's baseball trajectory work) numerically integrates the flight forward from the measured exit velocity + launch angle, applying baseball drag coefficients (and, optionally, Magnus lift if spin rate is estimated or defaulted from a league-average table by launch-angle bucket). This should be ported as a small deterministic physics module rather than a lookup table, so it can later accept real spin data as an enhancement input without changing its interface.

## 3. Required iOS frameworks / APIs

| Framework | Purpose |
|---|---|
| `AVFoundation` | Custom high-fps capture session, `AVAssetWriter` for saved clips |
| `Vision` | `VNDetectTrajectoriesRequest`, `VNTrajectoryObservation`, `VNSequenceRequestHandler` |
| `CoreMotion` | Device level/tilt for framing guide and horizontal reference |
| `AVAudioEngine` / `Accelerate` | Bat-contact audio onset detection (auto-trim) |
| `Core ML` / `Create ML` | Optional V2 custom ball detector / contact-frame classifier |
| `ARKit` / depth APIs | Optional LiDAR-based calibration on Pro devices |
| `SwiftData` (or Core Data) | Persist players, sessions, swings |
| `Swift Charts` | Trend visualization (EV/LA over time, distance distribution) |
| `SwiftUI` + Swift Concurrency | UI and async capture→analysis pipeline |
| `AVKit` | Clip playback with a synced trajectory/metric overlay |
| `PhotosKit` (optional) | Export annotated clips |

## 4. Feature scope by milestone

**MVP — controlled setup (tee / soft toss), proves the core pipeline works**
- Custom capture screen: highest-available frame rate, on-screen framing guide, live level indicator
- Manual record + trim around the hit
- `VNDetectTrajectoriesRequest`-based ball tracking on the saved clip
- Known-object-size calibration (ball diameter) with guided-placement fallback
- Compute and display exit velocity, launch angle, estimated distance (drag-model, not vacuum formula)
- Local history of swings (SwiftData), each with a thumbnail

**V1 — usable training tool**
- Automatic contact detection via audio onset (hands-free trimming)
- Trajectory overlay animation on clip playback with metric readout
- Player profiles, session history, trend charts (avg/max EV, LA distribution, distance chart)
- Confidence indicator per swing (based on tracked-point count, achieved frame rate, lighting) — camera-only measurement should always be labeled as an *estimate*, not a radar-grade reading
- Export (CSV/JSON) and share clips with metrics burned in

**V2 — differentiated / higher accuracy**
- Custom-trained Core ML ball detector for cluttered backgrounds (cages, ball buckets)
- LiDAR-based calibration on Pro devices, auto-selected when available
- Seam-tracking spin-rate estimate to improve the distance model's realism (Magnus effect)
- Optional second-device stereo capture (two iPhones synced) to remove monocular scale ambiguity entirely — most accurate option, higher setup cost
- CloudKit sync across a user's devices; coach/team multi-player mode

## 5. Risks & non-functional constraints to design around from day one

- **Accuracy framing:** this is a monocular-camera estimate, not a certified radar reading. Expect real error margins vs. Rapsodo/Trackman-class hardware. Product copy and UI should say "estimated," and the confidence indicator (V1) should make tracking quality visible rather than presenting every number with false precision.
- **Lighting/background sensitivity:** Vision-based tracking degrades with poor contrast, cluttered backgrounds, or dim indoor cages — onboarding should coach camera placement and lighting.
- **FOV vs. frame-rate tradeoff:** a 100 mph ball crosses a narrow FOV in very few frames at high fps; camera-placement guidance is a UX requirement, not just a backend detail.
- **Device capability spread:** not all iPhones support 240 fps; the app must detect capability at runtime and degrade gracefully (warn, or use a wider-but-lower-fps format) rather than assuming a rate.
- **Privacy:** all processing should be on-device (good privacy story, and avoids upload latency); still requires `NSCameraUsageDescription` / `NSMicrophoneUsageDescription`.
- **Xcode beta:** building against a beta toolchain means new/beta-only APIs may be tempting but should be avoided for the core pipeline unless they degrade gracefully on shipping OS versions — confirm actual deployment target before relying on anything beta-exclusive.

## 6. Recommended module architecture

```
CaptureKit        — capture session, format/frame-rate selection, framing guide, level indicator
VisionPipeline     — trajectory detection over the frame sequence, buffering, request handling
CalibrationEngine  — protocol-based: KnownObjectSizeCalibration, GuidedPlacementCalibration, LiDARCalibration
PhysicsEngine      — velocity/launch-angle regression from tracked points; drag-based flight/distance model
SwingStore         — SwiftData models: Player, Session, Swing
UI (SwiftUI)       — CaptureView, CalibrationView, ReviewView (clip + overlay), HistoryView, StatsView
```

This separation lets the calibration strategy and the distance model evolve (guided placement → known-object-size → LiDAR; vacuum formula → drag model → drag+spin model) without touching capture or UI code.

## Sources

- [Blast Vision Ball Flight App for Baseball, Softball, or Golf](https://blastmotion.com/blog/ball-flight-app/)
- [b4-app](https://www.b4-app.com/)
- [SmartScout Baseball - App Store](https://apps.apple.com/us/app/smartscout-baseball/id6744098755)
- [App Function | SmartPitchBaseball](https://www.smartpitchbaseball.com/app-function)
- [Baseball Hitting Technology Guide: Rapsodo, HitTrax & PitchCom](https://baseballtips.com/baseball-hitting-technology-guide/)
- [Rapsodo® MLM1 - Mobile Launch Monitor](https://rapsodo.com/products/mlm1-mobile-launch-monitor)
- [Rapsodo Review | Baseball & Softball Launch Monitor Tests](https://batdigest.com/blog/rapsodo-review/)
- [VNDetectTrajectoriesRequest | Apple Developer Documentation](https://developer.apple.com/documentation/vision/vndetecttrajectoriesrequest)
- [Explore the Action & Vision app - WWDC20 - Apple Developer](https://developer.apple.com/videos/play/wwdc2020/10099/)
- [Technical Note TN2409: New AV Foundation Camera Features for the iPhone 6 and iPhone 6 Plus](https://developer.apple.com/library/archive/technotes/tn2409/_index.html)
- [Where Is The Ball: 3D Ball Trajectory Estimation From 2D Monocular Tracking (CVPR 2025)](https://openaccess.thecvf.com/content/CVPR2025W/CVSPORTS/papers/Ponglertnapakorn_Where_Is_The_Ball_3D_Ball_Trajectory_Estimation_From_2D_CVPRW_2025_paper.pdf)
