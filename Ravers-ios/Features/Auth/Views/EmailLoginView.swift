import SwiftUI

struct EmailLoginView: View {

    @Environment(AuthViewModel.self) private var auth

    var body: some View {
        @Bindable var auth = auth

        ZStack {

            // MARK: Background

            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.25, green: 0.02, blue: 0.04),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.red.opacity(0.25),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: 350
            )
            .ignoresSafeArea()

            ScrollView {
              VStack {

                Spacer()

                VStack(alignment: .leading, spacing: 18) {

                    Text(auth.step == .code ? "CHECK YOUR\nEMAIL" : "WHAT'S YOUR\nEMAIL?")
                        .foregroundStyle(.white)
                        .font(.system(size: 46, weight: .black))
                        .lineSpacing(-2)

                    Text(auth.step == .code ? "Enter the six-digit code sent to \(auth.pendingEmail ?? "")." : "We’ll email you a six-digit code to sign in.")
                        .foregroundStyle(.white.opacity(0.8))
                        .font(.system(size: 21))
                        .lineSpacing(5)

                    if auth.step == .code {
                        OTPTextField(otp: $auth.otp)
                            .disabled(auth.isLoading)
                            .onSubmit { Task { await auth.verifyCode() } }
                    } else {
                        emailField(text: $auth.emailAddress)
                            .disabled(auth.isLoading)
                    }

                    if let error = auth.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }

                    loginButton

                    if auth.step == .code {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let seconds = auth.resendSecondsRemaining(at: context.date)
                            Button(seconds > 0 ? "Resend code in \(seconds)s" : "Resend code") {
                                Task { await auth.resendCode() }
                            }
                            .disabled(seconds > 0 || auth.isLoading)
                            .foregroundStyle(.white.opacity(seconds > 0 ? 0.5 : 1))
                        }
                        Button("Change email") { auth.changeEmail() }
                            .disabled(auth.isLoading)
                            .foregroundStyle(.white)
                    }

                    terms
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 60)

                Spacer()
              }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func emailField(text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope")
                .foregroundStyle(.white.opacity(0.6))
            TextField("you@gmail.com", text: text)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .foregroundStyle(.white)
                .accessibilityLabel("Email address")
                .onSubmit { Task { await auth.login() } }
        }
        .padding(.horizontal, 18)
        .frame(height: 65)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.12))
        }
    }

    var loginButton: some View {

        Button {
            Task {
                if auth.step == .code { await auth.verifyCode() }
                else { await auth.login() }
            }
        } label: {

            HStack {
                if auth.isLoading { ProgressView().tint(.white) }
                Text(auth.isLoading ? (auth.isSendingCode ? "SENDING CODE…" : "VERIFYING…") : (auth.step == .code ? "VERIFY & CONTINUE" : "SEND CODE"))
            }
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(
                    LinearGradient(
                        colors: [
                            Color.red,
                            Color(red: 0.65, green: 0.02, blue: 0.05)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .opacity((auth.step == .code ? auth.isCodeValid : auth.isEmailValid) ? 1 : 0.5)
        }
        .disabled(!(auth.step == .code ? auth.isCodeValid : auth.isEmailValid) || auth.isLoading)
        .padding(.top, 15)
    }

    var terms: some View {

        VStack(spacing: 6) {

            Text("By continuing you agree to our")
                .foregroundStyle(.white.opacity(0.65))

            Text("Terms & Privacy Policy.")
                .foregroundColor(.red)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .font(.footnote)
        .padding(.top, 18)
    }
}

#Preview {
    EmailLoginView()
        .environment(AuthViewModel())
}

