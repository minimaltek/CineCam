//
//  DancingLoaderView.swift
//  Cinecam
//
//  SwiftUI 棒人形ランニングアニメーション ローディング表示

import SwiftUI

struct DancingLoaderView: View {
    var size: CGFloat = 80
    var tint: Color = .white

    @State private var t: CGFloat = 0
    private let interval: Double = 1.0 / 30.0  // 30fps

    var body: some View {
        let displaySize = size * 0.5
        RunningFigureCanvas(t: t, tint: tint)
            .frame(width: displaySize, height: displaySize)
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                    t += CGFloat(interval) * 5.0  // 走りの速度
                }
            }
    }
}

// MARK: - Running Figure (continuous sin-wave animation)

private struct RunningFigureCanvas: View {
    let t: CGFloat   // 連続時間
    let tint: Color

    var body: some View {
        Canvas { context, sz in
            let w = sz.width
            let h = sz.height

            // --- 走りサイクル (sin波で滑らか) ---
            let cycle = t  // ラジアン、連続的に増加

            // 体の上下バウンス（着地で下、空中で上）— 1歩で2回バウンス
            let bounce = sin(cycle * 2) * h * 0.025

            // 体の前傾角度 ~20度 + 走りに合わせてわずかに揺れ
            let lean: CGFloat = 0.35 + sin(cycle * 2) * 0.03

            // --- 体幹 ---
            let hipX = w * 0.44
            let hipY = h * 0.48 + bounce
            let hip = CGPoint(x: hipX, y: hipY)

            let spineLen = h * 0.26
            let neck = CGPoint(
                x: hip.x + sin(lean) * spineLen,
                y: hip.y - cos(lean) * spineLen + bounce * 0.3
            )

            let headR = w * 0.09
            let headCenter = CGPoint(
                x: neck.x + sin(lean) * headR * 1.1,
                y: neck.y - cos(lean) * headR * 1.05 + bounce * 0.15
            )

            // 寸法
            let upperArm = w * 0.22
            let forearm  = w * 0.20
            let thigh    = h * 0.25
            let shin     = h * 0.25

            let lineW = w * 0.045
            let style = StrokeStyle(lineWidth: lineW, lineCap: .round, lineJoin: .round)

            // --- 脚の角度（sin波で前後に振る）---
            // 右脚が前のとき左脚は後ろ（位相180度ずれ）
            let legSwing: CGFloat = 0.75  // 振り幅（ラジアン）
            let legBase: CGFloat = CGFloat.pi / 2 + lean * 0.3  // 基準角度（やや前傾方向）

            let rLegPhase = sin(cycle)          // -1 ~ 1
            let lLegPhase = sin(cycle + .pi)    // 反対位相

            // 太もも角度
            let rThighAngle = legBase + rLegPhase * legSwing
            let lThighAngle = legBase + lLegPhase * legSwing

            // 膝の曲がり — 脚が後ろに行くほど膝が曲がる（蹴り上げ）、前に来るとほぼ伸びる
            let rKneeBend = max(0, -rLegPhase) * 1.2 + 0.15  // 後ろ脚のとき大きく曲がる
            let lKneeBend = max(0, -lLegPhase) * 1.2 + 0.15

            let rKneeAngle = rThighAngle + rKneeBend
            let lKneeAngle = lThighAngle + lKneeBend

            // --- 腕の角度（脚と反対に振る）---
            let armSwing: CGFloat = 0.65
            let armBase: CGFloat = CGFloat.pi / 2 + lean * 0.5

            let rArmPhase = sin(cycle + .pi)  // 右腕は右脚と反対
            let lArmPhase = sin(cycle)        // 左腕は左脚と反対

            let rShoulderAngle = armBase + rArmPhase * armSwing
            let lShoulderAngle = armBase + lArmPhase * armSwing

            // 肘 — 腕が後ろに行くと肘を曲げる
            let rElbowBend = max(0, -rArmPhase) * 0.9 + 0.3
            let lElbowBend = max(0, -lArmPhase) * 0.9 + 0.3

            let rElbowAngle = rShoulderAngle - rElbowBend
            let lElbowAngle = lShoulderAngle - lElbowBend

            // === 描画 ===

            // 頭（塗りつぶし）
            let headRect = CGRect(x: headCenter.x - headR, y: headCenter.y - headR,
                                  width: headR * 2, height: headR * 2)
            context.fill(Path(ellipseIn: headRect), with: .color(tint))

            // 背骨
            var spinePath = Path()
            spinePath.move(to: neck)
            spinePath.addLine(to: hip)
            context.stroke(spinePath, with: .color(tint), style: style)

            // 左腕
            let lElbowPt = CGPoint(x: neck.x + cos(lShoulderAngle) * upperArm,
                                   y: neck.y + sin(lShoulderAngle) * upperArm)
            let lHandPt  = CGPoint(x: lElbowPt.x + cos(lElbowAngle) * forearm,
                                   y: lElbowPt.y + sin(lElbowAngle) * forearm)
            var lArm = Path(); lArm.move(to: neck); lArm.addLine(to: lElbowPt); lArm.addLine(to: lHandPt)
            context.stroke(lArm, with: .color(tint), style: style)

            // 右腕
            let rElbowPt = CGPoint(x: neck.x + cos(rShoulderAngle) * upperArm,
                                   y: neck.y + sin(rShoulderAngle) * upperArm)
            let rHandPt  = CGPoint(x: rElbowPt.x + cos(rElbowAngle) * forearm,
                                   y: rElbowPt.y + sin(rElbowAngle) * forearm)
            var rArm = Path(); rArm.move(to: neck); rArm.addLine(to: rElbowPt); rArm.addLine(to: rHandPt)
            context.stroke(rArm, with: .color(tint), style: style)

            // 左脚
            let lKneePt = CGPoint(x: hip.x + cos(lThighAngle) * thigh,
                                  y: hip.y + sin(lThighAngle) * thigh)
            let lFootPt = CGPoint(x: lKneePt.x + cos(lKneeAngle) * shin,
                                  y: lKneePt.y + sin(lKneeAngle) * shin)
            var lLeg = Path(); lLeg.move(to: hip); lLeg.addLine(to: lKneePt); lLeg.addLine(to: lFootPt)
            context.stroke(lLeg, with: .color(tint), style: style)

            // 右脚
            let rKneePt = CGPoint(x: hip.x + cos(rThighAngle) * thigh,
                                  y: hip.y + sin(rThighAngle) * thigh)
            let rFootPt = CGPoint(x: rKneePt.x + cos(rKneeAngle) * shin,
                                  y: rKneePt.y + sin(rKneeAngle) * shin)
            var rLeg = Path(); rLeg.move(to: hip); rLeg.addLine(to: rKneePt); rLeg.addLine(to: rFootPt)
            context.stroke(rLeg, with: .color(tint), style: style)
        }
    }
}
