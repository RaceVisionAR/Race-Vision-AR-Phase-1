import ARKit
import SwiftUI

struct ARCameraView: UIViewRepresentable {
    let onFrameUpdate: @MainActor (ARFrame, CGSize) -> Void

    func makeUIView(context: Context) -> ARSCNView {
        let sceneView = ARSCNView(frame: .zero)
        sceneView.automaticallyUpdatesLighting = true
        sceneView.session.delegate = context.coordinator

        if ARWorldTrackingConfiguration.isSupported {
            let configuration = ARWorldTrackingConfiguration()
            configuration.worldAlignment = .gravity
            sceneView.session.run(configuration)
        }

        context.coordinator.sceneView = sceneView
        return sceneView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        context.coordinator.sceneView = uiView
    }

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        uiView.session.pause()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onFrameUpdate: onFrameUpdate)
    }

    final class Coordinator: NSObject, ARSessionDelegate {
        var sceneView: ARSCNView?
        private let onFrameUpdate: @MainActor (ARFrame, CGSize) -> Void

        init(onFrameUpdate: @escaping @MainActor (ARFrame, CGSize) -> Void) {
            self.onFrameUpdate = onFrameUpdate
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            guard let sceneView else {
                return
            }

            let viewSize = sceneView.bounds.size
            Task { @MainActor in
                onFrameUpdate(frame, viewSize)
            }
        }
    }
}
