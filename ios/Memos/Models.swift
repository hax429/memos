import Foundation

// MARK: - User

struct User: Codable, Identifiable {
    let name: String
    let id: Int
    let username: String
    let email: String?
    let nickname: String?
    let avatarUrl: String?
    let description: String?
    let role: String
    let createTime: String?
    let updateTime: String?

    enum CodingKeys: String, CodingKey {
        case name, id, username, email, nickname, description, role
        case avatarUrl = "avatarUrl"
        case createTime = "createTime"
        case updateTime = "updateTime"
    }

    var displayName: String {
        nickname ?? username
    }
}

// MARK: - Memo

struct Memo: Codable, Identifiable {
    let name: String
    let uid: String
    let content: String
    let visibility: String
    let pinned: Bool
    let createTime: String
    let updateTime: String
    let displayTime: String?
    let tags: [String]
    let reactions: [Reaction]?
    let property: MemoProperty?
    let parent: String?
    let resources: [Resource]?
    let relations: [MemoRelation]?

    var id: String { uid }

    enum CodingKeys: String, CodingKey {
        case name, uid, content, visibility, pinned, tags, reactions, property, parent, resources, relations
        case createTime = "createTime"
        case updateTime = "updateTime"
        case displayTime = "displayTime"
    }

    var createdDate: Date? {
        ISO8601DateFormatter().date(from: createTime)
    }

    var updatedDate: Date? {
        ISO8601DateFormatter().date(from: updateTime)
    }

    var displayDate: Date? {
        if let displayTime = displayTime {
            return ISO8601DateFormatter().date(from: displayTime)
        }
        return createdDate
    }
}

// MARK: - Memo Property

struct MemoProperty: Codable {
    let hasLink: Bool?
    let hasTaskList: Bool?
    let hasCode: Bool?
    let hasIncompleteTasks: Bool?

    enum CodingKeys: String, CodingKey {
        case hasLink, hasTaskList, hasCode, hasIncompleteTasks
    }
}

// MARK: - Reaction

struct Reaction: Codable, Identifiable {
    let id: Int
    let creator: String
    let contentId: String
    let reactionType: String

    enum CodingKeys: String, CodingKey {
        case id, creator
        case contentId = "contentId"
        case reactionType = "reactionType"
    }
}

// MARK: - Resource

struct Resource: Codable, Identifiable {
    let name: String
    let uid: String
    let createTime: String
    let filename: String
    let externalLink: String?
    let type: String
    let size: Int64
    let memo: String?

    var id: String { uid }

    enum CodingKeys: String, CodingKey {
        case name, uid, filename, type, size, memo
        case createTime = "createTime"
        case externalLink = "externalLink"
    }
}

// MARK: - Memo Relation

struct MemoRelation: Codable, Identifiable {
    let memo: String
    let relatedMemo: String
    let type: String

    var id: String { "\(memo)-\(relatedMemo)" }

    enum CodingKeys: String, CodingKey {
        case memo
        case relatedMemo = "relatedMemo"
        case type
    }
}

// MARK: - User Stats

struct UserStats: Codable {
    let name: String
    let memoCount: Int
    let tagCount: [String: Int]

    enum CodingKeys: String, CodingKey {
        case name
        case memoCount = "memoCount"
        case tagCount = "tagCount"
    }

    var sortedTags: [(String, Int)] {
        tagCount.sorted { $0.value > $1.value }
    }
}

// MARK: - View Models

@MainActor
class MemoListViewModel: ObservableObject {
    @Published var memos: [Memo] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var error: String?
    @Published var userStats: UserStats?

    private let apiClient = APIClient.shared

    func loadMemos() async {
        isLoading = true
        error = nil

        do {
            // Load memos
            memos = try await apiClient.listMemos(pageSize: 100)

            // Load user stats if authenticated
            if let user = apiClient.currentUser {
                userStats = try await apiClient.getUserStats(userName: user.name)
            }

            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    func createMemo(content: String) async throws {
        isSaving = true
        defer { isSaving = false }

        do {
            let newMemo = try await apiClient.createMemo(content: content)
            memos.insert(newMemo, at: 0)
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    func updateMemo(name: String, content: String) async throws {
        isSaving = true
        defer { isSaving = false }

        do {
            let updatedMemo = try await apiClient.updateMemo(name: name, content: content)
            if let index = memos.firstIndex(where: { $0.name == name }) {
                memos[index] = updatedMemo
            }
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    func deleteMemo(_ memo: Memo) async {
        do {
            try await apiClient.deleteMemo(name: memo.name)
            memos.removeAll { $0.id == memo.id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?

    private let apiClient = APIClient.shared

    func checkAuthentication() async {
        isLoading = true
        do {
            _ = try await apiClient.getCurrentSession()
        } catch {
            // Not authenticated - auto-create local user
            await autoLoginLocalUser()
        }
        isLoading = false
    }

    private func autoLoginLocalUser() async {
        do {
            // Try to login with default credentials
            do {
                try await apiClient.createSession(username: "local", password: "local")
            } catch {
                // User doesn't exist, create it
                _ = try await apiClient.createUser(username: "local", password: "local")
                try await apiClient.createSession(username: "local", password: "local")
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
