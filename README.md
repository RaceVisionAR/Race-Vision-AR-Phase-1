# BibDetector

BibDetector is a SwiftUI + ARKit prototype that detects race bib numbers from live camera frames, stabilizes OCR results over time, and overlays the matched runner name directly on top of the bib in the camera view.

The app is designed as a lightweight MVP focused on real-time detection flow, actor-safe concurrency, and a clean separation between UI, frame processing, OCR, parsing, and runner lookup.

## What The App Does

- Streams live frames from ARKit.
- Runs OCR on each sampled frame using Apple Vision text recognition.
- Extracts bib candidates (digits only, 2 to 5 characters).
- Stabilizes noisy frame-by-frame OCR results with a short time-window voting strategy.
- Matches stabilized bib numbers against local runner data.
- Draws a bounding box and runner label overlay in real time.

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
  - Throttles OCR, tracks detection history, stabilizes results, maps coordinates, updates UI state.
- `BibDetector/Services/BibOCRService.swift`
  - `actor` that performs Vision OCR and returns best candidate + confidence + bounding box.
- `BibDetector/Services/BibParser.swift`
  - Pure parsing helpers for bib normalization and variant generation.
- `BibDetector/Services/RunnerRepository.swift`
  - Loads runner records from `runners.json` and resolves bib to profile.
- `BibDetector/Models/BibDetection.swift`
  - Detection model (bib, confidence, bounding box, timestamp).
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
- Highest-confidence candidate in that frame becomes `OCRBibResult`.

7. Temporal stabilization

- `AppModel` stores short-lived detection history.
- Stale entries are removed (`staleDetectionTTL = 1.2s`).
- Detections are grouped by bib number; strongest group wins.
- Tie-breaker uses sum of confidence; then best confidence in winning group is selected.

8. Runner matching and overlay

- `RunnerRepository.matchRunner` tries bib variants (including leading-zero normalization).
- Vision normalized bounding box is converted to view coordinates.
- UI updates:
  - green rectangle over the bib
  - label with nickname/name
  - debug status text

## Concurrency Model

- `AppModel` is `@MainActor` to keep UI state mutations serialized and safe.
- `BibOCRService` is an `actor` to isolate OCR work.
- Frame processing uses a MainActor task with `defer` to guarantee `isProcessingFrame` cleanup.
- `BibParser` helper methods are marked `nonisolated` because they are pure stateless utilities and can be called from any isolation domain.

This architecture avoids actor isolation warnings while keeping frame flow responsive.

## Data Model Notes

- `OCRBibResult`: per-frame OCR output used internally by app model.
- `BibDetection`: stabilized candidate with timestamp and geometry.
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
- Basic UI launch tests

## Current Limitations

- OCR is configured for speed (`.fast`), which can reduce accuracy at distance or motion blur.
- Bib extraction assumes numeric bibs with 2 to 5 digits.
- Runner dataset is local static JSON (no remote sync).
- Overlay tracks OCR bounding box only; no advanced object tracking across frames.
- Real-world performance depends on lighting, bib typography, and camera stability.

## Tuning Knobs

In `AppModel`:

- `ocrInterval` (default `0.2`): lower for faster updates, higher for less CPU usage.
- `staleDetectionTTL` (default `1.2`): lower for quicker turnover, higher for more stability.

In `BibOCRService`:

- `recognitionLevel` can be switched to `.accurate` if quality is preferred over speed.

## Future Improvements

- Add confidence threshold before accepting detections.
- Use multi-frame tracking to smooth overlay movement.
- Add support for alphanumeric bib formats.
- Introduce remote runner directory and caching.
- Add benchmark metrics (frame rate, OCR latency, false positives).

## License

No license file is currently included in this repository.
