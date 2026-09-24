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
                .font(.system(size: 52, weight: .light))
                .foregroundColor(.ptAccent)
                .frame(width: 110, height: 110)
                .glassEffect(.regular.tint(.ptAccentSoft.opacity(0.5)), in: .circle)
                .symbolEffect(.wiggle, options: .repeat(.periodic(delay: 4)))
                .ptEntrance()
            VStack(spacing: 8) {
                Text("You're browsing as a guest")
                    .font(.ptSerif(.title3, weight: .semibold))
                Text("Create a free account to save your routines, track progress, and sync across devices.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .ptEntrance(index: 1)
            VStack(spacing: 12) {
                NavigationLink {
                    AuthView()
                } label: {
                    Text("Create Account")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .ptPrimaryButton()
                .padding(.horizontal, 32)

                Button {
                    Task { await authVM.signOut() }
                } label: {
                    Text("Exit Guest Mode")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .ptEntrance(index: 2)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { PTAmbientBackground().ignoresSafeArea() }
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
                PTSectionHeader("Account")
            }
            .ptGlassRow()

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
                PTSectionHeader("Profile")
            } footer: {
                if savedConfirmation {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.ptSecondary)
                        .symbolEffect(.bounce, options: .nonRepeating)
                        .transition(.blurReplace)
                }
            }
            .ptGlassRow()

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
                .foregroundColor(isSaving ? .secondary : .ptAccent)
                .disabled(isSaving)
            }
            .ptGlassRow()

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
            .ptGlassRow()
        }
        .listRowSpacing(8)
        .animation(PTMotion.snappy, value: savedConfirmation)
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
