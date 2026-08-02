import Foundation
import Observation
import UIKit

/// Gym photo → equipment list, via the Worker (which holds the Kimi key).
///
/// The service deliberately keeps `high` and `medium` apart. Confirmed items go
/// straight into memories; ambiguous ones are shown as questions, because a
/// machine that isn't really there produces a plan the user can't perform.
@MainActor
@Observable
final class GymVision {

    enum Phase: Equatable {
        case idle
        case uploading
        case ready
        case saving
        case saved
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var result: GymVisionResult?
    /// Ambiguous items the user has ticked; merged into the confirmed set.
    var accepted: Set<String> = []

    private let host: String
    private let sharedSecret: String
    private let userID: String

    init?(userID: String) {
        let info = Bundle.main.infoDictionary
        guard
            let host = (info?["COACH_API_HOST"] as? String)?.trimmingCharacters(in: .whitespaces),
            let secret = (info?["COACH_SHARED_SECRET"] as? String)?
                .trimmingCharacters(in: .whitespaces),
            !host.isEmpty, !secret.isEmpty
        else { return nil }
        self.host = host
        self.sharedSecret = secret
        self.userID = userID
    }

    /// Everything the user has agreed to — what gets written as memories.
    var confirmedEquipment: [String] {
        guard let result else { return [] }
        return (result.equipment.map(\.name) + accepted.sorted()).reduce(into: []) { names, name in
            if !names.contains(name) { names.append(name) }
        }
    }

    var needsSave: Bool {
        result != nil && phase != .saved
    }

    func recognize(_ image: UIImage, goal: String) async {
        phase = .uploading
        result = nil
        accepted = []

        // Downscale before encoding: a 12MP photo is ~4MB of base64 for no gain
        // in recognising a squat rack.
        guard let data = Self.encode(image) else {
            phase = .failed("图片处理失败")
            return
        }

        guard let url = endpoint("/vision/equipment") else {
            phase = .failed("识别服务地址无效")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(sharedSecret)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90
        // Nothing is stored until the user has seen it and moved on.
        request.httpBody = try? JSONEncoder().encode(
            VisionRequest(
                imageData: "data:image/jpeg;base64,\(data.base64EncodedString())",
                goal: goal,
                save: false
            ))

        do {
            let (body, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                phase = .failed("网络异常")
                return
            }
            guard http.statusCode == 200 else {
                phase = .failed(Self.message(for: http.statusCode, body: body))
                return
            }
            result = try JSONDecoder().decode(GymVisionResult.self, from: body)
            phase = .ready
        } catch {
            phase = .failed("识别失败，请重试")
        }
    }

    /// Persists only what Kimi saw with high confidence plus medium-confidence
    /// items the user explicitly accepted.
    func saveConfirmed() async -> Bool {
        guard result != nil else { return true }
        let equipment = confirmedEquipment
        guard !equipment.isEmpty else {
            phase = .saved
            return true
        }
        guard let url = endpoint("/vision/equipment/confirm") else {
            phase = .failed("识别服务地址无效")
            return false
        }

        phase = .saving
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(sharedSecret)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try? JSONEncoder().encode(ConfirmRequest(equipment: equipment))

        do {
            let (body, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                phase = .failed(Self.message(for: status, body: body))
                return false
            }
            phase = .saved
            return true
        } catch {
            phase = .failed("器械记忆保存失败，请重试")
            return false
        }
    }

    func toggleAccepted(_ item: String) {
        guard phase != .saving, phase != .saved else { return }
        if accepted.contains(item) {
            accepted.remove(item)
        } else {
            accepted.insert(item)
        }
    }

    func reportImageError() {
        result = nil
        accepted = []
        phase = .failed("图片读取失败，换一张试试")
    }

    func reset() {
        phase = .idle
        result = nil
        accepted = []
    }

    // MARK: - Internals

    private static func encode(_ image: UIImage) -> Data? {
        let maxEdge: CGFloat = 1280
        let scale = min(1, maxEdge / max(image.size.width, image.size.height))
        guard scale < 1 else { return image.jpegData(compressionQuality: 0.8) }

        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }

    private static func message(for status: Int, body: Data) -> String {
        let detail = (try? JSONDecoder().decode(VisionError.self, from: body))?.error
        switch detail {
        case "vision_not_configured": return "识别服务未开启"
        case "kimi_rate_limited": return "识别请求太频繁，稍后再试"
        case "invalid_image": return "这张图片用不了，换一张试试"
        case "invalid_equipment": return "器械确认内容无效，请重新识别"
        default: return status == 401 ? "鉴权失败" : "识别暂时不可用"
        }
    }

    private func endpoint(_ path: String) -> URL? {
        var components = URLComponents(string: "https://\(host)\(path)")
        components?.queryItems = [URLQueryItem(name: "user", value: userID)]
        return components?.url
    }

    private struct VisionRequest: Encodable {
        let imageData: String
        let goal: String
        let save: Bool
    }

    private struct VisionError: Decodable {
        let error: String?
    }

    private struct ConfirmRequest: Encodable {
        let equipment: [String]
    }
}

// MARK: - Wire types

struct GymVisionResult: Decodable, Equatable {
    let sceneSummary: String
    /// High confidence only — the Worker filters the rest out.
    let equipment: [Item]
    /// Ambiguous sightings, phrased as questions for the user.
    let needsConfirmation: [String]

    struct Item: Decodable, Equatable, Identifiable {
        let name: String
        let visibleEvidence: String
        var id: String { name }
    }
}
