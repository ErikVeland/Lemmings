#if os(iOS) || os(tvOS)
import Foundation
import Testing
import LemmingsAppCore
import LemmingsGameArt
@testable import LemmingsMobileUI

@MainActor struct MobileAboutTests {
    private var content: AboutContent {
        AboutContent(heritage: "# Original creators\n\nDMA Design and Psygnosis.",
            versionHistory: "# 2.7.5 · Build 128\n\n- Current release.\n\n# 2.6 · Build 115\n\n- Earlier release.",
            contributors: "# Contributors\n\n## Supporters\n\nBundled supporter")
    }

    private func contributorsPage(_ state: MobileAboutState) -> GameFrontEnd.Page {
        MobileAboutArt.page(productName: "Ultimate Lemmix", version: "2.7.5", build: "128",
            showsLixCredits: true, content: state.content ?? .init(), section: .contributors,
            contributors: state.contributors, contributorStatus: state.status,
            allowsContributorRetry: state.showsRetry)
    }

    @Test func offlineCreditsRemainReadableAndRetryCachesTheSuccessfulList() async throws {
        let suite = "MobileAboutTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        let resources = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        let state = MobileAboutState(content: content, defaults: defaults,
            loadContributors: { throw URLError(.notConnectedToInternet) })
        defer {
            state.cancelContributors()
            defaults.removePersistentDomain(forName: suite)
        }
        state.prepare(resources: resources)
        state.refreshContributors(onChange: {})
        let firstRequest = try #require(state.task)
        await firstRequest.value
        #expect(contributorsPage(state).details.contains("Bundled supporter"))
        #expect(contributorsPage(state).details.contains("Supporters"))
        #expect(state.showsRetry)
        #expect(contributorsPage(state).rows.contains { $0.id == "aboutRetry" })
        #expect(defaults.string(forKey: AboutContent.contributorCacheKey) == nil)
        #expect(state.task == nil)

        let updated = "# Contributors\n\n## Supporters\n\nUpdated supporter"
        state.loadContributors = { updated }
        state.refreshContributors(onChange: {})
        let retry = try #require(state.task)
        await retry.value
        #expect(contributorsPage(state).details.contains("Updated supporter"))
        #expect(!contributorsPage(state).details.contains("Bundled supporter"))
        #expect(!state.showsRetry)
        #expect(state.status == nil)
        #expect(defaults.string(forKey: AboutContent.contributorCacheKey) == updated)

        state.cancelContributors()
        state.prepare(resources: resources)
        state.loadContributors = { throw URLError(.notConnectedToInternet) }
        state.refreshContributors(onChange: {})
        let reopened = try #require(state.task)
        await reopened.value
        #expect(contributorsPage(state).details.contains("Updated supporter"))
        #expect(state.showsRetry)
        #expect(defaults.string(forKey: AboutContent.contributorCacheKey) == updated)
    }

    @Test func lateContributorResponseCannotRepaintOrReplaceNewerCredits() async throws {
        let suite = "MobileAboutTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        let resources = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        var pending: CheckedContinuation<String, Error>?
        let state = MobileAboutState(content: content, defaults: defaults,
            loadContributors: { try await withCheckedThrowingContinuation { pending = $0 } })
        defer {
            state.cancelContributors()
            pending?.resume(throwing: CancellationError())
            defaults.removePersistentDomain(forName: suite)
        }
        var changes = 0
        state.prepare(resources: resources)
        state.refreshContributors { changes += 1 }
        let cancelled = try #require(state.task)
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        while pending == nil {
            try #require(ProcessInfo.processInfo.systemUptime < deadline)
            await Task.yield()
        }
        let response = try #require(pending)
        state.cancelContributors()
        #expect(cancelled.isCancelled)
        #expect(state.task == nil)
        #expect(state.status == nil)

        let updated = "# Contributors\n\n## Supporters\n\nCurrent supporter"
        state.prepare(resources: resources)
        state.loadContributors = { updated }
        state.refreshContributors { changes += 1 }
        let current = try #require(state.task)
        await current.value
        response.resume(returning: "# Contributors\n\nStale supporter")
        pending = nil
        await cancelled.value
        #expect(contributorsPage(state).details.contains("Current supporter"))
        #expect(!contributorsPage(state).details.contains("Stale supporter"))
        #expect(defaults.string(forKey: AboutContent.contributorCacheKey) == updated)
        #expect(state.task == nil)
        #expect(changes == 3)
    }

    @Test func releasingAboutStateCancelsTheRequestWithoutSavingItsLateResult() async throws {
        let suite = "MobileAboutTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var pending: CheckedContinuation<String, Error>?
        var state: MobileAboutState? = MobileAboutState(content: content, defaults: defaults,
            loadContributors: { try await withCheckedThrowingContinuation { pending = $0 } })
        defer {
            state?.cancelContributors()
            pending?.resume(throwing: CancellationError())
        }
        weak var releasedState = state
        var changes = 0
        state?.refreshContributors { changes += 1 }
        let request = try #require(state?.task)
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        while pending == nil {
            try #require(ProcessInfo.processInfo.systemUptime < deadline)
            await Task.yield()
        }
        let response = try #require(pending)
        state = nil
        #expect(releasedState == nil)
        #expect(request.isCancelled)
        response.resume(returning: "# Contributors\n\nLate supporter")
        pending = nil
        await request.value
        #expect(defaults.string(forKey: AboutContent.contributorCacheKey) == nil)
        #expect(changes == 1)
    }
}
#endif
