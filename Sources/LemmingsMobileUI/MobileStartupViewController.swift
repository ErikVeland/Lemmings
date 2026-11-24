#if os(iOS) || os(tvOS)
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import UIKit

/// Keep disk-backed controllers and services out of the system's first-frame path.
@MainActor final class MobileStartupViewController: UIViewController {
    private let configuration: LemmingsMobileConfiguration
    init(configuration: LemmingsMobileConfiguration = .current) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { nil }
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
        #if os(iOS)
        if UIApplication.shared.alternateIconName == "RestoredIcon" { logo.image = nil }
        #endif
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
            let restored = await Task.detached(priority: .userInitiated) {
                Result { try MobileResourceAccess.restoredBundleURL() }
            }.value
            guard let self, !Task.isCancelled else { return }
            let resourceNotice: String?
            do {
                try GameResources.activate(bundleURL: try restored.get())
                if GameMenuLogo.usesRestoredArtwork, let image = MobileGameArt.typography?.menuLogo {
                    logo.image = UIImage(cgImage: image)
                }
                resourceNotice = nil
            } catch {
                resourceNotice = error.localizedDescription
            }
            MobileLixArtwork.activate()
            MobileWidgetResources.publish()
            let support = try? FileManager.default.url(for: MobileStorage.localDirectory, in: .userDomainMask,
                                                       appropriateFor: nil, create: false)
            let catalogue = await MobileCatalogueLoader().load(resources: GameResources.resourceURL, support: support)
            guard !Task.isCancelled else { return }
            #if os(tvOS)
            let controller = MobileTVBootstrap(configuration: configuration)
            controller.catalogue = catalogue
            controller.resourceNotice = resourceNotice
            #else
            let controller = MobileLibraryViewController(configuration: configuration)
            controller.catalogue = catalogue
            if let resourceNotice { controller.notice = resourceNotice }
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
