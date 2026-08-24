import SwiftUI

struct ProfileView: View {
    @Environment(AuthViewModel.self) private var authVM

    @State private var fullName = ""
    @State private var username = ""
    @State private var isSaving = false
    @State private var savedConfirmation = false

    var body: some View {
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
