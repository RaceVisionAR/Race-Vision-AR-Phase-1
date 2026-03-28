# BibDetector

An iOS prototype that uses augmented reality and computer vision to detect race bib numbers in real time and display a runner's name and details as an AR overlay above them.

---

## Requirements

- **Xcode** 15 or later
- **iOS** 16 or later
- **Physical iPhone** with an A-series chip (ARKit and Vision do not run in the simulator)
- An **Apple Developer account** (free tier works) for device signing

No third-party dependencies. The project uses only Apple frameworks — no CocoaPods, Swift Package Manager packages, or Carthage.

---

## How to Build and Run

1. Clone the repository:
   ```bash
   git clone https://github.com/RabinApps/BibDetectorNative.git
   cd BibDetectorNative
   ```

2. Open the project in Xcode:
   ```bash
   open BibDetector.xcodeproj
   ```

3. Connect your iPhone via USB.

4. In Xcode's toolbar, click the destination selector and choose your iPhone (not "My Mac").

5. Select the `BibDetector` scheme if it is not already selected.

6. Go to **BibDetector target → Signing & Capabilities** and set the **Team** to your Apple ID.

7. Press **Cmd+R** or click the Run button.

8. On first launch, grant camera access when prompted.

> **Note:** Building for "My Mac" will fail with a `UIKit` import error — the app requires iOS and an ARKit-capable device.

---

## How Bib Detection Works

The detection pipeline runs continuously while the camera is live and consists of four stages:

### 1. AR Camera Feed (`ARCameraView.swift`)
`ARSCNView` (ARKit's scene view) provides a live camera feed and calls `session(_:didUpdate:)` on every frame at ~60 fps. Each frame's `CVPixelBuffer` is passed to the OCR stage.

### 2. OCR via Vision (`BibOCRService.swift`)
Frames are sampled at 5 fps (every 200 ms) to avoid overloading the device. Each sampled frame is processed by `VNRecognizeTextRequest` from Apple's Vision framework:

- **Orientation:** The raw camera buffer is landscape (e.g. 1920×1440). The request is initialised with `orientation: .right` so Vision treats it as portrait-oriented — matching what the user sees on screen.
- **Recognition level:** `.fast` for near real-time performance.
- **Language correction:** Disabled, since bib numbers are digits and correction would introduce errors.

Each text observation is passed to `BibParser`, which strips non-digit characters and accepts only strings of 2–5 digits as valid bib candidates. Duplicate detections of the same bib number keep only the highest-confidence result.

### 3. Stabilisation and Tracking (`AppModel.swift`)
Raw OCR results are noisy — the same bib may flicker in and out between frames. `AppModel` uses a confidence and consistency model to suppress noise:

- A bib must be detected **3 times within an 0.8 s window** before it is considered stable.
- Once stable, the bib is matched against the runner dataset and an overlay card is created.
- Overlays stay on screen for **1.0 s after the bib was last seen**, then fade out over **0.35 s**.
- At most **4 overlay cards** are shown simultaneously.

### 4. Coordinate Conversion (`AppModel.convertVisionRectToView`)
Vision's bounding boxes are in normalised portrait space (origin bottom-left, y-up). The screen is portrait but the camera sensor is physically landscape, and `ARSCNView` aspect-fills the feed into the view — cropping the sides. The conversion accounts for this:

- The camera's actual resolution is read from `ARFrame.camera.imageResolution` each frame.
- The portrait aspect ratio (`cameraHeight / cameraWidth`) is compared to the view's aspect ratio.
- The displayed width and side-crop offset are computed, then applied to map Vision coordinates to UIKit points.

### 5. AR Overlay (`ContentView.swift`)
SwiftUI overlay cards are rendered on top of the `ARSCNView` using `.position()`. Each card shows:
- Runner's full name
- Nickname (if different from name)
- Bib number and race category (accent colour)
- Team name

Cards are green when the bib matches a known runner and yellow for unrecognised bibs.

---

## Runner Dataset

Stored in `BibDetector/Resources/runners.json`. The app ships with 10 runners. To add more, append entries following this format:

```json
{
  "bibNumber": "101",
  "name": "Jordan Alvarez",
  "nickname": "Jordy",
  "team": "City Striders",
  "category": "Half Marathon"
}
```

`nickname`, `team`, and `category` are optional. Changes take effect on the next build.

---

## External Libraries and Frameworks

All frameworks are part of the iOS SDK — no external dependencies are required.

| Framework | Purpose |
|-----------|---------|
| **ARKit** | AR session, world tracking, live camera frame delivery |
| **Vision** | On-device OCR (`VNRecognizeTextRequest`) |
| **SwiftUI** | UI, overlay cards, layout |
| **UIKit** | `UIViewRepresentable` bridge for `ARSCNView` |
| **AVFoundation** | Camera permission request |
| **Combine** | `@Published` / `ObservableObject` state propagation |
| **CoreGraphics** | Coordinate geometry (`CGRect`, `CGAffineTransform`) |
| **Swift Testing** | Unit tests (`@Test`, `#expect`) |

---

## Project Structure

```
BibDetector/
├── AR/
│   └── ARCameraView.swift          # UIViewRepresentable wrapping ARSCNView
├── Models/
│   ├── RunnerProfile.swift         # Codable runner data model
│   └── TrackedRunnerOverlay.swift  # Per-bib tracking state
├── Services/
│   ├── BibOCRService.swift         # Vision OCR, runs as a Swift actor
│   ├── BibParser.swift             # Digit extraction and variant generation
│   └── RunnerRepository.swift      # In-memory runner lookup
├── Resources/
│   └── runners.json                # Runner dataset (10 entries)
├── AppModel.swift                  # Main state, detection pipeline, lifecycle
└── ContentView.swift               # Root SwiftUI view and overlay rendering

BibDetectorTests/
└── BibDetectorTests.swift          # Unit tests for parser, repository, and AppModel
```
