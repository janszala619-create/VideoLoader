import UIKit
import UniformTypeIdentifiers

/// Share Extension: greift den geteilten Link (URL oder Text) ab, legt ihn als
/// Sicherheitsnetz in die Zwischenablage und öffnet die VideoLoader-App über
/// das eigene URL-Schema mit vorausgefülltem Link.
class ShareViewController: UIViewController {

    private var didHandle = false

    // Erst hier ist die Ansicht mit dem System verbunden – vorher verpufft
    // der Versuch, die Haupt-App zu öffnen.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didHandle else { return }
        didHandle = true
        handleShare()
    }

    private func handleShare() {
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
            var opened = false
            if let link {
                let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    // Sicherheitsnetz: Link in die Zwischenablage legen. Die App
                    // erkennt ihn beim Öffnen auch dann, wenn das direkte Öffnen
                    // aus der Extension von iOS blockiert wird.
                    UIPasteboard.general.string = trimmed
                    if let appURL = Self.appURL(forLink: trimmed) {
                        opened = self.openHostApp(appURL)
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (opened ? 0.6 : 0.1)) {
                self.extensionContext?.completeRequest(returningItems: nil)
            }
        }
    }

    private static func appURL(forLink link: String) -> URL? {
        var components = URLComponents()
        components.scheme = "videoloader"
        components.host = "add"
        components.queryItems = [URLQueryItem(name: "url", value: link)]
        return components.url
    }

    /// Öffnet die Haupt-App. Extensions haben kein UIApplication.shared,
    /// deshalb wird das Anwendungsobjekt über die Responder-Kette gesucht –
    /// entscheidend ist, jedes Objekt zu prüfen, das auf openURL: reagiert.
    @discardableResult
    private func openHostApp(_ url: URL) -> Bool {
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                return true
            }
            if !(current is UIViewController), !(current is UIView), current.responds(to: selector) {
                current.perform(selector, with: url)
                return true
            }
            responder = current.next
        }
        // Letzter Versuch über den offiziellen Weg (je nach iOS-Version aktiv).
        extensionContext?.open(url, completionHandler: nil)
        return false
    }
}
