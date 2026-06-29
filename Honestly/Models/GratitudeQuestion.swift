import Foundation

struct GratitudeQuestion {
    let question: String
    let chips: [String]

    static let pool: [GratitudeQuestion] = [
        GratitudeQuestion(
            question: L("what small habit has been good for you?"),
            chips: [L("a meal I enjoyed"), L("something beautiful"), L("a moment I'm proud of"), L("a person, a smell, a moment")]
        ),
        GratitudeQuestion(
            question: L("what made you smile yesterday?"),
            chips: [L("morning coffee"), L("a kind text"), L("my quiet room"), L("morning light"), L("a deep breath"), L("a comfort song")]
        ),
        GratitudeQuestion(
            question: L("who are you grateful for today?"),
            chips: [L("my family"), L("a close friend"), L("my partner"), L("someone who helped"), L("a stranger")]
        ),
        GratitudeQuestion(
            question: L("what's something small that made a difference?"),
            chips: [L("good sleep"), L("a good meal"), L("sunny weather"), L("getting things done"), L("a good laugh")]
        ),
        GratitudeQuestion(
            question: L("what do you have today that you once wished for?"),
            chips: [L("my home"), L("my health"), L("my work"), L("people I love"), L("time to myself")]
        ),
        GratitudeQuestion(
            question: L("what's a simple pleasure you're looking forward to?"),
            chips: [L("a good meal"), L("quiet time"), L("a walk"), L("music"), L("someone I like")]
        ),
    ]

    static func daily(for date: Date = Date()) -> GratitudeQuestion {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
        return pool[day % pool.count]
    }
}
