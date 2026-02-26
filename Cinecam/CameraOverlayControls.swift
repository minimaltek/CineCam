//
//  CameraOverlayControls.swift
//  Cinecam
//
//  カメラプレビュー上に表示されるオーバーレイコントロール
//

import SwiftUI
import AVFoundation

struct CameraOverlayControls: View {
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var sessionManager: CameraSessionManager
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    // デバイスの向きを検出
    private var isLandscape: Bool {
        horizontalSizeClass == .regular || 
        (horizontalSizeClass == .compact && verticalSizeClass == .compact)
    }
    
    var body: some View {
        GeometryReader { geometry in
            if isLandscape {
                landscapeLayout
            } else {
                portraitLayout
            }
        }
    }
    
    // MARK: - 縦向きレイアウト
    
    private var portraitLayout: some View {
        ZStack {
            VStack {
                // 上部コントロール
                topControlsPortrait
                    .padding(.top, 50)
                    .padding(.horizontal, 20)
                
                Spacer()
                
                // 右側コントロール
                HStack {
                    Spacer()
                    rightSideControls
                        .padding(.trailing, 20)
                }
                
                // 下部コントロール
                bottomControlsPortrait
                    .padding(.bottom, 40)
                    .padding(.horizontal, 20)
            }
            
            // 右上: インカメ切替ボタン
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        CameraHelper.toggleFrontBackCamera(
                            currentCamera: cameraManager.currentCamera,
                            cameraManager: cameraManager
                        )
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 50)
                }
                Spacer()
            }
            
            // 録画中の経過時間を画面中央に表示
            if cameraManager.isRecording {
                centerRecordingTimer
            }
        }
    }
    
    // MARK: - 横向きレイアウト
    
    private var landscapeLayout: some View {
        ZStack {
            HStack(spacing: 0) {
                // 左側コントロール
                VStack {
                    topControlsLandscape
                        .padding(.leading, 20)
                        .padding(.top, 20)
                    Spacer()
                }
                
                Spacer()
                
                // 右側コントロール（縦並び）
                VStack(spacing: 20) {
                    Spacer()
                    rightSideControls
                    Spacer()
                }
                .padding(.trailing, 20)
                .padding(.vertical, 20)
            }
            
            // 録画ボタンを下部中央に配置
            VStack {
                Spacer()
                recordButton
                    .padding(.bottom, 30)
            }
            
            // 右上: インカメ切替ボタン
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        CameraHelper.toggleFrontBackCamera(
                            currentCamera: cameraManager.currentCamera,
                            cameraManager: cameraManager
                        )
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                }
                Spacer()
            }
            
            // 録画中の経過時間を画面中央に表示
            if cameraManager.isRecording {
                centerRecordingTimer
            }
        }
    }
    
    // MARK: - 上部コントロール（縦向き）
    
    private var topControlsPortrait: some View {
        HStack {
            // 閉じるボタン（左上）
            Button(action: {
                sessionManager.stopCameraAndReturnToMenu()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            
            // フラッシュ/トーチボタン
            controlButton(
                icon: cameraManager.torchMode == .off ? "bolt.slash.fill" : "bolt.fill",
                isActive: cameraManager.torchMode != .off
            ) {
                cameraManager.toggleTorch()
            }
            
            // 露出補正表示
            if cameraManager.exposureMode == .locked {
                Text(String(format: "%+.1f", cameraManager.exposureBias))
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
            }
            
            Spacer()
            
            // タイマー表示
            if cameraManager.isRecording {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text(formatDuration(cameraManager.recordingDuration))
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.6))
                .cornerRadius(20)
            }
            
            Spacer()
            
            // 解像度・フレームレート表示
            VStack(alignment: .trailing, spacing: 2) {
                Text(resolutionText)
                    .font(.caption2)
                    .fontWeight(.semibold)
                Text("\(cameraManager.frameRate)")
                    .font(.caption2)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.6))
            .cornerRadius(8)
        }
    }
    
    // MARK: - 上部コントロール（横向き）
    
    private var topControlsLandscape: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 閉じるボタン
            Button(action: {
                sessionManager.stopCameraAndReturnToMenu()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            
            // 解像度・フレームレート
            HStack(spacing: 4) {
                Text(resolutionText)
                    .font(.caption2)
                    .fontWeight(.semibold)
                Text("・")
                Text("\(cameraManager.frameRate)")
                    .font(.caption2)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.6))
            .cornerRadius(8)
            
            // タイマー
            if cameraManager.isRecording {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text(formatDuration(cameraManager.recordingDuration))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.6))
                .cornerRadius(20)
            }
            
            // フラッシュ
            controlButton(
                icon: cameraManager.torchMode == .off ? "bolt.slash.fill" : "bolt.fill",
                isActive: cameraManager.torchMode != .off
            ) {
                cameraManager.toggleTorch()
            }
            
            // 露出補正
            if cameraManager.exposureMode == .locked {
                Text(String(format: "%+.1f", cameraManager.exposureBias))
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
            }
        }
    }
    
    // MARK: - 右側コントロール
    
    private var rightSideControls: some View {
        VStack(spacing: 16) {
            // カメラ切り替えボタン
            if availableCameras.count > 1 {
                cameraSelectionControl
            }
            
            // フォーカスロック
            controlButton(
                icon: cameraManager.focusMode == .locked ? "scope" : "scope",
                isActive: cameraManager.focusMode == .locked
            ) {
                if cameraManager.focusMode == .locked {
                    cameraManager.focusMode = .continuousAutoFocus
                } else {
                    cameraManager.focusMode = .locked
                }
            }
            
            // 露出ロック
            controlButton(
                icon: cameraManager.exposureMode == .locked ? "sun.max.fill" : "sun.max",
                isActive: cameraManager.exposureMode == .locked
            ) {
                if cameraManager.exposureMode == .locked {
                    cameraManager.exposureMode = .continuousAutoExposure
                } else {
                    cameraManager.exposureMode = .locked
                }
            }
        }
    }
    
    // MARK: - カメラ選択コントロール
    
    private var cameraSelectionControl: some View {
        VStack(spacing: 8) {
            ForEach(availableCameras, id: \.uniqueID) { camera in
                let isSelected = cameraManager.currentCamera?.uniqueID == camera.uniqueID
                
                Button(action: {
                    cameraManager.switchCamera(to: camera)
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 44, height: 44)
                        
                        if isSelected {
                            Circle()
                                .stroke(Color.yellow, lineWidth: 2)
                                .frame(width: 44, height: 44)
                        }
                        
                        Text(cameraZoomLabel(for: camera.deviceType))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isSelected ? .yellow : .white)
                    }
                }
            }
        }
    }
    
    // MARK: - 中央録画タイマー
    
    private var centerRecordingTimer: some View {
        VStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                
                Text(formatDuration(cameraManager.recordingDuration))
                    .font(.system(size: 48, weight: .ultraLight, design: .monospaced))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.black.opacity(0.5))
            )
        }
    }
    
    // MARK: - 下部コントロール（縦向き）
    
    private var bottomControlsPortrait: some View {
        HStack(spacing: 40) {
            // 左側のスペーサー（バランス調整用）
            Color.clear
                .frame(width: 50, height: 50)
            
            // 録画ボタン（中央）
            recordButton
            
            // 右側のスペーサー（バランス調整用）
            Color.clear
                .frame(width: 50, height: 50)
        }
    }
    
    // MARK: - 録画ボタン
    
    private var recordButton: some View {
        Button(action: {
            if sessionManager.isMaster {
                if cameraManager.isRecording {
                    sessionManager.stopRecordingAll()
                } else {
                    sessionManager.startRecordingAll()
                }
            }
        }) {
            ZStack {
                // 外側の円
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 70, height: 70)
                
                // 内側の円/四角
                if cameraManager.isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.red)
                        .frame(width: 28, height: 28)
                } else {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 60, height: 60)
                }
            }
        }
        .disabled(sessionManager.isWaitingForReady || !sessionManager.isMaster)
        .opacity(sessionManager.isMaster ? 1.0 : 0.5)
    }
    
    // MARK: - ヘルパー関数
    
    private func controlButton(icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 44, height: 44)
                
                if isActive {
                    Circle()
                        .stroke(Color.yellow, lineWidth: 2)
                        .frame(width: 44, height: 44)
                }
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isActive ? .yellow : .white)
            }
        }
    }
    
    private var availableCameras: [AVCaptureDevice] {
        CameraHelper.availableBackCameras()
    }
    
    private func cameraZoomLabel(for deviceType: AVCaptureDevice.DeviceType) -> String {
        CameraHelper.zoomLabel(for: deviceType)
    }
    
    private var resolutionText: String {
        cameraManager.videoResolution.displayName
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        TimeFormatter.formatDuration(duration)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        CameraOverlayControls(
            cameraManager: .previewMock,
            sessionManager: CameraSessionManager()
        )
    }
}
