# VisionML-Simplified

![Counting](docs/res/counting-small.gif)

Using Apple's Vision, HandPose, and Create/Core ML - simplified!

### The Goal

Learning (and any anything else in life) should be easy and fun. 
The goal for this article is to simplify the building block for using Apple's Machine Learning framework and its Vision 
framework to the bare minimum. Then, from thereon we can expand our understanding to tackle more complex work.

### The plan

1. Train ML Model to recognise and classify our hand-posture images
2. Get images from device's camera
3. Use our ML model to classify the images
4. Re-train our ML model, i.e. make it more accurate
5. Bob is your uncle and the world is our oyster. Let's do something cool about this!

### Requirements

1. A Mac. Preferrably Silicon M-series (mine is M1 with 16GB RAM)
2. Xcode 16 (beta 2) or newer

### Source code

A full source code used in this article can be downloaded (cloned) from my public Github here:

`git@github.com:primecoder/VisionML-Simplify.git`


## Part 1 - Create a (ML) Model

Xcode 16 (Beta), comes with Create ML tool which comes with several preset templates, 
i.e., Image Classification, Multi-label Image Classification, Hand Pose Classification. 
_Hand Pose Classification! Interesting!_
This is the first time I tried my hand on this UI tool. 

_Let's see how hard can it be?_

> Just some background, I have been using, creating, and training Core/Create ML before, but
> by coding, not by using this UI tool.

Embarrassing enough, it took me a while to find where to activate this tool.

![ML Create](docs/res/mlcreate-00.png)

![ML Create](docs/res/mlcreate-01.png)

I have to say, Apple did well on Easy-to-use department. I clicked around and just follow the
given instructions. Everything seemed to work (with only a few trail-and-error attempts).

![ML Create](docs/res/mlcreate-02.png)

_Right!_ Looking at the pop-up hint. 

It gave an instruction on the training process - It should be as simple as creating folder structure for training, testing, and validation. Then within each folder, create a sub-folder for each label. Then, my guess, for each label, give it a set of images that represent each number. _Easy!_

Let's prepare Training Directories and Data.

```bash
$ mkdir mldata
$ cd mldata
$ mkdir training testing validation
```

Create 10 sub directories for each.

```bash
$ cd training
$ mkdir 1 2 3 4 5 6 7 8 9 10
```

Repeate the above command for `testing` and `validation` folders.

Now, I just needed some images to train my Hand Pose classifier.

![ML Create](docs/res/wikipedia-finger-counting.png)

![ML Create](docs/res/training-folders.png)


Again, the goal at this stage is to simplify the training process as much as possible. We will keep it to minimum, i.e. 2 images for each label. I opted to not provide images for testing for now and let the tool auto generate test images by subsetting them from the training images. We can always come back here and retrain our ML model, see Part 4 below.
Once, Create ML tool has enough images, the train button should be enabled. 

Start training ML

![ML Create](docs/res/mlcreate-03.png)

Training

![ML Create](docs/res/mlcreate-04.png)

After training process is completed, you can inspecting the result in each tab.
You can even view a live preview!

![ML Create](docs/res/mlcreate-preview.gif)

Select on the Output tab, and click 'Get' to export as `.mlmodel` file. Give it any name. Note that this name will be used as a class name for our ML classifier during our coding phase.

![ML Create](docs/res/mlcreate-05.png)
![ML Create](docs/res/mlcreate-06.png)
![ML Create](docs/res/mlcreate-07.png)


## Part 2 - Capture Images from Camera

Now, we have a Machine Learning model that classifies hand-pose images. We need to get some images from somewhere to let our model to work with. We will use `AVFoundation` to capture images from device's camera and use them in our app. 

### Setup a camera

```swift
import AVFoundation
import Vision

class CameraViewModel: NSObject, ObservableObject {
    ...
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    ...

    override init() {
        super.init()
        setupCamera()
        ...
    }
}
```

```swift
    private func setupCamera() {
        session.beginConfiguration()

        guard let camera = getCaptureDevice(),  // (1) 
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            print("Error setting up camera input")
            return
        }

        session.addInput(input)

        let videoQueue = DispatchQueue(label: "videoQueue")
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)    // (2)
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
```

(1) `getCaptureDevice()`, I want app to support running on both macOS and on iOS/iPadOS. Setting up
a camera on these devices requires platform-specific code. For example, on iPhone, I'd like to use
front-facing camera. To keep this part of the code clean and not to pollute it with
platform specific codes, I refactored it out into a separate file.

```swift
extension CameraViewModel {
    ...
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

    // (3)
    func handleDeviceOrientation(connection: AVCaptureConnection) {
#if os(iOS)
        if connection.isVideoOrientationSupported,
           let videoOrientation = videoOrientationFor(deviceOrientation) {
            connection.videoOrientation = videoOrientation
        }
#endif
    }

    ...
}
```

(2) Next, we want to process the captured images, some how.
`videoOutput.setSampleBufferDelegate(self, queue: videoQueue)`. The frameworkd will call `captureOutput(_:didOutput:from)`. So let's conform to this protocol and then figure out what to do with the captured 
images later.

```swift
extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        handleDeviceOrientation(connection: connection)     // (3)

        // We will figure out what to do with the image here.
    }

}
```

(3) On iPhone, I need to handle when I rotate my phone. Again, I wrapped this device-specific code
inside a function to keep the main logic clean. As you can see, `handleDeviceOrientation(connection:)`
doesn't do anything for `macOS` as I don't expect to rotate my mac around 😉.


### Display the captured images

At this point, the app looks very dull. I don't know if it works. Or not?
Let's add some code to show the images from the camera.

```swift
extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        handleDeviceOrientation(connection: connection)     // (3)

        updateFrameImage(pixelBuffer)   // (4b)
    }

}
```

Let's update our `CameraViewModel` to publish an image for each frame that we capture.

```swift

#if os(macOS)
typealias HandPoseImage = NSImage
#else
typealias HandPoseImage = UIImage
#endif

class CameraViewModel: NSObject, ObservableObject {
    @Published @MainActor var frameImage: HandPoseImage?    // (4a)
    ...
}
```

At (4b), we add a call to a function which will create an image for each frame that is captured, we 
will use this to display in our SwiftUI view.

```swift
...
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
```

We can use this image, here, for example.

```swift
import SwiftUI
struct ContentView: View {
    @StateObject private var cameraViewModel = CameraViewModel()

    var body: some View {
        ZStack {
            if let frameImage = cameraViewModel.frameImage {
                HandPoseImageView(handPoseImage: frameImage)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
            } else {
                Text("No Camera Feed")
            }
        }
        .background(Color.black)
        .edgesIgnoringSafeArea(.all)
    }
}

...
struct HandPoseImageView: View {
    var handPoseImage: HandPoseImage
    var body: some View {
#if os(macOS)
        Image(nsImage: handPoseImage)
            .resizable()
            .scaledToFit()
#else
        Image(uiImage: handPoseImage)
            .resizable()
            .scaledToFit()
#endif
    }
}

```

## Part 3 - Using ML Model for Hand Pose Classification

### Loading Hand Post Classification Model

Now, it's time to use our ML model that we created from part 1. To do this, simply, drag and drop our
`mlmodel` file into Xcode.

![ML Create](docs/res/xcode-import-mlmodel.png)

We will load this ML model into our `CameraViewModel`.

```swift
class CameraViewModel: NSObject, ObservableObject {
    @Published @MainActor var frameImage: HandPoseImage?
    ...
    private var mlModel: HandPoseMLModel!
    ...

    override init() {
        super.init()
        setupCamera()

        Task {
            do {
                mlModel = try await HandPoseMLModel.loadMLModel()
                ...
            } catch {
                print("ERROR: Initialising ML classifier: \(error)")
            }
        }
    }
    ...
}
```

And to load our ML model.

```swift
extension HandPoseMLModel {
    static func loadMLModel() async throws -> HandPoseMLModel? {
        do {
            let model = try HandPoseCountingClassifier(configuration: MLModelConfiguration()).model
            return HandPoseMLModel(mlModel: model)
        } catch {
            return nil
        }
    }
    ...
}
```

### Using Hand-Pose ML Model 

We now can use our ML model to predict hand poses from images captured via our camera.
Let modify our `captureOutput(_:didOutput:from)` function to use this classifier, see (5).

```swift
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        handleDeviceOrientation(connection: connection)
        predictHandPose(pixelBuffer)    // (5)
        updateFrameImage(pixelBuffer)
    }
```

The function implementation is here.

```swift
    private func predictHandPose(_ pixelBuffer: CVImageBuffer) {
        ...
        // (6)
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        Task { @MainActor in
            do {
                try imageRequestHandler.perform([handPoseRequest])      // (7)
                if let observation = handPoseRequest.results?.first {
                    let poseMultiArray = try observation.keypointsMultiArray()
                    let input = HandPoseInput(poses: poseMultiArray)
                    if let prediction = try mlModel.predict(poses: input) {     // (8)
                        print("Hand pose: \(prediction.label)")
                    }
                }
            } catch {
                print("Error performing request: \(error)")
            }
        }
    }
```

(6), Notice that our ML classifier accepts multi-array of hand postures. Apple provides a framework
, see 'import Vision' at the top of 'CameraViewModel') to handle the bulk of the work here. 
In order to use Vision, we need to create a hand-pose request, see (7). Let's add a property to 
our model to keep track of this request.

```swift

class CameraViewModel: NSObject, ObservableObject {
    @Published @MainActor var frameImage: HandPoseImage?
    ...
    private var mlModel: HandPoseMLModel!

    // (7)
    lazy private var handPoseRequest: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1
        return request
    }()
    ...

    override init() {
        super.init()
        ...
    }

    ...
}
```

Now that we've converted a captured image into multi-array, we can feed it as an input to our
ML model. Our ML model gives best prediction for a given image. From here on, the usage is limited
only by our imagination!

## Part 4 - (Re)Training you ML Model

If you see the demo video at the beginning of this post, you'll notice that the ML model struggles
to recognise hand-pose for number 3. This is true as the training steps was simplified.
The objective was to provide a skeletal framework of Xcode project to get
Apple Vision and Hand Pose ML to work at its simplesticity (I made up a new word here).

Now that we have a skeletal working project. Training and retraining can be done simply by
repeating Part 1 - Create ML Model, this can be repeated until the model produces satisfactory accuracy. 
For example, you might like to give more variety of images for each number. Perhaps, give 
different set of images for different background, and etc.
The new `.mlmodel` file can be dropped into the Xcode (replacing the old one), then rebuild the new 
version of the app.

