/*
See the License.txt file for this sample’s licensing information.
*/

import Foundation
import CoreML

final class HandPoseMLModel: NSObject, Identifiable {
    let mlModel: MLModel

    private var classLabels: [Any] {
        mlModel.modelDescription.classLabels ?? []
    }

    init(mlModel: MLModel) {
        self.mlModel = mlModel
    }

    func predict(poses: HandPoseInput) throws -> HandPoseOutput? {
        let features = try mlModel.prediction(from: poses)
        let output = HandPoseOutput(features: features)
        return output
    }
}

class HandPoseInput {
    var poses: MLMultiArray
    
    init(poses: MLMultiArray) {
        self.poses = poses
    }
}

class HandPoseOutput {
    let provider : MLFeatureProvider

    lazy var labelProbabilities: [String : Double] = { [unowned self] in
        self.getOutputProbabilities()
    }()

    lazy var label: String = { [unowned self] in
        self.getOutputLabel()
    }()

    init(features: MLFeatureProvider) {
        self.provider = features
    }
}
