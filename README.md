# BibDetector

BibDetector is a SwiftUI + ARKit prototype that detects race bib numbers from live camera frames, stabilizes OCR results over time, and overlays matched runner cards directly on top of each detected bib in the camera view.

The app is designed as a lightweight MVP focused on real-time detection flow, actor-safe concurrency, and a clean separation between UI, frame processing, OCR, parsing, multi-track state, and runner lookup.

## What The App Does

- Streams live frames from ARKit.
- Runs OCR on each sampled frame using Apple Vision text recognition.
- Extracts bib candidates (digits only, 2 to 5 characters).
- Emits multiple valid bib detections per frame, deduplicated by normalized bib number.
- Stabilizes noisy frame-by-frame OCR results with a per-bib short time-window hit strategy.
- Matches stabilized bib numbers against local runner data.
- Draws one bounding box and runner card per visible bib in real time.

## Tech Stack

- SwiftUI for UI and app structure
- ARKit (`ARSCNView`, `ARSessionDelegate`) for camera frame stream
- Vision (`VNRecognizeTextRequest`) for OCR
- Swift Concurrency (`actor`, `Task`, `@MainActor`) for thread-safe processing
- XCTest / Swift Testing for unit and UI tests

## Project Structure

- `BibDetector/BibDetectorApp.swift`
  - App entry point, injects shared `AppModel` via `environmentObject`.
- `BibDetector/ContentView.swift`
  - Main screen and overlay UI.
  - Handles AR unsupported and camera-permission states.
- `BibDetector/AR/ARCameraView.swift`
  - `UIViewRepresentable` wrapper around `ARSCNView`.
  - Forwards each frame to the app model on `@MainActor`.
- `BibDetector/AppModel.swift`
  - Main state machine and orchestration layer.
  - Throttles OCR, maintains per-bib track state, stabilizes results, manages lifecycle, maps coordinates, updates UI state.
- `BibDetector/Services/BibOCRService.swift`
  - `actor` that performs Vision OCR and returns deduplicated bib candidates for the current frame.
- `BibDetector/Services/BibParser.swift`
  - Pure parsing helpers for bib normalization and variant generation.
- `BibDetector/Services/RunnerRepository.swift`
  - Loads runner records from `runners.json` and resolves bib to profile.
- `BibDetector/Models/BibDetection.swift`
  - Detection model (bib, confidence, bounding box, timestamp).
- `BibDetector/Models/TrackedRunnerOverlay.swift`
  - Per-bib overlay track model, including lifecycle state, detection history, matched runner, and screen-space rect.
- `BibDetector/Models/RunnerProfile.swift`
  - Runner model and display name logic.
- `BibDetector/Resources/runners.json`
  - Local sample runner database.

## End-To-End Runtime Flow

1. App launch

- `BibDetectorApp` creates one shared `AppModel`.
- `ContentView` starts model initialization via `.task { appModel.start() }`.

2. Permission and capability checks

- `AppModel` checks camera permission and AR support.
- UI displays fallback state if AR is unsupported or permission is denied.

3. Frame ingestion

- `ARCameraView` receives `ARSession` updates in its coordinator.
- Each frame is forwarded to `onFrameUpdate` inside `Task { @MainActor in ... }`.

4. Frame gating and throttling

- `AppModel.processFrame` applies fast guards:
  - AR must be supported.
  - Camera permission must be authorized.
  - OCR interval must be met (`ocrInterval = 0.2s`).
  - A previous OCR pass must not still be in flight.

5. OCR execution

- The frame pixel buffer is passed to `BibOCRService.detectBib`.
- Vision runs `VNRecognizeTextRequest` with:
  - language: `en_US`
  - recognition level: `fast`
  - language correction disabled

6. Candidate filtering

- OCR observations are reduced to top text candidates.
- `BibParser.normalizedBibCandidate` strips non-digits and only accepts length 2 to 5.
- Highest-confidence observation for each normalized bib becomes an `OCRBibResult`.

7. Multi-track stabilization

- `AppModel` maintains a bib-keyed track store.
- Each track keeps a short-lived detection history (`stabilizationWindow = 0.8s`).
- A card becomes visible after `consistentDetectionsRequired = 3` hits for the same bib.
- Visible tracks are held when temporarily lost (`visibleGracePeriod = 1.0s`), then faded and removed (`fadeOutDuration = 0.35s`).
- OCR noise is constrained with `minimumTrackConfidence = 0.35` and `maxTrackedCards = 4`.

8. Runner matching and overlay

- `RunnerRepository.matchRunner` tries bib variants (including leading-zero normalization).
- Each stabilized track resolves its runner profile once and keeps it for the life of that track.
- Vision normalized bounding boxes are converted to view coordinates per track.
- UI updates with one card per visible bib plus tracked-count debug status.

## Concurrency Model

- `AppModel` is `@MainActor` to keep UI state mutations serialized and safe.
- `BibOCRService` is an `actor` to isolate OCR work.
- Frame processing uses a MainActor task with `defer` to guarantee `isProcessingFrame` cleanup.
- `BibParser` helper methods are marked `nonisolated` because they are pure stateless utilities and can be called from any isolation domain.

This architecture avoids actor isolation warnings while keeping frame flow responsive.

## Data Model Notes

- `OCRBibResult`: per-frame OCR output used internally by app model.
- `BibDetection`: per-frame detection with timestamp and geometry.
- `TrackedRunnerOverlay`: per-bib track with visibility state, confidence history, and screen-space overlay rect.
- `RunnerProfile`: local profile keyed by bib number; display name prefers nickname.

## Running The App

### Requirements

- Xcode 17+
- iOS Simulator or physical iPhone
- ARKit-capable device for real camera/AR behavior

### Open And Run

1. Open `BibDetector.xcodeproj` in Xcode.
2. Select the `BibDetector` scheme.
3. Choose an iOS Simulator or device target.
4. Build and run.

### Camera Permission

The app requires camera permission and includes:

- `NSCameraUsageDescription`: "BibDetector uses the camera to detect race bib numbers and show runner overlays."

If permission is denied, use the in-app "Open Settings" button to re-enable access.

## Testing

Run tests from Xcode or terminal:

```bash
xcodebuild -scheme BibDetector -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Current tests include:

- Bib parser normalization behavior
- Runner repository matching with leading-zero fallback
- Track promotion / grace-period / fade lifecycle behavior
- Confidence floor and maximum-card capping behavior
- Basic UI launch tests

## Current Limitations

- OCR is configured for speed (`.fast`), which can reduce accuracy at distance or motion blur.
- Bib extraction assumes numeric bibs with 2 to 5 digits.
- Runner dataset is local static JSON (no remote sync).
- Overlay remains screen-space only; it does not use 3D anchors or long-term person re-identification.
- Real-world performance depends on lighting, bib typography, and camera stability.

## Tuning Knobs

In `AppModel`:

- `ocrInterval` (default `0.2`): lower for faster updates, higher for less CPU usage.
- `stabilizationWindow` (default `0.8`): larger window tolerates more OCR jitter before a track is discarded.
- `consistentDetectionsRequired` (default `3`): lower values show cards sooner, higher values reduce false positives.
- `visibleGracePeriod` (default `1.0`): how long a visible card stays fully shown after a miss.
- `fadeOutDuration` (default `0.35`): how long a stale visible card remains in the fade-out state before removal.
- `minimumTrackConfidence` (default `0.35`): floor for accepting per-frame OCR results into the track store.
- `maxTrackedCards` (default `4`): upper bound on simultaneously tracked overlays.

In `BibOCRService`:

- `recognitionLevel` can be switched to `.accurate` if quality is preferred over speed.

## Future Improvements

- Improve per-person motion smoothing beyond OCR bounding-box updates.
- Add support for alphanumeric bib formats.
- Introduce remote runner directory and caching.
- Add benchmark metrics (frame rate, OCR latency, false positives).

## License

No license file is currently included in this repository.
