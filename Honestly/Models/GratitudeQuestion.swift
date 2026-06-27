import Foundation

struct GratitudeQuestion {
    let question: String
    let chips: [String]

    static let pool: [GratitudeQuestion] = [
        GratitudeQuestion(
            question: "what small habit has been good for you?",
            chips: ["a meal I enjoyed", "something beautiful", "a moment I'm proud of", "a person, a smell, a moment"]
        ),
        GratitudeQuestion(
            question: "what made you smile yesterday?",
            chips: ["morning coffee", "a kind text", "my quiet room", "morning light", "a deep breath", "a comfort song"]
        ),
        GratitudeQuestion(
            question: "who are you grateful for today?",
            chips: ["my family", "a close friend", "my partner", "someone who helped", "a stranger"]
        ),
        GratitudeQuestion(
            question: "what's something small that made a difference?",
            chips: ["good sleep", "a good meal", "sunny weather", "getting things done", "a good laugh"]
        ),
        GratitudeQuestion(
            question: "what do you have today that you once wished for?",
            chips: ["my home", "my health", "my work", "people I love", "time to myself"]
        ),
        GratitudeQuestion(
            question: "what's a simple pleasure you're looking forward to?",
            chips: ["a good meal", "quiet time", "a walk", "music", "someone I like"]
        ),
    ]

    static func daily(for date: Date = Date()) -> GratitudeQuestion {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
        return pool[day % pool.count]
    }
}
