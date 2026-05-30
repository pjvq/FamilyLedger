import Flutter
import NaturalLanguage

public class NLEmbeddingPlugin: NSObject, FlutterPlugin {
    private let embedding: NLEmbedding?

    override init() {
        self.embedding = NLEmbedding.wordEmbedding(for: .simplifiedChinese)
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "familyledger/nl_embedding",
            binaryMessenger: registrar.messenger()
        )
        let instance = NLEmbeddingPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            result(embedding != nil)

        case "distance":
            guard let args = call.arguments as? [String: String],
                  let w1 = args["word1"],
                  let w2 = args["word2"],
                  let emb = embedding else {
                result(nil)
                return
            }
            let dist = emb.distance(between: w1, and: w2)
            result(dist.isNaN ? nil : dist)

        case "batchDistances":
            guard let args = call.arguments as? [String: Any],
                  let words = args["words"] as? [String],
                  let emb = embedding else {
                result(nil)
                return
            }
            var distances: [String: Double] = [:]
            for i in 0..<words.count {
                for j in (i + 1)..<words.count {
                    let pair = [words[i], words[j]].sorted()
                    let key = "\(pair[0])|\(pair[1])"
                    let dist = emb.distance(between: words[i], and: words[j])
                    distances[key] = dist.isNaN ? 2.0 : dist
                }
            }
            result(distances)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
