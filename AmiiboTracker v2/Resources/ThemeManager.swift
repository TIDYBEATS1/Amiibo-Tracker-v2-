import SwiftUI
import Combine

enum AppTheme: String, CaseIterable, Identifiable {
    case light, dark

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

final class ThemeManager: ObservableObject {
    @AppStorage("appTheme") private var storedThemeRawValue: String = AppTheme.light.rawValue

    @Published var selectedTheme: AppTheme

    private var cancellables = Set<AnyCancellable>()

    init() {
        let rawValue = UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.light.rawValue
        
        if let stored = AppTheme(rawValue: rawValue) {
            selectedTheme = stored
        } else {
            selectedTheme = .light
        }

        $selectedTheme
            .sink { [weak self] newTheme in
                DispatchQueue.main.async {
                    self?.storedThemeRawValue = newTheme.rawValue
                }
            }
            .store(in: &cancellables)
    }

    var colorScheme: ColorScheme? {
        switch selectedTheme {
        case .light: return .light
        case .dark: return .dark
        }
    }
}
