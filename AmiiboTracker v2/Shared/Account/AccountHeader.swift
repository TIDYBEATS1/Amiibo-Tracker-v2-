import SwiftUI
import FirebaseAuth
#if os(iOS)
import PhotosUI
#elseif os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

struct AccountHeader: View {
    @State private var displayName: String = ""
    @State private var email: String = ""
    @State private var uid: String = ""

    @State private var showEmail = false
    @State private var showUID = false
    @State private var copied = false
    @State private var localImageURL: URL? = nil
    @AppStorage("localImagePath") private var localImagePath: String?

    #if os(iOS)
    @State private var selectedItem: PhotosPickerItem?
    #endif

    var body: some View {
        HStack(spacing: 16) {
            #if os(iOS)
            PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                avatarView
            }
            .onChange(of: selectedItem) { newItem in
                if let newItem = newItem {
                    Task {
                        await loadAndSavePhotoPickerItem(newItem)
                    }
                }
            }
            #elseif os(macOS)
            avatarView
                .onTapGesture {
                    pickImage()
                }
                .help("Click to change profile photo")
            #endif

            VStack(alignment: .leading, spacing: 4) {
                Text(showUID ? uid : (displayName.isEmpty ? "Unknown User" : displayName))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(showUID ? .blue : .primary)
                    .onTapGesture {
                        withAnimation(.easeInOut) {
                            showUID = true
                            copied = true
                            copyToClipboard(uid)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(.easeInOut) {
                                showUID = false
                                copied = false
                            }
                        }
                    }

                Text(showEmail ? (email.isEmpty ? "No Email" : email) : "Show Email")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .onTapGesture {
                        withAnimation(.easeInOut) {
                            showEmail = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            withAnimation(.easeInOut) {
                                showEmail = false
                            }
                        }
                    }

                if copied {
                    Text("UID copied to clipboard")
                        .font(.caption)
                        .foregroundColor(.green)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .onAppear(perform: loadUserInfo)
    }

    private var avatarView: some View {
        Group {
            if let url = localImageURL, let img = loadImageFromDisk(url) {
                #if os(iOS)
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                #elseif os(macOS)
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                #endif
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(
                        LinearGradient(colors: [.accentColor, .accentColor.opacity(0.6)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(Circle())
    }

    private func saveImageData(_ data: Data) {
        do {
            let filename = getDocumentsDirectory().appendingPathComponent("profile_photo.jpg")
            try data.write(to: filename)
            print("Saved image to: \(filename)")
            DispatchQueue.main.async {
                localImageURL = filename
                localImagePath = filename.path
            }
        } catch {
            print("Failed to save image data locally: \(error)")
        }
    }

    private func loadUserInfo() {
        if let path = localImagePath {
            localImageURL = URL(fileURLWithPath: path)
        }
        if let user = Auth.auth().currentUser {
            displayName = user.displayName ?? "No Name"
            email = user.email ?? "No Email"
            uid = user.uid
        }
    }

    #if os(iOS)
    private func loadAndSavePhotoPickerItem(_ item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                saveImageData(data)
            }
        } catch {
            print("Error loading photo picker item: \(error)")
        }
    }
    #endif

    private func loadImageFromDisk(_ url: URL) -> PlatformImage? {
        #if os(iOS)
        return UIImage(contentsOfFile: url.path)
        #elseif os(macOS)
        return NSImage(contentsOf: url)
        #endif
    }

    private func getDocumentsDirectory() -> URL {
        #if os(iOS)
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        #elseif os(macOS)
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        #endif
    }

    private func pickImage() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let data = try? Data(contentsOf: url) {
                    saveImageData(data)
                }
            }
        }
        #endif
    }

    private func copyToClipboard(_ string: String) {
        #if os(iOS)
        UIPasteboard.general.string = string
        #elseif os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
        #endif
    }
}

struct AccountHeader_Previews: PreviewProvider {
    static var previews: some View {
        AccountHeader()
            .padding()
            .frame(width: 400)
    }
}
