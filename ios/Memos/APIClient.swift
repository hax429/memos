import Foundation

/// API client for communicating with the Memos Go backend
/// Uses the REST API endpoints provided by gRPC-Gateway
class APIClient: ObservableObject {
    static let shared = APIClient()

    @Published var isAuthenticated = false
    @Published var currentUser: User?

    private var baseURL: URL
    private let session: URLSession

    init(baseURL: String = "http://localhost:5230") {
        self.baseURL = URL(string: baseURL)!

        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = .shared
        configuration.httpCookieAcceptPolicy = .always
        self.session = URLSession(configuration: configuration)
    }

    // Update the base URL (called when server starts with actual URL)
    func updateBaseURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            self.baseURL = url
            print("APIClient baseURL updated to: \(urlString)")
        }
    }

    // MARK: - Authentication

    func getCurrentSession() async throws -> User? {
        let url = baseURL.appendingPathComponent("/api/v1/auth/sessions/current")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let sessionResponse = try JSONDecoder().decode(SessionResponse.self, from: data)
            DispatchQueue.main.async {
                self.currentUser = sessionResponse.user
                self.isAuthenticated = true
            }
            return sessionResponse.user
        } else if httpResponse.statusCode == 401 {
            // Not authenticated
            DispatchQueue.main.async {
                self.currentUser = nil
                self.isAuthenticated = false
            }
            return nil
        } else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    func createSession(username: String, password: String) async throws {
        let url = baseURL.appendingPathComponent("/api/v1/auth/sessions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = CreateSessionRequest(passwordCredentials: PasswordCredentials(username: username, password: password))
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        // Debug: Print cookies
        print("All cookies in storage: \(HTTPCookieStorage.shared.cookies?.map { "\($0.name)=\($0.value) [domain:\($0.domain), path:\($0.path)]" } ?? [])")
        if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            print("Cookies after createSession for \(url): \(cookies.map { "\($0.name)=\($0.value)" })")
        } else {
            print("No cookies set for URL: \(url)")
        }

        let sessionResponse = try JSONDecoder().decode(SessionResponse.self, from: data)
        DispatchQueue.main.async {
            self.currentUser = sessionResponse.user
            self.isAuthenticated = true
        }
    }

    func createUser(username: String, password: String) async throws -> User {
        let url = baseURL.appendingPathComponent("/api/v1/users")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = CreateUserRequest(username: username, password: password)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        return try JSONDecoder().decode(User.self, from: data)
    }

    // MARK: - Memos

    func listMemos(filter: String? = nil, pageSize: Int = 50, pageToken: String? = nil) async throws -> [Memo] {
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/v1/memos"), resolvingAgainstBaseURL: false)!

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "pageSize", value: "\(pageSize)")
        ]

        if let filter = filter {
            queryItems.append(URLQueryItem(name: "filter", value: filter))
        }

        if let pageToken = pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }

        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        let memosResponse = try JSONDecoder().decode(MemosResponse.self, from: data)
        return memosResponse.memos
    }

    func createMemo(content: String, visibility: String = "PRIVATE") async throws -> Memo {
        let url = baseURL.appendingPathComponent("/api/v1/memos")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Debug: Print cookies before request
        if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            print("Cookies before createMemo: \(cookies.map { "\($0.name)=\($0.value)" })")
        } else {
            print("No cookies found for createMemo request!")
        }

        let body = CreateMemoRequest(content: content, visibility: visibility)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        return try JSONDecoder().decode(Memo.self, from: data)
    }

    func updateMemo(name: String, content: String) async throws -> Memo {
        let url = baseURL.appendingPathComponent("/api/v1/\(name)")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = UpdateMemoRequest(content: content, updateMask: "content")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        return try JSONDecoder().decode(Memo.self, from: data)
    }

    func deleteMemo(name: String) async throws {
        let url = baseURL.appendingPathComponent("/api/v1/\(name)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - User Stats

    func getUserStats(userName: String) async throws -> UserStats {
        let url = baseURL.appendingPathComponent("/api/v1/\(userName)/stats")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        return try JSONDecoder().decode(UserStats.self, from: data)
    }
}

// MARK: - API Error

enum APIError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Request/Response Models

struct PasswordCredentials: Codable {
    let username: String
    let password: String
}

struct CreateSessionRequest: Codable {
    let passwordCredentials: PasswordCredentials
}

struct SessionResponse: Codable {
    let user: User?
}

struct CreateUserRequest: Codable {
    let username: String
    let password: String
}

struct CreateMemoRequest: Codable {
    let content: String
    let visibility: String
}

struct UpdateMemoRequest: Codable {
    let content: String
    let updateMask: String
}

struct MemosResponse: Codable {
    let memos: [Memo]
}
