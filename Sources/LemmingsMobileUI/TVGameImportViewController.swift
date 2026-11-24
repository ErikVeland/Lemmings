#if os(tvOS)
import CoreImage.CIFilterBuiltins
import NxlvKit
import UIKit

/**
 * Pairs a local browser with the TV without a game-data host or player account.
 */
@MainActor final class TVGameImportViewController: UIViewController {
    private let importDirectory: @Sendable (URL) throws -> Void
    private let helperURL: URL?
    private let onImported: @MainActor () -> Void
    private let titleLabel = MobilePixelLabel()
    private let addressLabel = MobilePixelLabel()
    private let statusLabel = MobilePixelLabel()
    private let qrView = UIImageView()
    private let backButton = MobilePixelButton()
    private let restartButton = MobilePixelButton()
    private let observers = MobileNotificationObserverBag()
    private var server: TVGameImportServer?

    init(importDirectory: @escaping @Sendable (URL) throws -> Void, helperURL: URL?,
         onImported: @escaping @MainActor () -> Void) {
        self.importDirectory = importDirectory
        self.helperURL = helperURL
        self.onImported = onImported
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        titleLabel.text = L10n.text("Import owned games").uppercased()
        titleLabel.palette = .green
        titleLabel.maximumScale = 6
        addressLabel.maximumScale = 3
        statusLabel.maximumScale = 3
        statusLabel.numberOfLines = 2
        qrView.contentMode = .scaleAspectFit
        qrView.layer.magnificationFilter = .nearest
        qrView.isAccessibilityElement = true
        qrView.accessibilityLabel = L10n.text("Transfer address QR code")
        backButton.title = L10n.text("Back").uppercased()
        backButton.onPress = { [weak self] in self?.dismiss(animated: true) }
        restartButton.title = L10n.text("New address").uppercased()
        restartButton.isPrimary = true
        restartButton.isHidden = true
        restartButton.onPress = { [weak self] in self?.startTransfer() }
        for item in [titleLabel, addressLabel, statusLabel, qrView, backButton, restartButton] as [UIView] {
            view.addSubview(item)
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.server?.stop()
                self?.showFailure(L10n.text("Transfer paused. Choose a new address."))
            }
        })
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if server == nil { startTransfer() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        server?.stop()
        server = nil
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        restartButton.isHidden ? [backButton] : [restartButton, backButton]
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { $0.type == .menu }) {
            dismiss(animated: true)
        } else {
            super.pressesBegan(presses, with: event)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let safe = view.safeAreaLayoutGuide.layoutFrame.insetBy(dx: 30, dy: 18)
        titleLabel.frame = CGRect(x: safe.minX, y: safe.minY, width: safe.width, height: 70)
        let size = min(330, max(120, safe.height * 0.39))
        qrView.frame = CGRect(x: safe.midX - size / 2, y: titleLabel.frame.maxY + 24, width: size, height: size)
        addressLabel.frame = CGRect(x: safe.minX, y: qrView.frame.maxY + 20, width: safe.width, height: 48)
        statusLabel.frame = CGRect(x: safe.minX + 50, y: addressLabel.frame.maxY + 14,
                                  width: safe.width - 100, height: 90)
        backButton.frame = CGRect(x: safe.minX, y: safe.maxY - 78, width: 300, height: 72)
        restartButton.frame = CGRect(x: safe.maxX - 370, y: safe.maxY - 78, width: 370, height: 72)
    }

    private func startTransfer() {
        server?.stop()
        restartButton.isHidden = true
        statusLabel.palette = .blue
        statusLabel.text = L10n.text("Starting").uppercased()
        let next = TVGameImportServer(importDirectory: importDirectory, helperURL: helperURL)
        server = next
        next.onState = { [weak self] state in
            guard let self else { return }
            switch state {
            case let .ready(url):
                self.addressLabel.text = url.absoluteString
                self.qrView.accessibilityValue = url.absoluteString
                let filter = CIFilter.qrCodeGenerator()
                filter.message = Data(url.absoluteString.utf8)
                filter.correctionLevel = "M"
                if let image = filter.outputImage,
                   let cg = CIContext().createCGImage(image, from: image.extent) {
                    self.qrView.image = UIImage(cgImage: cg)
                }
                self.statusLabel.text = L10n.text("Scan or open this address on a phone or computer").uppercased()
            case let .receiving(bytes):
                self.statusLabel.text = L10n.text("Received \(bytes / 1_024) KB").uppercased()
            case .validating:
                self.statusLabel.text = L10n.text("Checking game files").uppercased()
            case let .failed(message):
                self.showFailure(message)
            }
        }
        next.onImported = { [weak self] in
            guard let self else { return }
            self.dismiss(animated: true, completion: self.onImported)
        }
        next.start()
    }

    private func showFailure(_ message: String) {
        statusLabel.text = message
        statusLabel.palette = .warning
        addressLabel.text = ""
        qrView.image = nil
        restartButton.isHidden = false
        setNeedsFocusUpdate()
    }
}
#endif
