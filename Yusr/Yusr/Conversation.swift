import Foundation

enum PracticeMode: String, CaseIterable, Identifiable {
    case free = "Free conversation", random = "Surprise me", cafe = "Coffee shop", restaurant = "Restaurant", shopping = "Shopping", directions = "Asking directions", appointment = "Booking an appointment", interview = "Job interview", presentation = "Presentation", coworkers = "Coworkers", classroom = "Class discussion", football = "Soccer", movies = "Movies", tv = "TV shows", gaming = "Gaming", travel = "Travel", hobbies = "Hobbies", music = "Music", custom = "Choose a topic"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .free: "bubble.left.and.bubble.right"
        case .random: "shuffle"
        case .cafe: "cup.and.saucer"
        case .restaurant: "fork.knife"
        case .shopping: "bag"
        case .directions: "map"
        case .appointment: "calendar"
        case .interview: "briefcase"
        case .presentation: "rectangle.on.rectangle"
        case .coworkers: "person.2"
        case .classroom: "books.vertical"
        case .football: "soccerball"
        case .movies: "film"
        case .tv: "tv"
        case .gaming: "gamecontroller"
        case .travel: "airplane"
        case .hobbies: "paintpalette"
        case .music: "music.note"
        case .custom: "text.bubble"
        }
    }
    var opening: String {
        switch self {
        case .free: "Hi! What would you like to talk about today?"
        case .random: "If you could travel anywhere, where would you go?"
        case .cafe: "Welcome! What can I get for you today?"
        case .restaurant: "Welcome! What would you like to eat?"
        case .shopping: "Hi! What are you shopping for?"
        case .directions: "Hi there! Where are you trying to go?"
        case .appointment: "Hello! What kind of appointment would you like to book?"
        case .interview: "Welcome to the interview. Tell me about yourself."
        case .presentation: "Whenever you are ready, please begin your presentation."
        case .coworkers: "Hey! Is this your first day on the team?"
        case .classroom: "What do you think about today’s lesson?"
        case .football: "Which soccer team do you support?"
        case .movies: "What movie have you enjoyed recently?"
        case .tv: "What TV show are you watching?"
        case .gaming: "What game do you enjoy playing?"
        case .travel: "Where would you love to travel?"
        case .hobbies: "What do you enjoy doing in your free time?"
        case .music: "What kind of music do you like?"
        case .custom: "What would you like to talk about?"
        }
    }
}
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: String
    let content: String
    init(role: String, content: String) { self.id = UUID(); self.role = role; self.content = content }
}

struct ConversationReply: Decodable { let reply: String }

struct APIClient {
    // Simulator: localhost works. Physical iPhone: replace with your Mac's LAN IP or HTTPS server.
    static let baseURL = URL(string: "http://10.101.59.85:8000")!
    func reply(mode: PracticeMode, messages: [ChatMessage]) async throws -> String {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent("chat"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180
        let body: [String: Any] = ["mode": mode.rawValue, "messages": messages.map { ["role": $0.role, "content": $0.content] }]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(ConversationReply.self, from: data).reply
    }
}

extension APIClient {
    func voiceAudio(text: String) async throws -> Data {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent("speak"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180
        request.httpBody = try JSONEncoder().encode(["text": text])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
