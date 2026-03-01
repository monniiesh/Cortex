import SwiftUI
import UniformTypeIdentifiers

struct VaultPickerView: UIViewControllerRepresentable {
    @Environment(AppState.self) private var appState
    @Environment(VaultBookmarkService.self) private var vaultBookmarkService
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: VaultPickerView

        init(_ parent: VaultPickerView) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.vaultBookmarkService.saveBookmark(for: url)
            parent.appState.isVaultConnected = parent.vaultBookmarkService.hasVaultFolder
            parent.appState.vaultFolderName = url.lastPathComponent
            parent.dismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}
