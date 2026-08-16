# Ex-Velo — CLI Kickoff Prompt

Paste this into Claude Code (or another coding CLI) inside Xcode / this repo to start building:

```
Build the MVP of "Ex-Velo," an iOS app (Swift, SwiftUI, Xcode) that measures a baseball's
exit velocity and launch angle immediately after bat contact, and derives an estimated hit
distance from those two values — using only the iPhone's camera, no external hardware.

Read docs/ASSESSMENT.md in this repo first — it has the full technical rationale, the
frameworks to use, and the architecture. Follow it. Summary of the required approach:

CORE PIPELINE
1. Capture: AVFoundation custom capture session, rear camera, highest available frame rate
   on-device (target 240fps, detect capability at runtime and gracefully fall back), locked
   exposure/focus during capture.
2. Contact trim: MVP = rolling buffer + manual "mark the hit" trim UI. (Auto audio-onset
   trimming is a fast-follow, not MVP-blocking.)
3. Ball tracking: use Vision's VNDetectTrajectoriesRequest over the trimmed frame sequence
   to get tracked ball positions (VNTrajectoryObservation). Do not start by training a
   custom Core ML detector — this Apple API is purpose-built for parabolic-motion tracking
   and is the correct MVP starting point.
4. Calibration (solves the monocular scale problem): implement a CalibrationEngine protocol
   with a first concrete strategy — KnownObjectSizeCalibration — using the baseball's fixed
   real-world diameter (~7.35cm) plus camera focal length to convert pixel displacement into
   real-world distance/velocity per frame. Add a GuidedPlacementCalibration fallback (user
   places phone at an app-specified distance, shown via an on-screen framing guide + a
   CoreMotion-based level indicator).
5. Physics: fit the post-contact tracked points to a parabola (least-squares) to recover the
   initial velocity vector. Exit velocity = magnitude of that vector. Launch angle = its
   angle above horizontal (horizontal reference from CoreMotion device level).
6. Distance: do NOT use the vacuum projectile-range formula (it overestimates real batted-
   ball distance because it ignores drag). Implement a small deterministic
   drag-based flight model (numerically integrate forward from exit velocity + launch angle
   using standard baseball drag coefficients; default a reasonable league-average backspin
   value since spin isn't measured yet) to produce the estimated distance.

ARCHITECTURE — keep these as separate, swappable modules (see docs/ASSESSMENT.md §6):
  CaptureKit        — capture session, format/frame-rate selection, framing guide, level UI
  VisionPipeline    — trajectory detection/buffering over the frame sequence
  CalibrationEngine — protocol + KnownObjectSizeCalibration + GuidedPlacementCalibration
  PhysicsEngine     — velocity/launch-angle regression + drag-based distance model
  SwingStore        — SwiftData models: Player, Session, Swing
  UI (SwiftUI)      — CaptureView, CalibrationView, ReviewView (clip playback + overlay),
                       HistoryView

MVP SCOPE (build in this order, get each working before the next):
  1. Project scaffold: SwiftUI app, target the latest non-beta-dependent deployment target
     this Xcode install supports cleanly; Info.plist camera/mic usage strings.
  2. CaptureKit: high-fps recording to a local file, with the framing-guide + level overlay.
  3. VisionPipeline: run VNDetectTrajectoriesRequest on a recorded clip, log/visualize the
     raw tracked points to confirm detection works before wiring up physics.
  4. CalibrationEngine: KnownObjectSizeCalibration first; GuidedPlacementCalibration as a
     manual-entry fallback.
  5. PhysicsEngine: velocity/launch-angle regression, then the drag-based distance model.
     Unit-test the physics module independently of the vision/capture code with known
     synthetic inputs (e.g., verify a known v/θ pair produces the expected drag-adjusted
     distance within a documented tolerance).
  6. SwingStore + minimal HistoryView: persist each swing's clip reference + EV/LA/distance.
  7. ReviewView: play back the clip with the tracked trajectory and metrics overlaid.

NON-NEGOTIABLE CONSTRAINTS
  - All processing on-device; no video/data leaves the device in this MVP.
  - Every displayed metric is explicitly labeled as an estimate (this is camera-based, not
    radar-grade) — do not imply certified accuracy in any UI copy.
  - Detect frame-rate capability at runtime; do not hardcode an assumed fps.
  - Keep CalibrationEngine and the distance model behind their protocols/interfaces so a
    LiDAR-based calibration strategy and a spin-aware distance model can be added later
    (V2, described in docs/ASSESSMENT.md) without touching capture, UI, or the rest of the
    pipeline.

Start by scaffolding the Xcode project and CaptureKit, get high-fps recording with the
framing guide working and confirmed on a real device/simulator constraint check, then move
to VisionPipeline. Report back after each numbered MVP step rather than building all of it
silently in one pass.
```
