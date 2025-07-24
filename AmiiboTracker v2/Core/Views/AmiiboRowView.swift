import SwiftUI
import SDWebImageSwiftUI

struct AmiiboRowView: View {
    var amiibo: Amiibo
    var toggleOwned: () -> Void

    var body: some View {
        HStack {
            // Load image from local URL or remote URL
            if let localImageData = try? Data(contentsOf: amiibo.localImageURL),
               let image = platformImage(from: localImageData) {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
            } else if let url = amiibo.imageURL {
                WebImage(url: url)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .foregroundColor(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
            }

            VStack(alignment: .leading) {
                Text(amiibo.name)
                    .font(.headline)
                Text(amiibo.series)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                toggleOwned()
            } label: {
                Image(systemName: amiibo.isOwned ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(amiibo.isOwned ? .green : .gray)
                    .imageScale(.large)
            }
            .buttonStyle(PlainButtonStyle()) // works on both platforms
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color.secondarySystemBackground)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
        .padding(.horizontal)
    }

    // Helper function to convert Data to UIImage (iOS) or NSImage (macOS)
    @ViewBuilder
    private func platformImage(from data: Data) -> PlatformImage? {
        #if os(iOS)
        return UIImage(data: data)
        #elseif os(macOS)
        return NSImage(data: data)
        #else
        return nil
        #endif
    }
}

// Typealias for platform-specific image
#if os(iOS)
typealias PlatformImage = UIImage
#elseif os(macOS)
typealias PlatformImage = NSImage
#endif

// Helper extension to create SwiftUI Image from platform image
extension Image {
    init(platformImage: PlatformImage) {
        #if os(iOS)
        self.init(uiImage: platformImage)
        #elseif os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(systemName: "photo")
        #endif
    }
}
