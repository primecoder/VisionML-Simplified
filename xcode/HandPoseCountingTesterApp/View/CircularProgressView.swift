//
//  CircularProgressView.swift
//  HandPoseCountingTesterApp
//
//  Created by Ace on 4/7/2024.
//

import SwiftUI

/// Display progress in circular view.
struct CircularProgressView: View {
    var pct: Double = 0.0
    var readingNumber: String = ""
    var recognisedNumber: String = ""

    @State private var circleOpacity: Double = 0.2
    @State private var numberOpacity: Double = 1.0

    private var progressLabelText: String {
        pct < 100.0 ? readingNumber : recognisedNumber
    }

    private var labelColor: Color {
        pct < 100.0 ? .white.opacity(circleOpacity) : .green.opacity(numberOpacity)
    }

    var body: some View {
        VStack {
            Text("\(progressLabelText)")
                .foregroundStyle(labelColor)
        }
        .font(.system(size: 100))
        .bold()
        .padding()
        .padding(50)
        .overlay {
            Circle()
                .trim(from: 0, to: pct / 100.0)
                .stroke (.white.opacity(circleOpacity), lineWidth: 20)
                .rotationEffect(.degrees(-90))
                .padding()
        }
        .onChange(of: pct) { oldValue, newValue in
            if newValue == 100 {
                withAnimation(.linear(duration: 1)) {
                    circleOpacity = 0.0
                    numberOpacity = 1.0
                }
            } else {
                withAnimation(.linear(duration: 0.5)) {
                    circleOpacity = 0.2
                    numberOpacity = 0.0
                }
            }
        }
    }
}

#Preview {
    CircularProgressView()
}
