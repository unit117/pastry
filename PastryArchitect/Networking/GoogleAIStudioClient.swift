import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct GoogleAIStudioClient {
    struct GeminiResponse: Decodable {
        let candidates: [Candidate]
    }

    struct Candidate: Decodable {
        let content: Content
    }

    struct Content: Decodable {
        let parts: [Part]
    }

    struct Part: Decodable {
        let text: String?
    }

    private let session: URLSession
    private let apiKeyProvider: () throws -> String

    init(session: URLSession = .shared, apiKeyProvider: @escaping () throws -> String) {
        self.session = session
        self.apiKeyProvider = apiKeyProvider
    }

    func upload(pdfData: Data, fileName: String, systemPrompt: String) async throws -> ParsedPayload {
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/upload/v1beta/files?key=\(try apiKeyProvider())")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = try multipartBody(boundary: boundary, pdfData: pdfData, fileName: fileName)

        let (_, uploadResponse) = try await session.data(for: request)
        guard (uploadResponse as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        var generationRequest = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(try apiKeyProvider())")!)
        generationRequest.httpMethod = "POST"
        generationRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt: [String: Any] = [
            "system_instruction": ["parts": [["text": systemPrompt]]],
            "contents": [[
                "parts": [["file_data": ["mime_type": "application/pdf", "file_uri": "upload://pastry"]]]
            ]],
            "generation_config": ["response_schema": [
                "type": "OBJECT",
                "properties": [
                    "catalogue": ["type": "ARRAY"],
                    "recipes": ["type": "ARRAY"],
                    "products": ["type": "ARRAY"]
                ]
            ]]
        ]
        generationRequest.httpBody = try JSONSerialization.data(withJSONObject: prompt)

        let (data, response) = try await session.data(for: generationRequest)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = decoded.candidates.first?.content.parts.compactMap({ $0.text }).joined(separator: "\n"),
              let payloadData = text.data(using: .utf8) else {
            throw URLError(.cannotParseResponse)
        }
        return try JSONDecoder().decode(ParsedPayload.self, from: payloadData)
    }

    private func multipartBody(boundary: String, pdfData: Data, fileName: String) throws -> Data {
        var body = Data()
        let disposition = "--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\nContent-Type: application/pdf\r\n\r\n"
        body.append(disposition.data(using: .utf8)!)
        body.append(pdfData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }
}
