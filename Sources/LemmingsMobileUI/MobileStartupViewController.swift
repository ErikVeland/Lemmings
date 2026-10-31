#if os(iOS) || os(tvOS)
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import UIKit

/// Keep disk-backed controllers and services out of the system's first-frame path.
@MainActor final class MobileStartupViewController: UIViewController {
    private let logo = UIImageView(image: UIImage(named: "StartupLogo"))
    private let hourglass = MobileStartupHourglass()
    private var content: UIViewController?
    private var startupTask: Task<Void, Never>?
    nonisolated(unsafe) private var firstFrameLink: CADisplayLink?
    private var hasSubmittedFrame = false
    #if os(iOS)
    private var pendingDeskClock = false
    #endif

    #if os(iOS)
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    #endif
    override var preferredFocusEnvironments: [any UIFocusEnvironment] { content.map { [$0] } ?? [] }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        logo.contentMode = .scaleAspectFit
        logo.isAccessibilityElement = false
        view.addSubview(logo)
        view.addSubview(hourglass)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let layout = GameStartupArt.layout(in: view.bounds)
        logo.frame = layout.logo
        hourglass.frame = layout.hourglass
        content?.view.frame = view.bounds
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard startupTask == nil, content == nil, firstFrameLink == nil else { return }
        hourglass.startAnimating()
        let target = MobileDisplayLinkTarget { [weak self] _ in
            guard let self else { return }
            // A display-link callback precedes submission. The following callback confirms
            // that the loading surface had a frame before any disk-backed construction.
            guard self.hasSubmittedFrame else { self.hasSubmittedFrame = true; return }
            self.firstFrameLink?.invalidate()
            self.firstFrameLink = nil
            self.startLoading()
        }
        let link = CADisplayLink(target: target, selector: #selector(MobileDisplayLinkTarget.frame(_:)))
        firstFrameLink = link
        link.add(to: .main, forMode: .common)
    }

    private func startLoading() {
        hourglass.accessibilityLabel = L10n.text("Loading...")
        startupTask = Task { [weak self] in
            let support = try? FileManager.default.url(for: MobileStorage.localDirectory, in: .userDomainMask,
                                                       appropriateFor: nil, create: false)
            let catalogue = await MobileCatalogueLoader().load(resources: Bundle.main.resourceURL, support: support)
            guard let self, !Task.isCancelled else { return }
            #if os(tvOS)
            let controller = MobileTVBootstrap()
            controller.catalogue = catalogue
            #else
            let controller = MobileLibraryViewController()
            controller.catalogue = catalogue
            #endif
            addChild(controller)
            controller.view.frame = view.bounds
            view.addSubview(controller.view)
            content = controller
            controller.didMove(toParent: self)
            logo.removeFromSuperview()
            hourglass.removeFromSuperview()
            setNeedsFocusUpdate()
            updateFocusIfNeeded()
            #if os(iOS)
            if pendingDeskClock { openDeskClock() }
            #endif
        }
    }

    #if os(iOS)
    func openDeskClock() {
        guard let library = content as? MobileLibraryViewController else {
            pendingDeskClock = true
            return
        }
        pendingDeskClock = false
        library.loadViewIfNeeded()
        library.presentDeskClock(reason: .widget)
    }
    #endif

    deinit {
        firstFrameLink?.invalidate()
        startupTask?.cancel()
    }
}

@MainActor private final class MobileStartupHourglass: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        isAccessibilityElement = true
        accessibilityLabel = "Loading..."
        accessibilityTraits = .updatesFrequently
    }

    required init?(coder: NSCoder) { nil }

    func startAnimating() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1
        pulse.toValue = 0.35
        pulse.duration = 0.65
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        layer.add(pulse, forKey: "loading")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        GameStartupArt.drawHourglass(in: bounds, context: context)
    }
}
#endif
