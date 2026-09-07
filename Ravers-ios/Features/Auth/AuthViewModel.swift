//
//  AuthViewModel.swift
//  Raverse-ios
//
//  Owns the entire login journey: phone → send OTP → verify → session.
//  Views stay dumb; all auth logic lives here. Uses @Observable (iOS 17+).
//

import SwiftUI

@Observable
final class AuthViewModel {

    enum Step {
        case phone
        case otp
        case signedIn
    }

    var step: Step = .phone
    var phoneNumber = ""
    var otpCode = ""
    var isLoading = false
    var errorMessage: String?

    
    var e164Phone: String { "+91" + phoneNumber }

    // MARK: - Actions (stubbed until Supabase is wired)

    @MainActor
    func sendCode() async {
        isLoading = true
        defer { isLoading = false }
        // TODO: try await SupabaseManager.shared.client.auth
        //          .signInWithOTP(phone: e164Phone)
        step = .otp
    }

    @MainActor
    func verifyCode() async {
        isLoading = true
        defer { isLoading = false }
        // TODO: try await SupabaseManager.shared.client.auth
        //
        step = .signedIn
    }

    @MainActor
    func signOut() async {
       
        step = .phone
    }
}
