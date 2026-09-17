import SwiftUI
internal import Auth

struct ProfileView: View {
    @Environment(AuthViewModel.self) private var authVM

    @State private var fullName = ""
    @State private var username = ""
    @State private var isSaving = false
    @State private var savedConfirmation = false

    var body: some View {
        if authVM.isGuest {
            guestPrompt
        } else {
            profileContent
        }
    }

    private var guestPrompt: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(.ptTerracotta)
            VStack(spacing: 8) {
                Text("You're browsing as a guest")
                    .font(.ptSerif(.title3, weight: .semibold))
                Text("Create a free account to save your routines, track progress, and sync across devices.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            VStack(spacing: 12) {
                NavigationLink {
                    AuthView()
                } label: {
                    Text("Create Account")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.ptTerracotta)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)

                Button {
                    Task { await authVM.signOut() }
                } label: {
                    Text("Exit Guest Mode")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ptBackground.ignoresSafeArea())
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private var profileContent: some View {
        List {
            // Account info
            Section {
                if let email = authVM.currentUser?.email {
                    LabeledContent("Email") {
                        Text(email)
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                }
                LabeledContent("User ID") {
                    Text(authVM.currentUser?.id.uuidString.prefix(8).description ?? "—")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .fontDesign(.monospaced)
                }
            } header: {
                Text("Account")
                    .font(.ptSerif(.subheadline, weight: .semibold))
            }

            // Editable profile
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Display Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Your name", text: $fullName)
                        .font(.body)
                }
                .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Username")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("@handle (optional)", text: $username)
                        .font(.body)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(.vertical, 2)
            } header: {
                Text("Profile")
                    .font(.ptSerif(.subheadline, weight: .semibold))
            } footer: {
                if savedConfirmation {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            // Save button
            Section {
                Button {
                    Task { await save() }
                } label: {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save Profile")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .foregroundColor(isSaving ? .secondary : .ptTerracotta)
                .disabled(isSaving)
                .listRowBackground(Color(.systemBackground))
            }

            // Sign out
            Section {
                Button(role: .destructive) {
                    Task { await authVM.signOut() }
                } label: {
                    HStack {
                        Spacer()
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        Spacer()
                    }
                }
            }
        }
        .ptBackground()
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { populateFields() }
        .onChange(of: authVM.profile) { populateFields() }
    }

    // MARK: - Helpers

    private func populateFields() {
        fullName = authVM.profile?.fullName ?? ""
        username = authVM.profile?.username ?? ""
    }

    private func save() async {
        isSaving = true
        await authVM.saveProfile(fullName: fullName, username: username)
        isSaving = false
        if authVM.errorMessage == nil {
            savedConfirmation = true
            try? await Task.sleep(for: .seconds(2))
            savedConfirmation = false
        }
    }
}
