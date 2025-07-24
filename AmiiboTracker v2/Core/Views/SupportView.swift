//
//  SupportView.swift
//  AmiiboTracker v2
//
//  Created by Sam Stanwell on 21/07/2025.
//


import SwiftUI

struct SupportView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Text("Need Help?")
                    .font(.largeTitle.bold())
                    .padding(.top)

                Text("If you’re experiencing issues or have questions about AmiiboTracker, we’re here to help! Below are some ways to get support or provide feedback.")

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.accentColor)
                        Text("Email Support")
                            .font(.headline)
                        Spacer()
                    }
                    Text("support@amiibotracker.co.uk")
                        .foregroundColor(.secondary)
                        .contextMenu {
                            Button {
                             //   UIPasteboard.general.string = "support@amiibotracker.com"
                            } label: {
                                Label("Copy Email", systemImage: "doc.on.doc")
                            }
                        }
                    Button("Send Email") {
                        if let url = URL(string: "mailto:support@amiibotracker.co.uk") {
                            openURL(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Divider()

                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.accentColor)
                        Text("Website")
                            .font(.headline)
                        Spacer()
                    }
                    Text("https://amiibotracker.com")
                        .foregroundColor(.secondary)
                        .contextMenu {
                            Button {
                   //             UIPasteboard.general.string = "https://amiibotracker.com"
                            } label: {
                                Label("Copy URL", systemImage: "doc.on.doc")
                            }
                        }
                    Button("Visit Website") {
                        if let url = URL(string: "https://amiibotracker.com") {
                            openURL(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Support")
        }
    }
}

#if DEBUG
struct SupportView_Previews: PreviewProvider {
    static var previews: some View {
        SupportView()
    }
}
#endif
