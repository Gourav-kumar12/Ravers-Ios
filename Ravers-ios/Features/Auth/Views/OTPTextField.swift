import SwiftUI

struct OTPTextField: View {

    @Binding var otp: String

    @FocusState private var focused: Bool

    var body: some View {

        ZStack {

            TextField("", text: $otp)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .foregroundColor(.clear)
                .tint(.clear)
                .accessibilityLabel("6-digit verification code")
                .accessibilityValue("\(otp.count) of 6 digits entered")
                .onChange(of: otp) { _, value in

                    // Keep only digits, capped at 6. Guards against paste,
                    // hardware keyboards, and autofill inserting non-numbers.
                    let cleaned = String(value.filter { $0.isASCII && $0.isNumber }.prefix(6))
                    if cleaned != otp {
                        otp = cleaned
                    }

                }

            HStack(spacing: 8) {

                ForEach(0..<6, id: \.self) { index in

                    ZStack {

                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                index == min(otp.count, 5)
                                ? Color.red
                                : Color.white.opacity(0.12),
                                lineWidth: 1.5
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)

                        Text(character(at: index))
                            .font(.title.bold())
                            .foregroundColor(.white)

                    }

                }

            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)

        }
        .onAppear { focused = true }
        .contentShape(Rectangle())
        .onTapGesture {

            focused = true

        }

    }

    func character(at index: Int) -> String {

        guard index < otp.count else {

            return ""

        }

        let i = otp.index(otp.startIndex,
                          offsetBy: index)

        return String(otp[i])

    }

}
