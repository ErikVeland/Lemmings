import Foundation

public extension TrolleyArchetype {
    var philosophySummary: String {
        switch id {
        case "bentham": "Jeremy Bentham judged actions by their effects on happiness and suffering. Each person's welfare counts."
        case "mill": "John Stuart Mill was a utilitarian. He valued everyone's well-being and distinguished higher and lower pleasures."
        case "kant": "Immanuel Kant emphasised moral duty and respect for people. People must never be treated merely as tools."
        case "singer": "Peter Singer argues for reducing suffering and using evidence to find where our resources can do the most good."
        case "aristotle": "Aristotle linked a good life to character, practical judgement and habits that avoid excess and deficiency."
        case "epicurus": "Epicurus valued freedom from pain and anxiety. Simple pleasures, friendship and moderation support a good life."
        case "hobbes": "Thomas Hobbes saw peace and security as essential. Shared rules and authority protect people from conflict."
        case "sartre": "Jean-Paul Sartre emphasised freedom and responsibility. Our choices help define who we become."
        case "popper": "Karl Popper argued that scientific claims must be open to refutation by evidence. A failed prediction calls for revision."
        case "absurdist": "A fictional play style for an unlikely rescue. Inspired by the tension between our search for meaning and an indifferent world."
        case "humanist": "A fictional play style centred on care for each lemming. Humanism places human welfare and agency at the centre of ethics."
        case "bureaucrat": "A fictional play style for meeting the minimum exactly. The Bureaucrat values a completed checklist."
        case "trolley_operator": "A fictional play style inspired by the trolley problem: whether sacrificing one person to save several can be justified."
        default: "A neutral play style for a run that does not strongly match another style. It is not a score or an achievement requirement."
        }
    }

    var affinityDescription: String {
        switch id {
        case "bentham", "trolley_operator": "A recorded sacrifice enabled other rescues."
        case "mill": "High rescue rate with efficient skill use."
        case "kant": "Full rescue with no destructive skills or nuke."
        case "singer": "High rescue rate with few resources spent."
        case "aristotle": "A balance of rescue, resource use and intervention."
        case "epicurus": "High rescue rate with little intervention."
        case "hobbes": "Level cleared despite substantial losses."
        case "sartre": "A successful rescue through a documented unusual route."
        case "popper": "More rescued than the previous best-known target."
        case "absurdist": "Level cleared with extensive skill use, nukes or rewinds."
        case "humanist": "A high rescue rate, well above the minimum."
        case "bureaucrat": "Level cleared at or just above the minimum."
        default: "No strong match to another play style."
        }
    }
}
