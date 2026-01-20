//
//  GradientView.swift
//  clipboard
//
//  Created on 2026/1/8.
//

import SwiftUI

struct GradientView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 线性渐变
                VStack(alignment: .leading, spacing: 8) {
                    Text("线性渐变 (Linear Gradient)")
                        .font(.headline)

                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient.fromHex(
                            ["#FF6B6B", "#4ECDC4", "#45B7D1"],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(height: 80)

                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient.fromHex(
                            ["#00c6fb", "#005bea"],
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        ))
                        .frame(height: 80)
                }

                // 径向渐变
                VStack(alignment: .leading, spacing: 8) {
                    Text("径向渐变 (Radial Gradient)")
                        .font(.headline)

                    RoundedRectangle(cornerRadius: 12)
                        .fill(RadialGradient.fromHex(
                            ["#f093fb", "#f5576c"],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        ))
                        .frame(height: 120)
                }

                // 角度渐变
                VStack(alignment: .leading, spacing: 8) {
                    Text("角度渐变 (Angular Gradient)")
                        .font(.headline)

                    Circle()
                        .fill(AngularGradient.fromHex(
                            ["#FF0080", "#FF8C00", "#40E0D0", "#FF0080"],
                            center: .center
                        ))
                        .frame(width: 120, height: 120)
                }

                // 带停止点的渐变
                VStack(alignment: .leading, spacing: 8) {
                    Text("带停止点的渐变 (Gradient with Stops)")
                        .font(.headline)

                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient.fromHex(
                            stops: [
                                (hex: "#FA8BFF", location: 0.0),
                                (hex: "#2BD2FF", location: 0.5),
                                (hex: "#2BFF88", location: 1.0),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(height: 100)
                }

                // 单色
                VStack(alignment: .leading, spacing: 8) {
                    Text("单色 (Single Color)")
                        .font(.headline)

                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: "#FF6B6B"))
                            .frame(width: 50, height: 50)

                        Circle()
                            .fill(Color(hex: "#4ECDC4"))
                            .frame(width: 50, height: 50)

                        Circle()
                            .fill(Color(hex: "#45B7D1"))
                            .frame(width: 50, height: 50)

                        Circle()
                            .fill(Color(hex: "#96CEB4"))
                            .frame(width: 50, height: 50)
                    }
                }
            }
            .padding()
        }
        .frame(width: 400, height: 600)
    }
}

#Preview {
    GradientView()
}
