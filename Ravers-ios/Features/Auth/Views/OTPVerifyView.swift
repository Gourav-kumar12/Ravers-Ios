//
//  OTPVerifyView.swift
//  Raverse-ios
//
//  6-digit code entry. (Screen: Auth 3)
//
//  Reads the shared AuthViewModel: shows the number the user actually typed,
//  binds the boxes to auth.otpCode, and auto-verifies once 6 digits are in —
//  which flips auth.step to .signedIn (RootView then shows the main app).
//  "Edit" sends auth.step back to .phone.
//

import SwiftUI

struct OTPVerifyView: View {

    @Environment(AuthViewModel.self) private var auth

    /// "+91 98765 43210" style display of the number just entered.
    private var displayPhone: String {
        let digits = auth.phoneNumber
        guard digits.count == 10 else { return auth.e164Phone }
        let a = digits.prefix(5)
        let b = digits.suffix(5)
        return "+91 \(a) \(b)"
    }

    var body: some View {
        @Bindable var auth = auth

        ZStack {

            Image("bg-img")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack {

                // MARK: Top Bar

                
               

                Spacer()


                VStack(alignment: .leading, spacing: 18) {

                    Text("ENTER THE CODE\nWE SENT")
                        .font(.system(size: 42, weight: .black))
                        .foregroundColor(.white)
                        .padding(.vertical)

                    Text("We've sent a 6-digit code to")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.title3)

                    HStack(spacing: 8) {

                        Text(displayPhone)
                            .foregroundColor(.red)
                            .fontWeight(.semibold)

                        Button("Edit") {
                            auth.step = .phone
                        }
                        .foregroundColor(.red)
                    }

                    OTPTextField(otp: $auth.otpCode)
                        .disabled(auth.isLoading)
                        .onChange(of: auth.otpCode) { _, code in
                            // Only fire once we have 6 digits and no verify
                            // is already in flight — avoids duplicate calls.
                            if code.count == 6 && !auth.isLoading {
                                Task { await auth.verifyCode() }
                            }
                        }

                    if auth.isLoading {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(.red)
                            Text("Verifying…")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.subheadline)
                        }
                    }

                    if let error = auth.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)

                Spacer()

                HStack(spacing: 6) {

                    Text("Resend code in")
                        .foregroundColor(.white.opacity(0.8))

                    Text("00:24")
                        .foregroundColor(.red)
                }
                .font(.headline)

                Spacer()
            }
        }
    }
}

#Preview {
    OTPVerifyView()
        .environment(AuthViewModel())
}
