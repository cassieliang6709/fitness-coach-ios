import Foundation

/// Talks to the Cloudflare Worker. Streams Server-Sent Events so the coach's
/// reply appears word by word instead of after a two-second pause.
struct CoachAPI: Sendable {

    let host: String
    let sharedSecret: String

    /// Built from the app's Info.plist (populated by Secrets.xcconfig).
    /// Returns nil when the config is absent, which puts the app in the
    /// offline scripted mode used by demos and UI tests.
    static func fromBundle() -> CoachAPI? {
        let info = Bundle.main.infoDictionary
        guard
            let host = (info?["COACH_API_HOST"] as? String)?
                .trimmingCharacters(in: .whitespaces),
            let secret = (info?["COACH_SHARED_SECRET"] as? String)?
                .trimmingCharacters(in: .whitespaces),
            !host.isEmpty, !secret.isEmpty
        else { return nil }
        return CoachAPI(host: host, sharedSecret: secret)
    }

    private var turnURL: URL? {
        // The scheme lives here rather than in the xcconfig — "//" starts a
        // comment in xcconfig files and would silently truncate the value.
        URL(string: "https://\(host)/coach/turn")
    }

    func stream(_ request: CoachTurnRequest) -> AsyncThrowingStream<CoachEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let url = turnURL else { throw CoachAPIError.notConfigured }

                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue(
                        "Bearer \(sharedSecret)", forHTTPHeaderField: "Authorization")
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    urlRequest.timeoutInterval = 60
                    urlRequest.httpBody = try JSONEncoder().encode(request)

                    let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)

                    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                        throw CoachAPIError.http(status: http.statusCode)
                    }

                    var event = ""
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }

                        if line.hasPrefix("event: ") {
                            event = String(line.dropFirst(7))
                        } else if line.hasPrefix("data: ") {
                            let payload = Data(line.dropFirst(6).utf8)
                            if let parsed = decode(event: event, payload: payload) {
                                continuation.yield(parsed)
                            }
                            if case .error(let reason)? = classify(event: event, payload: payload) {
                                throw CoachAPIError.upstream(reason)
                            }
                        }
                        // A blank line terminates an SSE event; nothing to do.
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - SSE decoding

    private enum Classified {
        case error(String)
    }

    private func classify(event: String, payload: Data) -> Classified? {
        guard event == "error" else { return nil }
        let body = try? JSONDecoder().decode(ErrorPayload.self, from: payload)
        return .error(body?.message ?? "unknown")
    }

    private func decode(event: String, payload: Data) -> CoachEvent? {
        let decoder = JSONDecoder()
        switch event {
        case "text":
            guard let body = try? decoder.decode(TextPayload.self, from: payload) else {
                return nil
            }
            return .text(body.delta)
        case "action":
            guard let body = try? decoder.decode(ActionPayload.self, from: payload) else {
                return nil
            }
            return .action(
                id: body.id,
                name: body.name,
                input: body.input,
                action: CoachAction(name: body.name, input: body.input)
            )
        case "refusal":
            let body = try? decoder.decode(RefusalPayload.self, from: payload)
            return .refusal(category: body?.category)
        case "done":
            return .done
        default:
            return nil
        }
    }

    private struct TextPayload: Decodable { let delta: String }
    private struct ActionPayload: Decodable {
        let id: String
        let name: String
        let input: JSONValue
    }
    private struct RefusalPayload: Decodable { let category: String? }
    private struct ErrorPayload: Decodable { let message: String? }
}
