## Plan: Multi-Runner AR Overlay Tracking

Implement multi-person, screen-space tracking by refactoring the app from one active detection to a per-bib track store. This keeps your current ARKit + Vision pipeline, adds multi-result OCR, and applies your chosen behavior: show after 2-3 consistent detections, keep briefly when lost, then fade/remove.

**Steps**

1. Phase 1: Expand OCR output to support multiple people.
2. Refactor [BibOCRService.swift](BibDetector/Services/BibOCRService.swift) so one frame can return multiple valid bib detections (deduplicated by normalized bib, highest confidence box per bib).
3. Keep bib normalization/filtering in [BibParser.swift](BibDetector/Services/BibParser.swift) as the single source of truth.
4. Phase 2: Replace single-runner state with per-runner track state.
5. Add a new tracked overlay model in [Models](BibDetector/Models) for one card’s state: bib, runner profile, latest bounding box, visibility status, confidence history, first-seen and last-seen timestamps.
6. Refactor [AppModel.swift](BibDetector/AppModel.swift) to replace latestDetection, matchedRunner, and overlayRect with a published collection keyed by bib number.
7. Update frame handling in [AppModel.swift](BibDetector/AppModel.swift) to iterate every OCR result per cycle, update existing tracks, create new tracks, and prevent duplicates for the same bib.
8. Add stabilization logic in [AppModel.swift](BibDetector/AppModel.swift): track becomes visible only after 2-3 consistent hits in the short time window.
9. Add lifecycle logic in [AppModel.swift](BibDetector/AppModel.swift): hold visible tracks during a grace period when not detected, then fade/remove.
10. Keep runner lookup from [RunnerRepository.swift](BibDetector/Services/RunnerRepository.swift) and run it per stabilized bib track.
11. Phase 3: Render multiple cards.
12. Refactor overlay rendering in [ContentView.swift](BibDetector/ContentView.swift) from single optional rect to a loop over visible tracks.
13. Render one card per track with per-card position clamping and smooth appearance/disappearance transitions.
14. Phase 4: Performance and UX guardrails.
15. Add confidence floor and max-cards cap in [AppModel.swift](BibDetector/AppModel.swift) to avoid noisy OCR overload.
16. Update debug/status messaging in [ContentView.swift](BibDetector/ContentView.swift) and [AppModel.swift](BibDetector/AppModel.swift) to include tracked count and recent stabilized bibs.
17. Update project docs in [README.md](README.md) to describe multi-person behavior and tuning knobs.

**Parallelism and Dependencies**

1. OCR multi-result work in [BibOCRService.swift](BibDetector/Services/BibOCRService.swift) must land before full multi-track logic in [AppModel.swift](BibDetector/AppModel.swift).
2. Track model creation and AppModel refactor can proceed in parallel once OCR return type is decided.
3. UI refactor in [ContentView.swift](BibDetector/ContentView.swift) depends on the new published track collection from [AppModel.swift](BibDetector/AppModel.swift).
4. README updates can happen in parallel with verification at the end.

**Relevant files**

1. [AppModel.swift](BibDetector/AppModel.swift): orchestration, stabilization threshold, lifecycle, published multi-track state.
2. [ContentView.swift](BibDetector/ContentView.swift): render one card per visible track.
3. [BibOCRService.swift](BibDetector/Services/BibOCRService.swift): emit multiple bib detections per frame.
4. [BibParser.swift](BibDetector/Services/BibParser.swift): normalization and candidate filtering reuse.
5. [RunnerRepository.swift](BibDetector/Services/RunnerRepository.swift): bib-to-runner matching reuse.
6. [BibDetection.swift](BibDetector/Models/BibDetection.swift): reuse per-detection geometry and timestamp.
7. [RunnerProfile.swift](BibDetector/Models/RunnerProfile.swift): reuse identity/display fields.
8. [README.md](README.md): document new behavior and tuning.

**Verification**

1. Build and run; confirm single-person flow still works.
2. Show two or more bibs simultaneously; verify separate cards appear only after 2-3 consistent detections.
3. Move camera and runners; verify each card follows its corresponding detection region.
4. Briefly occlude one bib; verify grace-period persistence, then fade/removal.
5. Re-introduce same bib; verify track resumes cleanly without duplicate cards.
6. Run tests:
7. xcodebuild -scheme BibDetector -destination 'platform=iOS Simulator,name=iPhone 17' test

**Decisions captured**

1. Overlay mode: 2D screen-following.
2. Card trigger: 2-3 consistent detections.
3. Card lifecycle: grace period, then fade/remove.
4. In scope: multi-person OCR-to-overlay tracking.
5. Out of scope: true 3D world anchors and long-term person re-identification beyond bib matching.

Plan has been saved to session memory and is ready for handoff to implementation.
