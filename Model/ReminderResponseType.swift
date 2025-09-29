import Foundation

enum ReminderResponseType: String, Codable, CaseIterable {
    case yesNo
    case text
    case both
    case scale // Added for mood/scale responses
    
    var description: String {
        switch self {
        case .yesNo: return "Yes/No"
        case .text: return "Text"
        case .both: return "Yes/No + Text"
        case .scale: return "Scale (e.g., 1-5)" // Add description for scale
        }
    }
    
    static var allCases: [ReminderResponseType] {
        return [.yesNo, .text, .both, .scale]
    }
}
