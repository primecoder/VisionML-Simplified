//
//  CameraViewModel+Devices.swift
//  HandPoseCountingTesterApp
//
//  Created by Ace on 2/7/2024.
//
import AVFoundation
import SwiftUI
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

    func getCaptureDevice() -> AVCaptureDevice? {
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

    func updateFrameImage(_ pixelBuffer: CVImageBuffer) {
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

