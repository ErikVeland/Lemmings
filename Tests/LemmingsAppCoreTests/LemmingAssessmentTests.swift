import CryptoKit
import Foundation
import NxlvKit
import Testing
@testable import LemmingsAppCore

@MainActor struct LemmingAssessmentTests {
    @Test func authoredStoriesAreTenWordsUniqueAndFrozen() {
        let language = L10n.currentLanguagePreference
        L10n.setLanguage(.english)
        defer { L10n.setLanguage(language) }
        let stories = (0..<LemmingAssessmentCatalogue.count).map {
            let pair = LemmingAssessmentCatalogue.story(at: $0)
            #expect(!pair.0.isEmpty && !pair.1.isEmpty)
            return pair.0 + " " + pair.1
        }
        #expect(stories.count == 128)
        #expect(Set(stories).count == stories.count)
        for story in stories {
            #expect(story.split(whereSeparator: \.isWhitespace).count == 10, "\(story)")
        }
        // Changing a frozen catalogue would rewrite personalities in restored runs.
        let digest = SHA256.hash(data: Data(stories.joined(separator: "\n").utf8))
            .map { String(format: "%02x", $0) }.joined()
        #expect(LemmingInspection.catalogueVersion == 2)
        #expect(digest == "40af57afad246de9b2ac4414712b3399f55246862289ca8f31da8843c7fef5fd")
    }

    @Test func cohortsDoNotRepeatStoriesAndActorOrderCannotChangeThem() {
        for seed in [UInt64(0), 1, 127, 128, 65_535, 0x123456789abcdef0, .max] {
            let cohort = (0..<128).map { LemmingAssessmentCatalogue.index(seed: seed, actorID: $0) }
            #expect(Set(cohort) == Set(0..<128))
            for id in [127, 5, 0, 80, 1] {
                #expect(LemmingAssessmentCatalogue.index(seed: seed, actorID: id) == cohort[id])
            }
        }
        // A saved scope retains its mapping even if the selection code is refactored.
        #expect([0, 1, 2, 127, 128].map {
            LemmingAssessmentCatalogue.index(seed: 0x123456789abcdef0, actorID: $0)
        } == [94, 87, 80, 101, 94])
    }
}
