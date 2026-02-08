import Foundation

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private var baseURL: URL {
        if let s = ProcessInfo.processInfo.environment["STILLFRESH_ENDPOINT"],
           let url = URL(string: s) {
            return url
        }
        // Fallback if env var not set
        return URL(string: "https://stillfresh-worker.astitvnagpal.workers.dev")!
    }

    func classifyReceipt(imageDataURL: String,
                         timezone: String = "America/Los_Angeles",
                         partialScan: Bool = true) async throws -> WorkerReceiptResponse {
        let url = baseURL.appendingPathComponent("classify")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "scan_group_id": UUID().uuidString,
            "timezone": timezone,
            "partial_scan": partialScan,
            "image_data_url": imageDataURL
        ]

        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Request failed"
            throw NSError(
                domain: "APIClient",
                code: http.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(msg)"
                ]
            )
        }

        return try JSONDecoder().decode(WorkerReceiptResponse.self, from: data)
    }
}

