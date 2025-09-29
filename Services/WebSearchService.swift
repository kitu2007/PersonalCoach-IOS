import Foundation

struct SearchResult: Identifiable, Codable, Hashable {
    var id = UUID()
    let title: String
    let snippet: String
    let url: String
}

enum WebSearchError: Error {
    case invalidHTTP
    case parsingFailed
}

struct WebSearchService {
    static func search(query: String, maxResults: Int = 5) async throws -> [SearchResult] {
        // Use DuckDuckGo Instant Answer API (JSON). Limited but public.
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.duckduckgo.com/?q=\(encoded)&format=json&no_redirect=1&no_html=1") else {
            return []
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw WebSearchError.invalidHTTP }
        do {
            // DuckDuckGo JSON format: we only use "RelatedTopics".
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let topics = json["RelatedTopics"] as? [[String: Any]] {
                var results: [SearchResult] = []
                for item in topics {
                    if let text = item["Text"] as? String,
                       let firstUrl = item["FirstURL"] as? String {
                        // Split title and snippet roughly
                        let parts = text.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
                        let title = parts.first.map(String.init) ?? text
                        let snippet = parts.count > 1 ? String(parts[1]) : ""
                        results.append(SearchResult(title: title.trimmingCharacters(in: .whitespaces), snippet: snippet.trimmingCharacters(in: .whitespaces), url: firstUrl))
                        if results.count >= maxResults { break }
                    }
                }
                return results
            }
        } catch {
            throw WebSearchError.parsingFailed
        }
        return []
    }
} 