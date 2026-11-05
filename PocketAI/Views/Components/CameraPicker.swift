//
//  CameraPicker.swift
//  PocketAI
//
//  Created by Pascal Jesenberger on 13/10/2026.
//

import SwiftUI
import UIKit
@preconcurrency import AVFoundation
import ImageIO

struct CameraPicker: View {
    let onCapture: (Data) -> Void
    let onClose: () -> Void
    @State private var camera = CameraModel()
    @State private var captureCount = 0

    var body: some View {
        ZStack {
            Color.black

            CameraPreview(session: camera.session)

            if camera.hasFlash {
                PanelButton(systemImage: camera.isFlashOn ? "bolt.fill" : "bolt.slash") {
                    camera.isFlashOn.toggle()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(16)
            }

            HStack {
                PanelButton(systemImage: "chevron.left", action: onClose)

                Spacer()

                Button {
                    captureCount += 1
                    Task {
                        if let data = await camera.capture() {
                            onCapture(data)
                        }
                    }
                } label: {
                    Circle()
                        .fill(.white)
                        .frame(width: 60, height: 60)
                        .padding(8)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact, trigger: captureCount)

                Spacer()

                PanelButton(systemImage: "arrow.triangle.2.circlepath") {
                    camera.flip()
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(16)
        }
        .task { await camera.start() }
        .onDisappear { camera.stop() }
    }
}

struct PanelButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

@Observable
private final class CameraModel: NSObject {
    let session = AVCaptureSession()
    var isFlashOn = false
    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "PocketAI.camera")
    private var input: AVCaptureDeviceInput?
    private var position: AVCaptureDevice.Position = .back
    private var continuation: CheckedContinuation<Data?, Never>?
    private var isConfigured = false

    var hasFlash: Bool {
        input?.device.hasFlash ?? false
    }

    func start() async {
        guard await AVCaptureDevice.requestAccess(for: .video), !Task.isCancelled else { return }
        if !isConfigured {
            configure()
        }
        let session = session
        sessionQueue.async {
            session.startRunning()
        }
    }

    func stop() {
        let session = session
        sessionQueue.async {
            session.stopRunning()
        }
    }

    func capture() async -> Data? {
        guard continuation == nil, session.isRunning else { return nil }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            let settings = AVCapturePhotoSettings()
            if output.supportedFlashModes.contains(.on) {
                settings.flashMode = isFlashOn ? .on : .off
            }
            output.capturePhoto(with: settings, delegate: self)
        }
    }

    func flip() {
        position = position == .back ? .front : .back
        session.beginConfiguration()
        if let input {
            session.removeInput(input)
        }
        addInput()
        session.commitConfiguration()
    }

    private func addInput() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let newInput = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(newInput) else { return }
        session.addInput(newInput)
        input = newInput
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        addInput()
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        session.commitConfiguration()
        isConfigured = true
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let data = photo.fileDataRepresentation().flatMap { $0.preparedForModel() }
        Task { @MainActor in
            continuation?.resume(returning: data)
            continuation = nil
        }
    }
}

extension Data {
    nonisolated func preparedForModel(maxDimension: CGFloat = 1024) -> Data? {
        guard let source = CGImageSourceCreateWithData(self as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image).jpegData(compressionQuality: 0.85)
    }
}
