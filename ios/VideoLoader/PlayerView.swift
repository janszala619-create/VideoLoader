import SwiftUI
import AVKit
import AVFoundation

/// Vollwertiger Videoplayer auf Basis von AVPlayerViewController:
/// unterstützt Bild-in-Bild und das eingebaute Geschwindigkeitsmenü.
struct PlayerView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        // Für Ton und Bild-in-Bild die Audiositzung auf Wiedergabe stellen.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)

        let controller = AVPlayerViewController()
        controller.player = AVPlayer(url: url)
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.player?.play()
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {}
}
