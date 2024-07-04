// credit: https://developer.apple.com/tutorials/sample-apps/getstartedwithmachinelearning-recognizegestures

import Foundation
import CoreML
import Combine

extension HandPoseMLModel {
    static func loadMLModel() async throws -> HandPoseMLModel? {
        do {
            let model = try HandPoseCountingClassifier(configuration: MLModelConfiguration()).model
            return HandPoseMLModel(mlModel: model)
        } catch {
            return nil
        }
    }

    static func getDefaultMLModel() async -> HandPoseMLModel? {
        do {
            return try await HandPoseMLModel.loadMLModel()
        } catch {
            print("Could not load default ML model: \(error.localizedDescription)")
            return nil
        }
    }

}

extension HandPoseInput: MLFeatureProvider {
    var featureNames: Set<String> {
        get {
            return ["poses"]
        }
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        if featureName == "poses" {
            return MLFeatureValue(multiArray: poses)
        }
        return nil
    }
    
}

extension HandPoseOutput: MLFeatureProvider {
    var featureNames: Set<String> {
        return self.provider.featureNames
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        return self.provider.featureValue(for: featureName)
    }
}

extension HandPoseOutput {
    func getOutputProbabilities() -> [String : Double] {
        return self.provider.featureValue(for: "labelProbabilities")?.dictionaryValue as? [String : Double] ?? [:]
    }
    
    func getOutputLabel() -> String {
        return self.provider.featureValue(for: "label")?.stringValue ?? ""
    }
}
