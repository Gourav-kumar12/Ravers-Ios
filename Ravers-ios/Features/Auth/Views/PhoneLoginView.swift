//
//  PhoneLoginView.swift
//  Raverse-ios
//
//  Phone number entry → "SEND CODE". (Screen: Auth 2)
//
//  Drives the shared AuthViewModel: the phone field binds to auth.phoneNumber
//  and SEND CODE calls auth.sendCode(), which flips auth.step to .otp. RootView
//  watches that step and swaps in OTPVerifyView — this screen owns no navigation.
//

import SwiftUI

struct PhoneLoginView: View {

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

            VStack {

                // MARK: Top Bar

                HStack {

                    Button {

                    } label: {

                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 46, height: 46)
                            .background(.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(.white.opacity(0.12))
                            }
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                Spacer()

                VStack(alignment: .leading, spacing: 18) {

                    Text("WHAT'S YOUR\nNUMBER?")
                        .foregroundStyle(.white)
                        .font(.system(size: 46, weight: .black))
                        .lineSpacing(-2)

                    Text("We'll text a 6-digit code\nto verify it's you.")
                        .foregroundStyle(.white.opacity(0.8))
                        .font(.system(size: 21))
                        .lineSpacing(5)

                    phoneField(text: $auth.phoneNumber)

                    sendButton

                    terms
                }
                .padding(.horizontal, 28)

                Spacer()
            }
        }
    }

    func phoneField(text: Binding<String>) -> some View {

        HStack(spacing: 0) {

            HStack {

                Text("+91")

                Image(systemName: "chevron.down")
            }
            .foregroundColor(.white)
            .frame(width: 90)

            Divider()
                .background(.white.opacity(0.15))

            TextField(
                "Enter mobile number",
                text: text
            )
            .keyboardType(.numberPad)
            .foregroundColor(.white)
            .padding(.horizontal)
        }
        .frame(height: 65)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.12))
        }
    }

    var sendButton: some View {

        Button {
            Task { await auth.sendCode() }
        } label: {

            Text("SEND CODE")
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
        }
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
    PhoneLoginView()
        .environment(AuthViewModel())
}

