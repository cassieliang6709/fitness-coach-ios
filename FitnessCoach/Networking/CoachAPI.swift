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

    /// The scheme lives here rather than in the xcconfig — "//" starts a
    /// comment in xcconfig files and would silently truncate the value.
    private func url(path: String) -> URL? {
        var components = URLComponents(string: "https://\(host)\(path)")
        components?.queryItems = [URLQueryItem(name: "user", value: InstallIdentity.current)]
        return components?.url
    }

    private var turnURL: URL? { url(path: "/coach/turn") }
    private var planURL: URL? { url(path: "/plan") }
    private var speechURL: URL? { url(path: "/speech") }

    private func catalogURL(limit: Int, offset: Int) -> URL? {
        guard var components = URLComponents(string: "https://\(host)/exercises") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]
        return components.url
    }

    // MARK: - Requests

    /// Every endpoint is authorized the same way, so the header, the timeout
    /// and the "no config" failure are stated once instead of at each call.
    private func authorized(
        _ url: URL?,
        method: String = "GET",
        accept: String? = nil,
        timeout: TimeInterval
    ) throws -> URLRequest {
        guard let url else { throw CoachAPIError.notConfigured }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(sharedSecret)", forHTTPHeaderField: "Authorization")
        if let accept { request.setValue(accept, forHTTPHeaderField: "Accept") }
        request.timeoutInterval = timeout
        return request
    }

    private func authorizedJSON(
        _ url: URL?,
        body: some Encodable,
        accept: String,
        timeout: TimeInterval
    ) throws -> URLRequest {
        var request = try authorized(url, method: "POST", accept: accept, timeout: timeout)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    /// Sends a non-streaming request and turns any non-200 into an error, so
    /// callers only ever handle a body.
    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response)
        return data
    }

    private func check(_ response: URLResponse) throws {
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw CoachAPIError.http(status: http.statusCode)
        }
    }

    func stream(_ request: CoachTurnRequest) -> AsyncThrowingStream<CoachEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let urlRequest = try authorizedJSON(
                        turnURL,
                        body: request,
                        accept: "text/event-stream",
                        timeout: 60
                    )

                    let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                    try check(response)

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

    /// Voices the coach's exact final reply. MiniMax is a TTS provider here,
    /// not a second model that can alter what the user already sees on screen.
    func synthesizeSpeech(_ text: String) async throws -> Data {
        let data = try await send(
            authorizedJSON(
                speechURL,
                body: SpeechRequest(text: text),
                accept: "audio/mpeg",
                timeout: 30
            )
        )
        guard !data.isEmpty else { throw CoachAPIError.upstream("empty_audio") }
        return data
    }

    // MARK: - Plan

    /// The user's active plan, or nil when they have never had one generated.
    /// Throws on transport failures so the caller can tell "no plan yet" apart
    /// from "couldn't reach the server" and keep its cache in the second case.
    func activePlan() async throws -> PlanWire? {
        let data = try await send(authorized(planURL, timeout: 20))
        return try JSONDecoder().decode(PlanEnvelope.self, from: data).plan
    }

    private struct PlanEnvelope: Decodable { let plan: PlanWire? }
    private struct SpeechRequest: Encodable { let text: String }

    /// Loads the entire D1 catalogue in bounded pages. There are currently
    /// around 1.3k rows, so this is three requests rather than one huge body.
    func exerciseCatalog() async throws -> [ExerciseCatalogItem] {
        let pageSize = 500
        var offset = 0
        var catalogue: [ExerciseCatalogItem] = []

        while true {
            let data = try await send(
                authorized(catalogURL(limit: pageSize, offset: offset), timeout: 20)
            )
            let page = try JSONDecoder().decode(ExerciseCatalogPageWire.self, from: data)
            catalogue.append(contentsOf: page.items)
            guard let next = page.nextOffset else { break }
            guard next > offset else { throw CoachAPIError.upstream("invalid_catalog_page") }
            offset = next
        }

        return catalogue
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
        case "plan":
            guard let body = try? decoder.decode(PlanWire.self, from: payload) else { return nil }
            return .plan(body)
        case "plan_error":
            let body = try? decoder.decode(PlanErrorPayload.self, from: payload)
            return .planError(reason: body?.reason ?? "计划没有通过校验")
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
    private struct PlanErrorPayload: Decodable { let reason: String? }
    private struct ErrorPayload: Decodable { let message: String? }
}
