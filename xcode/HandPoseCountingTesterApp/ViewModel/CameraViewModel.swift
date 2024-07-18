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

/// Provide access to device's camera, provide captured images for display, and
/// convert each image into ML MultiArray of hand poses. This viewmodel also utilises
/// ML model for converting hand poses to numbers from 1 - 10.
///
/// This implementation captures images as fast as they comes in, each frame is called One Reading.
/// Each reading then converted to SwiftUI image and perform hand-pose classification.
/// The same reading is required for upto N times (see `frameCountMax`) before a number
/// is registered as "recognised" and stored in `recognisedNumber'.
/// `
class CameraViewModel: NSObject, ObservableObject {
    /// Represents an image captured from device camera.
    @Published @MainActor var frameImage: HandPoseImage?

    /// ML classified number after the same number appears N times (see `frameCountMax`).
    @Published @MainActor var recognisedNumber: String = ""

    /// ML classified number for each frame (reading).
    @Published @MainActor var readingNumber: String = ""

    /// Percentage of the frames that the same number appears in proportion to `frameCountMax`.
    @Published @MainActor var readingPct: Double = 0.0

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()

    /// Current number of frames with the same reading number.
    /// Each update, `readingPct` is recalculated.
    private var frameCount: Int = 0 {
        didSet {
            Task { @MainActor in
                readingPct = Double(frameCount) / Double(Self.frameCountMax) * 100.0
                if readingPct > 100 { readingPct = 100.0 }
            }
        }
    }

    /// Indicates if ML classification should be performed for the current reading.
    private var canPredict: Bool = false

    /// Remember the previous message (reading number).
    private var prevMessage: String = ""

    /// Max number of frames with same number before registering as recognised number for output to client.
    private static var frameCountMax: Int = 30

    /// ML model for classifying hand poses to output labels.
    private var mlModel: HandPoseMLModel!

    /// Vision's hand-pose request to submit to Vision engine.
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

    /// Setup device's camera and start capturing images.
    ///
    /// It is required that this class conforms to `AVCaptureVideoDataOutputSampleBufferDelegate`.
    /// AVFoundation calls this delegate to process each frame captured from a device.
    ///
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
    
    @MainActor
    private func resetPrediction() {
        readingNumber = ""
        prevMessage = ""
        frameCount = 0
        recognisedNumber = ""
        canPredict = true
    }
}

/// Conform to AVCaptureVideoDataOutputSampleBufferDelegate to process each captured images.
///
extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        handleDeviceOrientation(connection: connection)
        predictHandPose(pixelBuffer)
        updateFrameImage(pixelBuffer)
    }
}

extension CameraViewModel {
    /// Classifies a captured image.
    ///
    /// This function is running in 2 isolation thread: 1) "videoQueue" that does capturing images;
    /// and 2) @MainActor that is used for displaying UI.
    ///
    /// For each image, a request is sent to Vision engine to see if any hand-pose is detected.
    /// If it does, MLMultiArray is created and passed onto ML engine to perform classification.
    /// If the same classified number appears N times, this number is registered as "Recognised".
    /// Otherwise, the frame count is reset.
    ///
    fileprivate func predictHandPose(_ pixelBuffer: CVImageBuffer) {
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
}

