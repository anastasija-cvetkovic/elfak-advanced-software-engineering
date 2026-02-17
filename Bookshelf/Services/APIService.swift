// APIService.swift
// Trusty Bookshelf — Offline-First SwiftUI Tutorial
//
// All network communication with JSONPlaceholder (https://jsonplaceholder.typicode.com).
// We use the /posts endpoint as a stand-in for a real book API:
//   post.title  → book title
//   post.body   → book notes
//   post.userId → author number ("Author #N")
//   post.id     → remoteId
//
// NOTE: JSONPlaceholder always responds with success but does not actually persist data.
// This is fine for a tutorial — we're demonstrating the sync mechanism, not a real backend.
//
// WHY class (not actor)?
//   APIService is defined as a class so that MockAPIService can subclass it in tests.
//   Thread safety for network calls is provided by URLSession's own async/await support.

import Foundation

// MARK: - Remote Model

struct RemotePost: Codable {
    let id: Int
    let title: String
    let body: String
    let userId: Int
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case badURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .badURL:                   return "Invalid URL"
        case .networkError(let e):      return "Network error: \(e.localizedDescription)"
        case .decodingError(let e):     return "Decoding error: \(e.localizedDescription)"
        case .serverError(let code):    return "Server returned HTTP \(code)"
        }
    }
}

// MARK: - APIService

class APIService {

    private let baseURL = "https://jsonplaceholder.typicode.com"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Fetch posts (used for "Add Sample Books")

    /// Fetches the first `limit` posts from JSONPlaceholder.
    /// These become pre-populated "sample" books in the UI.
    func fetchPosts(limit: Int = 5) async throws -> [RemotePost] {
        guard let url = URL(string: "\(baseURL)/posts?_limit=\(limit)") else {
            throw APIError.badURL
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw APIError.networkError(error)
        }

        if let http = response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            throw APIError.serverError(statusCode: http.statusCode)
        }

        do {
            return try JSONDecoder().decode([RemotePost].self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Create a post (sync a new book to the server)

    /// POSTs a new book to JSONPlaceholder.
    /// JSONPlaceholder always responds with id: 101 — that's expected behaviour.
    func createPost(title: String, body: String, userId: Int = 1) async throws -> RemotePost {
        guard let url = URL(string: "\(baseURL)/posts") else {
            throw APIError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = ["title": title, "body": body, "userId": userId]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, _): (Data, URLResponse)
        do {
            (data, _) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        do {
            return try JSONDecoder().decode(RemotePost.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Update a post (sync an edited book)

    /// PUTs updated book data to JSONPlaceholder.
    func updatePost(id: Int, title: String, body: String) async throws -> RemotePost {
        guard let url = URL(string: "\(baseURL)/posts/\(id)") else {
            throw APIError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = ["id": id, "title": title, "body": body, "userId": 1]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, _): (Data, URLResponse)
        do {
            (data, _) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        do {
            return try JSONDecoder().decode(RemotePost.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Delete a post

    /// DELETEs a post from JSONPlaceholder (simulated — server does not persist deletes).
    func deletePost(id: Int) async throws {
        guard let url = URL(string: "\(baseURL)/posts/\(id)") else {
            throw APIError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        do {
            _ = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }
    }
}
