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
    @Published @MainActor var frameImage: HandPoseImage?
    @Published @MainActor var recognisedNumber: String = ""
    @Published @MainActor var readingNumber: String = ""
    @Published @MainActor var readingPct: Double = 0.0

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()

    private var frameCount: Int = 0 {
        didSet {
            Task { @MainActor in
                readingPct = Double(frameCount) / Double(Self.frameCountMax) * 100.0
                if readingPct > 100 { readingPct = 100.0 }
            }
        }
    }

    private var canPredict: Bool = false
    private var prevMessage: String = ""

    /// Max number of frames with same number before registering as output number.
    private static var frameCountMax: Int = 30

    private var mlModel: HandPoseMLModel!

    lazy private var handPoseRequest: VNDetectHumanHandPoseRequest = {
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
                canPredict = true
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
        // Check if ML is not busy.
        guard canPredict else { return }

        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        Task { @MainActor in
            do {
                try imageRequestHandler.perform([handPoseRequest])
                if let observation = handPoseRequest.results?.first {
                    canPredict = false  // ML is busy now.
                    let poseMultiArray = try observation.keypointsMultiArray()
                    let input = HandPoseInput(poses: poseMultiArray)
                    if let prediction = try mlModel.predict(poses: input) {
                        if prediction.label != readingNumber {  // New number
                            frameCount = 0
                            readingNumber = prediction.label
                        } else {    // Same number
                            if readingNumber != prevMessage {
                                if frameCount > Self.frameCountMax {    // Got enough.
                                    recognisedNumber = readingNumber
                                    frameCount = Self.frameCountMax
                                    prevMessage = readingNumber
                                } else {    // Need more frames with this number.
                                    frameCount += 1
                                }
                            }
                        }
                    }
                    canPredict = true   // ML is now free.
                } else {
                    resetPrediction()
                }

            } catch {
                print("Error performing request: \(error)")
            }
        }
    }

    @MainActor
    private func resetPrediction() {
        readingNumber = ""
        prevMessage = ""
        frameCount = 0
        recognisedNumber = ""
        canPredict = true
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

