//
//  ContentView.swift
//  BibDetector
//
//  Created by Alex Rabin on 3/16/26.
//

import AVFoundation
import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    /// Tracks each card's rendered size keyed by bib number, used for edge clamping.
    @State private var cardSizes: [String: CGSize] = [:]

    private var isTestRace: Bool { appModel.selectedRace?.isTestRace ?? false }

    var body: some View {
        ZStack {
            if !appModel.isARSupported {
                unsupportedView
            } else if appModel.cameraAuthorizationStatus == .denied || appModel.cameraAuthorizationStatus == .restricted {
                permissionDeniedView
            } else {
                ARCameraView { frame, viewSize in
                    appModel.processFrame(frame, viewSize: viewSize)
                }
                .ignoresSafeArea()

                overlayView
            }
        }
        .task { appModel.start() }
        .navigationBarHidden(true)
    }

    // MARK: - Error states

    private var unsupportedView: some View {
        VStack(spacing: 12) {
            Text("AR Not Supported")
                .font(.title2.bold())
            Text("This prototype requires an AR-capable iPhone.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 12) {
            Text("Camera Access Required")
                .font(.title2.bold())
            Text("Enable camera access in Settings to detect bib numbers.")
                .foregroundStyle(.secondary)
            Button("Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - AR overlay

    private var overlayView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(appModel.visibleTracks) { track in
                    overlayCard(for: track, in: geometry.size)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .ignoresSafeArea()
                }

                // Bottom-center: stabilizing indicator
                if appModel.isProbingBibs && appModel.visibleTracks.isEmpty {
                    scanningIndicator
                }

                // Top-left: status pill
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(appModel.selectedRace?.displayName ?? "RaceVisionAR")
                            .font(.headline)

                        if isTestRace {
                            Text("TEST")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.orange.opacity(0.2), in: Capsule())
                        } else if appModel.isLoadingRunners {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.secondary)
                        } else if appModel.isOffline {
                            Image(systemName: "wifi.slash")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    Text(appModel.debugStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.top, 12)
                .padding(.leading, 12)

                // Top-right: change race + sign out
                HStack(spacing: 8) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "flag.checkered")
                            .padding(10)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        appModel.reset()
                        try? authService.signOut()
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .padding(10)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.top, 12)
                .padding(.trailing, 12)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .animation(.easeInOut(duration: 0.25), value: appModel.trackedOverlays)
            .onPreferenceChange(CardSizeKey.self) { cardSizes = $0 }
        }
    }

    // MARK: - Runner overlay card

    @ViewBuilder
    private func overlayCard(for track: TrackedRunnerOverlay, in viewSize: CGSize) -> some View {
        let rect = track.overlayRect
        let accentColor: Color = isTestRace ? .orange : (track.runnerProfile == nil ? .yellow : .green)

        VStack(alignment: .leading, spacing: 3) {
            if let profile = track.runnerProfile {
                Text(profile.name)
                    .font(.caption.bold())
                if let nickname = profile.nickname, !nickname.isEmpty, nickname != profile.name {
                    Text("\"\(nickname)\"")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                }
                HStack(spacing: 6) {
                    Text("# \(profile.bibNumber)")
                    if let category = profile.category, !category.isEmpty {
                        Text("·")
                        Text(category)
                    }
                }
                .font(.caption2)
                .foregroundStyle(accentColor.opacity(0.9))
                if let team = profile.team, !team.isEmpty {
                    Text(team)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            isTestRace
                ? RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.5), lineWidth: 1)
                : nil
        )
        .foregroundStyle(.white)
        .opacity(track.overlayOpacity)
        .modifier(ClampedPositionModifier(rect: rect, viewSize: viewSize, trackID: track.id))
    }

    // MARK: - Scanning indicator

    /// Pulsing pill shown while a bib is being stabilized but no card has appeared yet.
    private var scanningIndicator: some View {
        ScanningPill()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 48)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .allowsHitTesting(false)
    }
}

// MARK: - Scanning pill

private struct ScanningPill: View {
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(Color.green)
                .frame(width: 7, height: 7)
                .scaleEffect(pulsing ? 1.3 : 0.8)
                .animation(
                    .easeInOut(duration: 0.65).repeatForever(autoreverses: true),
                    value: pulsing
                )
            Text("Scanning…")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(.black.opacity(0.72), in: Capsule())
        .onAppear { pulsing = true }
    }
}

// MARK: - Card size preference key

/// Collects each overlay card's rendered CGSize keyed by bib number.
private struct CardSizeKey: PreferenceKey {
    static let defaultValue: [String: CGSize] = [:]
    static func reduce(value: inout [String: CGSize], nextValue: () -> [String: CGSize]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Clamped position modifier

/// Positions an overlay card above the detected bib rect, clamping to the view
/// bounds using the card's actual rendered size so it never clips at the edges.
private struct ClampedPositionModifier: ViewModifier {
    let rect: CGRect
    let viewSize: CGSize
    let trackID: String

    @State private var cardSize: CGSize = CGSize(width: 160, height: 60)

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: CardSizeKey.self,
                        value: [trackID: geo.size]
                    )
                }
            )
            .onPreferenceChange(CardSizeKey.self) { sizes in
                if let s = sizes[trackID] { cardSize = s }
            }
            .position(
                x: clampedX,
                y: clampedY
            )
    }

    private var halfW: CGFloat { cardSize.width / 2 }
    private var halfH: CGFloat { cardSize.height / 2 }
    private let edgePadding: CGFloat = 8

    private var clampedX: CGFloat {
        let ideal = rect.midX
        let lo = halfW + edgePadding
        let hi = viewSize.width - halfW - edgePadding
        return min(max(ideal, lo), hi)
    }

    private var clampedY: CGFloat {
        let ideal = rect.minY - halfH - 8   // 8 pt gap above the bib
        let lo = halfH + edgePadding
        let hi = viewSize.height - halfH - edgePadding
        return min(max(ideal, lo), hi)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppModel())
        .environmentObject(AuthService())
}
