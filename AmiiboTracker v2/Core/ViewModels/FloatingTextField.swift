import SwiftUI

struct FloatingTextField<FieldIdentifier: Hashable>: View {
    @Binding var text: String
    var title: String
    var keyboardType: FloatingKeyboardType = .default
    
    var isSecure: Bool
    var focusedField: FocusState<FieldIdentifier?>.Binding
    var fieldIdentifier: FieldIdentifier
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.red) // or AppColors.amiiboRed
            
            if isSecure {
                #if os(iOS)
                SecureField("", text: $text)
                    .focused(focusedField, equals: fieldIdentifier)
                    .keyboardType(keyboardType.uiKeyboardType)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                #elseif os(macOS)
                SecureField("", text: $text)
                    .focused(focusedField, equals: fieldIdentifier)
                    .padding(12)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                #endif
            } else {
                #if os(iOS)
                TextField("", text: $text)
                    .focused(focusedField, equals: fieldIdentifier)
                    .keyboardType(keyboardType.uiKeyboardType)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                #elseif os(macOS)
                TextField("", text: $text)
                    .focused(focusedField, equals: fieldIdentifier)
                    .padding(12)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                #endif
            }
        }
    }
}

enum FloatingKeyboardType {
    case `default`
    case emailAddress
    
    #if os(iOS)
    var uiKeyboardType: UIKeyboardType {
        switch self {
        case .default: return .default
        case .emailAddress: return .emailAddress
        }
    }
    #endif
}
    
    
