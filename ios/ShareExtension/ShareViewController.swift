import UIKit
import UniformTypeIdentifiers

/// Share Extension: greift den geteilten Link (URL oder Text) ab, legt ihn als
/// Sicherheitsnetz in die Zwischenablage und öffnet die VideoLoader-App über
/// das eigene URL-Schema mit vorausgefülltem Link.
class ShareViewController: UIViewController {

    private var didHandle = false
    private let backgroundLayer = CAGradientLayer()
    private let cardView = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let linkLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let closeButton = UIButton(type: .system)
    private var completionWorkItem: DispatchWorkItem?

    private enum ShareState {
        case reading
        case opening(String)
        case success(String)
        case failure(String)

        var title: String {
            switch self {
            case .reading: return "Link wird gelesen"
            case .opening: return "VideoLoader wird geöffnet"
            case .success: return "Link übergeben"
            case .failure: return "Link nicht erkannt"
            }
        }

        var message: String {
            switch self {
            case .reading:
                return "Die geteilten Inhalte werden geprüft."
            case .opening:
                return "Der Link wird an VideoLoader gesendet."
            case .success:
                return "VideoLoader uebernimmt den geteilten Link."
            case .failure(let message):
                return message
            }
        }

        var iconName: String {
            switch self {
            case .reading: return "link"
            case .opening: return "arrow.up.forward.app.fill"
            case .success: return "checkmark.circle.fill"
            case .failure: return "exclamationmark.triangle.fill"
            }
        }

        var tint: UIColor {
            switch self {
            case .reading, .opening: return ShareDesign.Colors.accentPrimary
            case .success: return ShareDesign.Colors.success
            case .failure: return ShareDesign.Colors.warning
            }
        }

        var isLoading: Bool {
            switch self {
            case .reading, .opening: return true
            case .success, .failure: return false
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateUI(for: .reading, linkPreview: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundLayer.frame = view.bounds
    }

    // Erst hier ist die Ansicht mit dem System verbunden – vorher verpufft
    // der Versuch, die Haupt-App zu öffnen.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didHandle else { return }
        didHandle = true
        handleShare()
    }

    private func setupUI() {
        view.backgroundColor = ShareDesign.Colors.background

        backgroundLayer.colors = [
            ShareDesign.Colors.backgroundGlow.cgColor,
            ShareDesign.Colors.backgroundSoft.cgColor,
            ShareDesign.Colors.background.cgColor
        ]
        backgroundLayer.startPoint = CGPoint(x: 0, y: 0)
        backgroundLayer.endPoint = CGPoint(x: 1, y: 1)
        view.layer.insertSublayer(backgroundLayer, at: 0)

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = ShareDesign.Colors.surfaceStrong
        cardView.layer.cornerRadius = ShareDesign.Radius.large
        cardView.layer.cornerCurve = .continuous
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = ShareDesign.Colors.border.cgColor
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.18
        cardView.layer.shadowRadius = 18
        cardView.layer.shadowOffset = CGSize(width: 0, height: 10)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title2)
        iconView.contentMode = .center
        iconView.backgroundColor = ShareDesign.Colors.surfaceElevated
        iconView.layer.cornerRadius = ShareDesign.Radius.medium
        iconView.layer.cornerCurve = .continuous
        iconView.isAccessibilityElement = false

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = ShareDesign.Fonts.headline
        titleLabel.textColor = ShareDesign.Colors.textPrimary
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = ShareDesign.Fonts.body
        messageLabel.textColor = ShareDesign.Colors.textSecondary
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.numberOfLines = 0

        linkLabel.translatesAutoresizingMaskIntoConstraints = false
        linkLabel.font = ShareDesign.Fonts.footnote
        linkLabel.textColor = ShareDesign.Colors.textTertiary
        linkLabel.adjustsFontForContentSizeCategory = true
        linkLabel.numberOfLines = 2
        linkLabel.lineBreakMode = .byTruncatingMiddle
        linkLabel.isAccessibilityElement = false

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = ShareDesign.Colors.accentSecondary
        activityIndicator.hidesWhenStopped = true

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("Schließen", for: .normal)
        closeButton.titleLabel?.font = ShareDesign.Fonts.button
        closeButton.titleLabel?.adjustsFontForContentSizeCategory = true
        closeButton.tintColor = ShareDesign.Colors.textPrimary
        closeButton.backgroundColor = ShareDesign.Colors.surfaceElevated
        closeButton.layer.cornerRadius = ShareDesign.Radius.medium
        closeButton.layer.cornerCurve = .continuous
        closeButton.layer.borderWidth = 1
        closeButton.layer.borderColor = ShareDesign.Colors.border.cgColor
        closeButton.accessibilityLabel = "Share Extension schließen"
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, messageLabel, linkLabel])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = ShareDesign.Spacing.small

        let headerStack = UIStackView(arrangedSubviews: [iconView, textStack])
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.axis = .horizontal
        headerStack.alignment = .top
        headerStack.spacing = ShareDesign.Spacing.medium

        let actionStack = UIStackView(arrangedSubviews: [activityIndicator, closeButton])
        actionStack.translatesAutoresizingMaskIntoConstraints = false
        actionStack.axis = .horizontal
        actionStack.alignment = .center
        actionStack.spacing = ShareDesign.Spacing.medium

        let contentStack = UIStackView(arrangedSubviews: [headerStack, actionStack])
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = ShareDesign.Spacing.large

        view.addSubview(cardView)
        cardView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: ShareDesign.Spacing.extraLarge),
            cardView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -ShareDesign.Spacing.extraLarge),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: ShareDesign.Spacing.large),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -ShareDesign.Spacing.large),
            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: ShareDesign.Spacing.large),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -ShareDesign.Spacing.large),

            iconView.widthAnchor.constraint(equalToConstant: ShareDesign.Sizing.iconBox),
            iconView.heightAnchor.constraint(equalToConstant: ShareDesign.Sizing.iconBox),

            closeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: ShareDesign.Sizing.touchTarget),
            closeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 128)
        ])
    }

    private func handleShare() {
        updateUI(for: .reading, linkPreview: nil)
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []

        // Zuerst nach einer echten URL suchen …
        for item in items {
            for provider in item.attachments ?? [] where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { data, _ in
                    self.finish(with: (data as? URL)?.absoluteString)
                }
                return
            }
        }

        // … sonst einen geteilten Text (der oft einen Link enthält).
        for item in items {
            for provider in item.attachments ?? [] where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, _ in
                    self.finish(with: data as? String)
                }
                return
            }
        }

        finish(with: nil)
    }

    private func finish(with link: String?) {
        DispatchQueue.main.async {
            if let link {
                let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    self.updateUI(for: .opening(trimmed), linkPreview: trimmed)
                    // Sicherheitsnetz: Link in die Zwischenablage legen. Die App
                    // erkennt ihn beim Öffnen auch dann, wenn das direkte Öffnen
                    // aus der Extension von iOS blockiert wird.
                    UIPasteboard.general.string = trimmed
                    if let appURL = Self.appURL(forLink: trimmed) {
                        self.openHostApp(appURL, link: trimmed)
                        return
                    }
                }
            }
            self.updateUI(
                for: .failure("Es wurde keine gültige URL im geteilten Inhalt gefunden."),
                linkPreview: nil
            )
            self.completeAfterDelay(1.8)
        }
    }

    private static func appURL(forLink link: String) -> URL? {
        guard let encoded = link.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        return URL(string: "videoloader://add?url=\(encoded)")
    }

    private func openHostApp(_ url: URL, link: String) {
        guard let extensionContext = extensionContext else {
            updateUI(
                for: .failure("Der Link wurde kopiert. Öffne VideoLoader, um ihn zu übernehmen."),
                linkPreview: link
            )
            completeAfterDelay(2.4)
            return
        }

        extensionContext.open(url) { success in
            DispatchQueue.main.async {
                if success {
                    self.updateUI(for: .success(link), linkPreview: link)
                    self.completeAfterDelay(0.8)
                } else {
                    self.updateUI(
                        for: .failure("Der Link wurde kopiert. Öffne VideoLoader, um ihn zu übernehmen."),
                        linkPreview: link
                    )
                    self.completeAfterDelay(2.4)
                }
            }
        }
    }

    private func updateUI(for state: ShareState, linkPreview: String?) {
        iconView.image = UIImage(systemName: state.iconName)
        iconView.tintColor = state.tint
        titleLabel.text = state.title
        messageLabel.text = state.message
        linkLabel.text = linkPreview
        linkLabel.isHidden = linkPreview == nil
        view.accessibilityLabel = "\(state.title). \(state.message)"

        if state.isLoading {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }

    private func completeAfterDelay(_ delay: TimeInterval) {
        completionWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
        completionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    @objc private func closeTapped() {
        completionWorkItem?.cancel()
        extensionContext?.completeRequest(returningItems: nil)
    }
}

private enum ShareDesign {
    enum Colors {
        static let background = UIColor(red: 4 / 255, green: 6 / 255, blue: 11 / 255, alpha: 1)
        static let backgroundSoft = UIColor(red: 8 / 255, green: 16 / 255, blue: 30 / 255, alpha: 1)
        static let backgroundGlow = UIColor(red: 32 / 255, green: 40 / 255, blue: 77 / 255, alpha: 1)
        static let surfaceStrong = UIColor(red: 30 / 255, green: 39 / 255, blue: 60 / 255, alpha: 0.86)
        static let surfaceElevated = UIColor(red: 39 / 255, green: 48 / 255, blue: 72 / 255, alpha: 0.9)
        static let border = UIColor.white.withAlphaComponent(0.14)
        static let textPrimary = UIColor(red: 237 / 255, green: 237 / 255, blue: 239 / 255, alpha: 1)
        static let textSecondary = UIColor(red: 181 / 255, green: 187 / 255, blue: 198 / 255, alpha: 1)
        static let textTertiary = UIColor(red: 137 / 255, green: 144 / 255, blue: 156 / 255, alpha: 1)
        static let accentPrimary = UIColor(red: 111 / 255, green: 124 / 255, blue: 255 / 255, alpha: 1)
        static let accentSecondary = UIColor(red: 150 / 255, green: 160 / 255, blue: 255 / 255, alpha: 1)
        static let success = UIColor(red: 34 / 255, green: 197 / 255, blue: 94 / 255, alpha: 1)
        static let warning = UIColor(red: 245 / 255, green: 158 / 255, blue: 11 / 255, alpha: 1)
    }

    enum Fonts {
        static let headline = UIFont.preferredFont(forTextStyle: .headline)
        static let body = UIFont.preferredFont(forTextStyle: .body)
        static let footnote = UIFont.preferredFont(forTextStyle: .footnote)
        static let button = UIFont.preferredFont(forTextStyle: .headline)
    }

    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 24
    }

    enum Radius {
        static let medium: CGFloat = 16
        static let large: CGFloat = 20
    }

    enum Sizing {
        static let touchTarget: CGFloat = 44
        static let iconBox: CGFloat = 48
    }
}
