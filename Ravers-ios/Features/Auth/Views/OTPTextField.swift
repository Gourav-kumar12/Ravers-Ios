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
                .accentColor(.clear)
                .onChange(of: otp) { _, value in

                    // Keep only digits, capped at 6. Guards against paste,
                    // hardware keyboards, and autofill inserting non-numbers.
                    let cleaned = String(value.filter(\.isNumber).prefix(6))
                    if cleaned != otp {
                        otp = cleaned
                    }

                }

            HStack(spacing: 12) {

                ForEach(0..<6, id: \.self) { index in

                    ZStack {

                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                index == min(otp.count, 5)
                                ? Color.red
                                : Color.white.opacity(0.12),
                                lineWidth: 1.5
                            )
                            .frame(width: 52,
                                   height: 68)

                        Text(character(at: index))
                            .font(.title.bold())
                            .foregroundColor(.white)

                    }

                }

            }

        }
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
