#if os(iOS)
import LemmingsAppCore
import LemmingsGameArt
import UIKit

@MainActor final class MobileInsightsState {
    var summary: AnonymousTelemetrySummary?
    var days = 30
    var loading = false
    var token = ""
    var field: UITextField?
    var task: Task<Void, Never>?
}

extension MobileLibraryViewController {
    func insightsDashboardPage() -> GameFrontEnd.Page {
        let summary = mobileInsights.summary ?? AnonymousTelemetry.shared.localSummary()
        let counts = ["starts": summary.total(.levelStart), "wins": summary.total(.levelWin),
                      "fails": summary.total(.levelFail), "abandoned": summary.total(.levelAbandon),
                      "saved": summary.total(.lemmingsSaved), "solo": summary.total(.levelStart, mode: "solo"),
                      "hotSeat": summary.total(.levelStart, mode: "hot_seat"),
                      "music": summary.total(.allSoundtracksSelected), "downloads": summary.total(.allSoundtracksDownloaded)]
        return MobileInformationArt.insights(counts: counts, shared: mobileInsights.summary != nil,
            days: mobileInsights.days, sharingAvailable: AnonymousTelemetry.shared.sharingAvailable,
            loading: mobileInsights.loading, notice: notice)
    }
    func insightsTokenPage() -> GameFrontEnd.Page { MobileInformationArt.insightsToken(length: mobileInsights.token.count) }
    func insightsClearPage() -> GameFrontEnd.Page { MobileInformationArt.insightsClear() }
    func handleInsights(_ id: String) -> Bool {
        switch id {
        case "insightsLocal": mobileInsights.summary = nil; rebuild()
        case "insightsDays": mobileInsights.days = mobileInsights.days == 30 ? 7 : 30; mobileInsights.summary = nil; rebuild()
        case "insightsClear": navigate(.insightsClear)
        case "insightsClearConfirm": AnonymousTelemetry.shared.clearLocalCounts(); mobileInsights.summary = nil; navigate(.playInsights)
        case "insightsShared":
            mobileInsights.token = ""; navigate(.insightsToken); editInsightsToken()
        case "insightsTokenEdit": editInsightsToken()
        case "insightsLoad":
            let token = mobileInsights.token, days = mobileInsights.days
            guard !token.isEmpty else { return true }
            mobileInsights.token = ""; mobileInsights.field?.resignFirstResponder()
            mobileInsights.field?.removeFromSuperview(); mobileInsights.field = nil
            mobileInsights.loading = true; navigate(.playInsights)
            mobileInsights.task?.cancel()
            mobileInsights.task = Task { [weak self] in
                do {
                    let summary = try await AnonymousTelemetry.shared.sharedSummary(token: token, days: days)
                    guard !Task.isCancelled, let self, self.route == .playInsights else { return }
                    self.mobileInsights.summary = summary
                } catch {
                    guard !Task.isCancelled, let self else { return }
                    self.notice = "Check the access token and service."
                }
                self?.mobileInsights.loading = false; self?.rebuild()
            }
        default: return false
        }
        return true
    }
    private func editInsightsToken() {
        if let field = mobileInsights.field { field.becomeFirstResponder(); return }
        let field = UITextField()
        field.isSecureTextEntry = true; field.autocapitalizationType = .none; field.autocorrectionType = .no
        field.returnKeyType = .go; field.accessibilityLabel = "Dashboard access token"
        field.frame = CGRect(x: -100, y: -100, width: 10, height: 10); field.alpha = 0.01
        field.addAction(UIAction { [weak self, weak field] _ in
            guard let self else { return }
            self.mobileInsights.token = field?.text ?? ""; self.rebuild()
        }, for: .editingChanged)
        field.addAction(UIAction { [weak self] _ in _ = self?.handleInsights("insightsLoad") }, for: .editingDidEndOnExit)
        view.addSubview(field); mobileInsights.field = field; field.becomeFirstResponder()
    }
}
#endif
