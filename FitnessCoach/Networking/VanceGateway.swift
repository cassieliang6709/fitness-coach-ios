import Foundation

/// Configuration for the Vance Gateway. The app receives only a gateway host
/// and its short-lived access token; MiniMax and Kimi provider keys stay server-side.
struct VanceGatewayConfig: Sendable {
    let host: String
    let sharedSecret: String

    static func fromBundle() -> VanceGatewayConfig? {
        let info = Bundle.main.infoDictionary
        guard
            let host = (info?["VANCE_GATEWAY_HOST"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            let sharedSecret = (info?["VANCE_GATEWAY_SHARED_SECRET"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !host.isEmpty,
            !sharedSecret.isEmpty
        else { return nil }
        return VanceGatewayConfig(host: host, sharedSecret: sharedSecret)
    }

    func httpURL(path: String) -> URL? {
        URL(string: "\(isLocalHost ? "http" : "https")://\(host)\(path)")
    }

    func webSocketURL(path: String) -> URL? {
        URL(string: "\(isLocalHost ? "ws" : "wss")://\(host)\(path)")
    }

    private var isLocalHost: Bool {
        host.hasPrefix("localhost") || host.hasPrefix("127.0.0.1")
    }
}

enum VanceGatewayError: LocalizedError {
    case notConfigured
    case invalidResponse
    case http(Int)
    case upstream(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "实时教练服务未配置"
        case .invalidResponse: return "实时教练服务返回无效数据"
        case .http(let status): return "实时教练服务返回 \(status)"
        case .upstream(let message): return message
        }
    }
}

struct GymVisionResult: Codable, Hashable {
    struct Equipment: Codable, Hashable {
        let name: String
        let confidence: String
        let visibleEvidence: String
    }

    let sceneSummary: String
    let equipment: [Equipment]
    let needsConfirmation: [String]
}

/// A server-sanitized durable memory addition or update.
struct MemorySummary: Codable, Sendable {
    struct Update: Codable, Sendable {
        let id: String
        let operation: Operation
        let category: MemoryCategory
        let text: String

        enum Operation: String, Codable, Sendable {
            case upsert
        }
    }

    let updates: [Update]
}

struct GymVisionAPI: Sendable {
    let config: VanceGatewayConfig

    func recognize(
        imageData: Data,
        mimeType: String,
        conversationID: String,
        goal: String,
        userPlan: String
    ) async throws -> GymVisionResult {
        guard let url = config.httpURL(path: "/api/gym-vision") else {
            throw VanceGatewayError.notConfigured
        }
        let encoded = imageData.base64EncodedString()
        let requestBody = GymVisionRequest(
            conversationId: conversationID,
            imageData: "data:\(mimeType);base64,\(encoded)",
            goal: goal,
            userPlan: userPlan
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("Bearer \(config.sharedSecret)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw VanceGatewayError.invalidResponse }
        guard http.statusCode == 200 else {
            let error = try? JSONDecoder().decode(GatewayErrorPayload.self, from: data)
            throw VanceGatewayError.upstream(error?.error ?? "识别服务不可用（HTTP \(http.statusCode)）")
        }
        return try JSONDecoder().decode(GymVisionResult.self, from: data)
    }

    private struct GymVisionRequest: Encodable {
        let conversationId: String
        let imageData: String
        let goal: String
        let userPlan: String
    }
}

/// Kimi-backed, low-priority summary call. It is intentionally separate from
/// realtime coaching: a delayed or unavailable summary must never block a
/// conversation turn or camera recognition.
struct MemorySummaryAPI: Sendable {
    let config: VanceGatewayConfig

    func summarize(transcript: [String], existingMemories: [String]) async throws -> MemorySummary {
        guard let url = config.httpURL(path: "/api/memory-summary") else {
            throw VanceGatewayError.notConfigured
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("Bearer \(config.sharedSecret)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(Request(
            transcript: transcript,
            existingMemories: existingMemories
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw VanceGatewayError.invalidResponse }
        guard http.statusCode == 200 else {
            let error = try? JSONDecoder().decode(GatewayErrorPayload.self, from: data)
            throw VanceGatewayError.upstream(error?.error ?? "记忆总结服务不可用（HTTP \(http.statusCode)）")
        }
        return try JSONDecoder().decode(MemorySummary.self, from: data)
    }

    private struct Request: Encodable {
        let transcript: [String]
        let existingMemories: [String]
    }
}

struct GatewayErrorPayload: Decodable {
    let error: String?
}
