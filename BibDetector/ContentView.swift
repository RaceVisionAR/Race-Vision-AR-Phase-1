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
                if let rect = appModel.overlayRect {
                    let displayName = appModel.matchedRunner?.displayName ?? "Bib \(appModel.latestDetection?.bibNumber ?? "")"
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green, lineWidth: 2)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)

                    Text(displayName)
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.75), in: Capsule())
                        .foregroundStyle(.white)
                        .position(
                            x: clamp(rect.midX, min: 70, max: geometry.size.width - 70),
                            y: max(20, rect.minY - 18)
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("BibDetector MVP")
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
        }
    }

    private func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.max(minimum, Swift.min(maximum, value))
    }
}

#Preview {
    ContentView()
        .environmentObject(AppModel())
}
