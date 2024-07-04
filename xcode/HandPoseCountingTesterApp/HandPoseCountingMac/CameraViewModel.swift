//
//  CameraViewModel.swift
//  HandPoseCountingMac
//
//  Created by Ace on 2/7/2024.
//

import AVFoundation
import SwiftUI
import Combine
import Vision
import CoreImage
#if os(iOS)
import UIKit
#endif

#if os(macOS)
typealias HandPoseImage = NSImage
#else
typealias HandPoseImage = UIImage
#endif

class CameraViewModel: NSObject, ObservableObject {
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()

    @Published var frameImage: HandPoseImage?
    @Published @MainActor var canPrediect: Bool = false
    @Published @MainActor var message: String = ""

    private var mlModel: HandPoseMLModel?

    lazy var handPoseRequest: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1
        return request
    }()

    override init() {
        super.init()
        setupCamera()

        Task {
            do {
                mlModel = try await HandPoseMLModel.loadMLModel()
            } catch {
                print("ERROR: Initialising ML classifier: \(error)")
            }
        }
    }

    private func setupCamera() {
        session.beginConfiguration()

        guard let camera = getCaptureDevice(),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            print("Error setting up camera input")
            return
        }

        session.addInput(input)

        let videoQueue = DispatchQueue(label: "videoQueue")
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        guard session.canAddOutput(videoOutput) else {
            print("Error adding video output")
            return
        }

        session.addOutput(videoOutput)
        session.commitConfiguration()
        session.startRunning()
    }

    private func predictHandPose(_ pixelBuffer: CVImageBuffer) {
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        Task { @MainActor in
            do {
                try imageRequestHandler.perform([handPoseRequest])
                if let observation = handPoseRequest.results?.first {
                    canPrediect = true
                    let poseMultiArray = try observation.keypointsMultiArray()
                    let input = HandPoseInput(poses: poseMultiArray)
                    if let ml = self.mlModel {
                        canPrediect = false
                        if let prediction = try ml.predict(poses: input) {
                            message = prediction.label
                        } else {
                            message = "???"
                        }
                        canPrediect = true
                    } else {
                        print("WARN: ML not initialised!")
                    }
                } else {
                    message = ""
                    canPrediect = false
                }

            } catch {
                print("Error performing request: \(error)")
            }
        }
    }

}

extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        handleDeviceOrientation(connection: connection)
        predictHandPose(pixelBuffer)
        updateFrameImage(pixelBuffer)
    }
}

/// Extension to handle platform dependencies, i.e. macOS vs iOS/iPadOS.
///
extension CameraViewModel {

#if os(iOS)
    private var deviceOrientation: UIDeviceOrientation {
        var orientation = UIDevice.current.orientation
        if orientation == UIDeviceOrientation.unknown {
            orientation = UIScreen.main.orientation
        }
        return orientation
    }
#endif

    func handleDeviceOrientation(connection: AVCaptureConnection) {
#if os(iOS)
        if connection.isVideoOrientationSupported,
           let videoOrientation = videoOrientationFor(deviceOrientation) {
            connection.videoOrientation = videoOrientation
        }
#endif
    }

    private func getCaptureDevice() -> AVCaptureDevice? {
#if os(macOS)
        guard let camera = AVCaptureDevice.default(for: .video) else {
            print("Error setting up camera input")
            return nil
        }
#else
        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video, position: .front
        ) else {
            print("Error setting up camera input")
            return nil
        }
#endif
        return camera
    }

    private func updateFrameImage(_ pixelBuffer: CVImageBuffer) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
#if os(macOS)
        let image = NSImage(cgImage: cgImage, size: .zero)
#else
        let image = UIImage(cgImage: cgImage)
#endif
        DispatchQueue.main.async {
            self.frameImage = image
        }
    }

#if os(iOS)
    private func videoOrientationFor(_ deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation? {
        switch deviceOrientation {
        case .portrait: return AVCaptureVideoOrientation.portrait
        case .portraitUpsideDown: return AVCaptureVideoOrientation.portraitUpsideDown
        case .landscapeLeft: return AVCaptureVideoOrientation.landscapeRight
        case .landscapeRight: return AVCaptureVideoOrientation.landscapeLeft
        default: return nil
        }
    }
#endif
}

#if os(iOS)
fileprivate extension UIScreen {
    var orientation: UIDeviceOrientation {
        let point = coordinateSpace.convert(CGPoint.zero, to: fixedCoordinateSpace)
        if point == CGPoint.zero {
            return .portrait
        } else if point.x != 0 && point.y != 0 {
            return .portraitUpsideDown
        } else if point.x == 0 && point.y != 0 {
            return .landscapeRight //.landscapeLeft
        } else if point.x != 0 && point.y == 0 {
            return .landscapeLeft //.landscapeRight
        } else {
            return .unknown
        }
    }
}
#endif

