import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @Environment(\.appTheme) private var theme
    @StateObject private var viewModel = AuthViewModel()
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var coordinator: Coordinator
    let postSignInTab: AppTab

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(theme.primary)
                    Text(viewModel.mode == .signIn ? "Welcome back" : "Create your account")
                        .font(theme.title2Font)
                        .foregroundStyle(theme.textPrimary)
                    Text("Sign in to sync your garden across devices.")
                        .font(theme.subheadFont)
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)

                VStack(spacing: 14) {
                    TextField("Email", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(theme.surfaceSunken)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))

                    SecureField("Password", text: $viewModel.password)
                        .textContentType(viewModel.mode == .signIn ? .password : .newPassword)
                        .padding(12)
                        .background(theme.surfaceSunken)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(theme.footnoteFont)
                            .foregroundStyle(theme.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task {
                            await viewModel.submit()
                            if appState.isSignedIn { applyIntent() }
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView().tint(theme.onPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        } else {
                            Text(viewModel.mode == .signIn ? "Sign In" : "Sign Up")
                                .font(theme.headlineFont)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary)
                    .foregroundStyle(theme.onPrimary)
                    .clipShape(Capsule())
                    .disabled(viewModel.isLoading)

                    Button {
                        viewModel.mode = viewModel.mode == .signIn ? .signUp : .signIn
                        viewModel.errorMessage = nil
                    } label: {
                        Text(viewModel.mode == .signIn ? "No account? Sign up" : "Already have an account? Sign in")
                            .font(theme.subheadFont)
                            .foregroundStyle(theme.primary)
                    }
                }

                HStack {
                    Rectangle().fill(theme.separator).frame(height: 1)
                    Text("or").font(theme.footnoteFont).foregroundStyle(theme.textTertiary)
                    Rectangle().fill(theme.separator).frame(height: 1)
                }

                SignInWithAppleButton(.continue, onRequest: { request in
                    request.requestedScopes = [.email, .fullName]
                }, onCompletion: { result in
                    Task {
                        await viewModel.handleAppleCompletion(result)
                        if appState.isSignedIn { applyIntent() }
                    }
                })
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .clipShape(Capsule())
            }
            .padding(24)
        }
        .background(theme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func applyIntent() {
        coordinator.selectedTab = postSignInTab
        if postSignInTab == .scan {
            coordinator.scanPresetIntent = ScanIntent(mode: .identify, plantId: nil)
        }
    }
}

#Preview {
    ThemeProvider {
        NavigationStack { AuthView(postSignInTab: .garden) }
    }
    .environmentObject(AppState())
    .environmentObject(Coordinator())
}
