import SwiftUI

struct AuthView: View {
    @Environment(AuthViewModel.self) private var authVM

    enum Mode { case signIn, signUp, resetPassword }

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var resetSent = false

    private var passwordMismatch: Bool {
        mode == .signUp && !confirmPassword.isEmpty && password != confirmPassword
    }

    private var canSubmit: Bool {
        !email.isEmpty && (mode == .resetPassword || !password.isEmpty) && !passwordMismatch
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // ── Brand header ──
                VStack(spacing: 8) {
                    Image(systemName: "figure.walk.motion")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.ptTerracotta)
                    Text("PTHelper")
                        .font(.ptSerif(.largeTitle, weight: .bold))
                    Text("Your physical therapy companion")
                        .font(.ptSerif(.subheadline))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 60)
                .padding(.bottom, 40)

                // ── Card ──
                VStack(spacing: 20) {
                    // Mode title
                    Text(modeTitle)
                        .font(.ptSerif(.title3, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if mode == .resetPassword && resetSent {
                        resetSentBanner
                    } else {
                        fields
                        if let error = authVM.errorMessage {
                            errorBanner(error)
                        }
                        submitButton
                        modeLinks
                    }
                }
                .padding(24)
                .background(Color(.systemBackground))
                .cornerRadius(18)
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
                .padding(.horizontal, 24)

                if mode == .signIn {
                    guestButton
                        .padding(.top, 16)
                }

                Spacer(minLength: 48)
            }
        }
        .background(Color.ptBackground.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: mode)
    }

    // MARK: - Fields

    @ViewBuilder
    private var fields: some View {
        VStack(spacing: 14) {
            PTTextField(
                label: "Email",
                text: $email,
                keyboardType: .emailAddress,
                textContentType: .emailAddress,
                autocapitalization: .never
            )

            if mode != .resetPassword {
                PTTextField(
                    label: "Password",
                    text: $password,
                    textContentType: mode == .signUp ? .newPassword : .password,
                    isSecure: true
                )
            }

            if mode == .signUp {
                PTTextField(
                    label: "Confirm Password",
                    text: $confirmPassword,
                    textContentType: .newPassword,
                    isSecure: true
                )
                if passwordMismatch {
                    Text("Passwords do not match")
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Submit

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            ZStack {
                if authVM.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(submitLabel)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canSubmit ? Color.ptTerracotta : Color.ptTerracotta.opacity(0.4))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canSubmit || authVM.isLoading)
        .padding(.top, 4)
    }

    private func submit() async {
        switch mode {
        case .signIn:
            await authVM.signIn(email: email, password: password)
        case .signUp:
            await authVM.signUp(email: email, password: password)
        case .resetPassword:
            await authVM.resetPassword(email: email)
            if authVM.errorMessage == nil { resetSent = true }
        }
    }

    // MARK: - Mode links

    @ViewBuilder
    private var modeLinks: some View {
        VStack(spacing: 10) {
            if mode == .signIn {
                Button("Forgot password?") { mode = .resetPassword }
                    .font(.subheadline)
                    .foregroundColor(.ptTerracotta)
                Divider()
                Button("Create an account") { mode = .signUp }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.ptTerracotta)
            } else {
                Button("Back to sign in") {
                    mode = .signIn
                    resetSent = false
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
        }
        .padding(.top, 4)
    }

    private var guestButton: some View {
        Button {
            authVM.continueAsGuest()
        } label: {
            Text("Continue as Guest")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Banners

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.caption)
                .foregroundColor(.red)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08))
        .cornerRadius(8)
    }

    private var resetSentBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: "envelope.badge.checkmark")
                .font(.system(size: 36))
                .foregroundColor(.ptTerracotta)
            Text("Check your email")
                .font(.ptSerif(.headline, weight: .semibold))
            Text("We sent a password reset link to **\(email)**. Follow the link to set a new password.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Back to sign in") {
                mode = .signIn
                resetSent = false
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(.ptTerracotta)
            .padding(.top, 4)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Computed strings

    private var modeTitle: String {
        switch mode {
        case .signIn: return "Welcome back"
        case .signUp: return "Create account"
        case .resetPassword: return "Reset password"
        }
    }

    private var submitLabel: String {
        switch mode {
        case .signIn: return "Sign In"
        case .signUp: return "Create Account"
        case .resetPassword: return "Send Reset Email"
        }
    }
}

// MARK: - Reusable text field

private struct PTTextField: View {
    let label: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .sentences
    var isSecure = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
            Group {
                if isSecure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(autocapitalization)
                        .autocorrectionDisabled()
                }
            }
            .textContentType(textContentType)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}
