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

class CameraViewModel: NSObject, ObservableObject {
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()

    @Published var frameImage: HandPoseImage?
    @Published @MainActor var canPrediect: Bool = false

    @Published @MainActor var recognisedNumber: String = ""
    @Published @MainActor var readingNumber: String = ""
    @Published @MainActor var readingPct: Double = 0.0

    private var frameCount: Int = 0 {
        didSet {
            Task { @MainActor in
                readingPct = Double(frameCount) / Double(Self.frameCountMax) * 100.0
                if readingPct > 100 { readingPct = 100.0 }
            }
        }
    }

    private var prevMessage: String = ""

    /// Max number of frames with same number before registering as output number.
    private static var frameCountMax: Int = 30

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
                            if prediction.label != readingNumber {
                                frameCount = 0
                                readingNumber = prediction.label
                            } else {
                                if readingNumber != prevMessage {
                                    if frameCount > Self.frameCountMax {
                                        recognisedNumber = readingNumber
                                        frameCount = Self.frameCountMax
                                        prevMessage = readingNumber
                                    } else {
                                        frameCount += 1
                                    }
                                }
                            }
                        } else {
                            readingNumber = "???"
                        }
                        canPrediect = true
                    } else {
                        print("WARN: ML not initialised!")
                    }
                } else {
                    readingNumber = ""
                    prevMessage = ""
                    frameCount = 0
                    recognisedNumber = ""
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

