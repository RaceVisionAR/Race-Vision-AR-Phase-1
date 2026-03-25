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
        .task {
            appModel.start()
        }
    }

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
                guard let url = URL(string: UIApplication.openSettingsURLString) else {
                    return
                }
                UIApplication.shared.open(url)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var overlayView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(appModel.visibleTracks) { track in
                    overlayCard(for: track, in: geometry.size)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("BibDetector Multi-Runner")
                        .font(.headline)
                    Text(appModel.debugStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.top, 12)
                .padding(.leading, 12)
            }
            .animation(.easeInOut(duration: 0.25), value: appModel.trackedOverlays)
        }
    }

    @ViewBuilder
    private func overlayCard(for track: TrackedRunnerOverlay, in viewSize: CGSize) -> some View {
        let rect = track.overlayRect
        let accentColor: Color = track.runnerProfile == nil ? .yellow : .green

        RoundedRectangle(cornerRadius: 8)
            .stroke(accentColor, lineWidth: 2)
            .frame(width: rect.width, height: rect.height)
            .opacity(track.overlayOpacity)
            .position(x: rect.midX, y: rect.midY)

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
                if let team = profile.team {
                    Text(team)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
            } else {
                Text("Bib \(track.bibNumber)")
                    .font(.caption.bold())
                Text("# \(track.bibNumber)")
                    .font(.caption2)
                    .foregroundStyle(accentColor.opacity(0.9))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 8))
        .foregroundStyle(.white)
        .opacity(track.overlayOpacity)
        .position(
            x: clamp(rect.midX, min: 88, max: viewSize.width - 88),
            y: max(24, rect.minY - 22)
        )
    }

    private func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.max(minimum, Swift.min(maximum, value))
    }
}

#Preview {
    ContentView()
        .environmentObject(AppModel())
}
