import Foundation

/// Everyday subjects people keep folders for. When Sight finds a group of
/// files that fit none of the user's rules, the closest topic here gives the
/// new folder a real, human name ("Recipes", "Travel") instead of a keyword.
public struct Topic: Sendable, Hashable {
    public let english: String
    public let russian: String
    /// Short descriptions of what belongs in the folder. They double as the
    /// prompt of the rule that gets created.
    public let anchors: [String]

    public func name(russian useRussian: Bool) -> String { useRussian ? russian : english }
    public var prompt: String { anchors.joined(separator: ", ") }
}

public enum TopicCatalog {
    public static let all: [Topic] = [
        Topic(english: "Recipes", russian: "Рецепты",
              anchors: ["cooking recipe with ingredients and steps", "meal plan or menu", "baking and kitchen tips"]),
        Topic(english: "Travel", russian: "Путешествия",
              anchors: ["travel itinerary or trip plan", "flight tickets and hotel booking", "travel guide for a destination"]),
        Topic(english: "Fitness", russian: "Спорт и фитнес",
              anchors: ["workout plan or exercise routine", "fitness and training program", "nutrition and diet plan"]),
        Topic(english: "Health", russian: "Здоровье",
              anchors: ["medical test results or doctor report", "prescription or treatment plan", "health insurance claim"]),
        Topic(english: "Insurance", russian: "Страховки",
              anchors: ["insurance policy document", "insurance claim or coverage terms"]),
        Topic(english: "Legal", russian: "Юридические",
              anchors: ["legal document or court paperwork", "power of attorney or notarized document", "terms and conditions"]),
        Topic(english: "Real Estate", russian: "Недвижимость",
              anchors: ["apartment rental or property listing", "mortgage or home purchase documents", "utility bills for a home"]),
        Topic(english: "Courses", russian: "Курсы",
              anchors: ["online course material and lessons", "training program syllabus", "certificate of completion"]),
        Topic(english: "Research Papers", russian: "Научные статьи",
              anchors: ["academic research paper with abstract and references", "scientific article or journal publication"]),
        Topic(english: "Books", russian: "Книги",
              anchors: ["book chapter or full book text", "ebook or novel", "book summary and reading notes"]),
        Topic(english: "Manuals", russian: "Инструкции",
              anchors: ["product manual and setup instructions", "warranty and device specifications"]),
        Topic(english: "Tickets", russian: "Билеты",
              anchors: ["event ticket or boarding pass", "concert or cinema booking confirmation"]),
        Topic(english: "Music Sheets", russian: "Ноты и тексты",
              anchors: ["sheet music or chord chart", "song lyrics"]),
        Topic(english: "Games", russian: "Игры",
              anchors: ["video game guide or walkthrough", "game mods and save data"]),
        Topic(english: "Investing", russian: "Инвестиции",
              anchors: ["investment portfolio and stock analysis", "cryptocurrency and trading notes"]),
        Topic(english: "Shopping", russian: "Покупки",
              anchors: ["online order confirmation", "product wishlist and price comparison"]),
        Topic(english: "Job Search", russian: "Поиск работы",
              anchors: ["job listings and interview preparation", "career plan and networking notes"]),
        Topic(english: "Languages", russian: "Языки",
              anchors: ["vocabulary lists and grammar exercises", "language learning lessons"]),
        Topic(english: "Tutorials", russian: "Туториалы",
              anchors: ["programming tutorial or technical guide", "step by step how-to article"]),
        Topic(english: "AI Notes", russian: "ИИ",
              anchors: ["prompts for language models and AI assistants", "machine learning experiments and notes"]),
        Topic(english: "Cars", russian: "Авто",
              anchors: ["car maintenance and repair", "vehicle registration and driving documents"]),
        Topic(english: "Wedding", russian: "Свадьба",
              anchors: ["wedding planning and guest list", "wedding invitations and vendors"]),
        Topic(english: "Kids", russian: "Дети",
              anchors: ["school and kindergarten documents for children", "parenting and child activities"]),
        Topic(english: "Pets", russian: "Питомцы",
              anchors: ["pet care and veterinary records", "dog or cat training"]),
        Topic(english: "Home Projects", russian: "Дом и ремонт",
              anchors: ["home renovation and furniture plans", "garden and DIY projects"]),
        Topic(english: "Finance", russian: "Финансы",
              anchors: ["personal budget and expenses tracking", "loan, credit card and savings documents"]),
        Topic(english: "Inspiration", russian: "Вдохновение",
              anchors: ["inspiration collection and design references", "ideas and concept notes"]),
        Topic(english: "Memes", russian: "Мемы",
              anchors: ["funny meme image", "reaction gif and humor"])
    ]
}
