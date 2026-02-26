//
//  CinecamExportEngine.swift
//  Cinecam
//
//  ExclusiveEditTimeline の編集結果を AVComposition で1本の動画に書き出す

import Foundation
import Combine
import AVFoundation
import Photos

@MainActor
final class ExportEngine: ObservableObject {

    enum ExportState: Equatable {
        case idle
        case exporting(progress: Float)
        case done(url: URL)
        case failed(message: String)
    }

    @Published var state: ExportState = .idle

    private var exportSession: AVAssetExportSession?

    // MARK: - Public

    /// 書き出し実行 → カメラロールに保存
    func export(timeline: ExclusiveEditTimeline, videos: [String: URL], orientation: VideoOrientation = .landscape) async {
        state = .exporting(progress: 0)

        do {
            let url = try await buildAndExport(timeline: timeline, videos: videos, orientation: orientation)
            // カメラロールに保存（失敗したら .done には絶対到達しない）
            do {
                try await saveToPhotoLibrary(url: url)
            } catch {
                try? FileManager.default.removeItem(at: url)
                state = .failed(message: error.localizedDescription)
                return
            }
            // 保存成功 → 一時ファイルを削除して完了
            try? FileManager.default.removeItem(at: url)
            state = .done(url: url)
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    func cancel() {
        exportSession?.cancelExport()
        state = .idle
    }

    // MARK: - カメラロール保存

    private func saveToPhotoLibrary(url: URL) async throws {
        // 権限確認
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw ExportError.photoLibraryDenied
        }
        // PHPhotosErrorDomain 3302 等が来ることがあるのでここで catch して再スロー
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }
        } catch {
            // 権限エラー (3302) はより分かりやすいメッセージに置き換える
            let nsError = error as NSError
            if nsError.domain == "PHPhotosErrorDomain" && nsError.code == 3302 {
                throw ExportError.photoLibraryDenied
            }
            throw error
        }
    }

    // MARK: - Private

    private func buildAndExport(
        timeline: ExclusiveEditTimeline,
        videos: [String: URL],
        orientation: VideoOrientation = .landscape
    ) async throws -> URL {

        // ① 使用するセグメントを trimIn 順に並べる
        struct EditClip {
            let url: URL
            let sourceIn: CMTime   // 元ファイルの切り出し開始
            let sourceOut: CMTime  // 元ファイルの切り出し終了
            let trimIn: Double     // タイムライン上の開始時刻（ソート用）
        }

        var clips: [EditClip] = []
        for device in timeline.devices {
            guard let url = videos[device] else { continue }
            for seg in timeline.segments(for: device) where seg.isValid {
                clips.append(EditClip(
                    url:       url,
                    sourceIn:  CMTimeMakeWithSeconds(seg.sourceInTime,  preferredTimescale: 600),
                    sourceOut: CMTimeMakeWithSeconds(seg.sourceOutTime, preferredTimescale: 600),
                    trimIn:    seg.trimIn
                ))
            }
        }

        let orderedClips = clips.sorted { $0.trimIn < $1.trimIn }

        guard !orderedClips.isEmpty else {
            throw ExportError.noClips
        }

        // ② AVMutableComposition を組み立てる
        let composition       = AVMutableComposition()
        let videoTrack        = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )!
        let audioTrack        = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )!

        var cursor = CMTime.zero

        for clip in orderedClips {
            let asset      = AVURLAsset(url: clip.url)
            let duration   = clip.sourceOut - clip.sourceIn
            let timeRange  = CMTimeRange(start: clip.sourceIn, duration: duration)
            // 映像トラック
            if let srcVideo = try? await asset.loadTracks(withMediaType: .video).first {
                try videoTrack.insertTimeRange(timeRange, of: srcVideo, at: cursor)
            }
            // 音声トラック（なくてもクラッシュしない）
            if let srcAudio = try? await asset.loadTracks(withMediaType: .audio).first {
                try? audioTrack.insertTimeRange(timeRange, of: srcAudio, at: cursor)
            }

            cursor = cursor + duration
        }

        // ③ 映像の向き・サイズを最初のクリップに合わせる（クロップ設定を含む）
        let videoComposition = try await makeVideoComposition(
            composition: composition,
            firstAsset: AVURLAsset(url: orderedClips[0].url),
            orientation: orientation
        )

        // ④ 書き出し先
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cinecam_export_\(Int(Date().timeIntervalSince1970)).mp4")
        try? FileManager.default.removeItem(at: outputURL)

        // ⑤ AVAssetExportSession で書き出し
        guard let session = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw ExportError.sessionFailed
        }

        session.outputURL          = outputURL
        session.outputFileType     = .mp4
        session.videoComposition   = videoComposition
        session.shouldOptimizeForNetworkUse = true

        self.exportSession = session

        // 進捗を定期的に更新
        let progressTask = Task { [weak self] in
            while !Task.isCancelled {
                await MainActor.run {
                    if case .exporting = self?.state {
                        self?.state = .exporting(progress: session.progress)
                    }
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            }
        }

        await session.export()
        progressTask.cancel()

        switch session.status {
        case .completed:
            return outputURL
        case .cancelled:
            throw ExportError.cancelled
        default:
            throw session.error ?? ExportError.sessionFailed
        }
    }

    // MARK: - VideoComposition（向き補正）

    private func makeVideoComposition(
        composition: AVMutableComposition,
        firstAsset: AVURLAsset,
        orientation: VideoOrientation = .landscape
    ) async throws -> AVMutableVideoComposition {

        guard let firstVideoTrack = try await firstAsset.loadTracks(withMediaType: .video).first
        else { return AVMutableVideoComposition(propertiesOf: composition) }

        let naturalSize = try await firstVideoTrack.load(.naturalSize)
        let transform   = try await firstVideoTrack.load(.preferredTransform)
        let applied     = naturalSize.applying(transform)
        let sourceWidth  = abs(applied.width)
        let sourceHeight = abs(applied.height)
        
        // クロップ判定: 向き設定と実映像のアスペクト比を比較
        let isSourcePortrait = sourceHeight > sourceWidth
        let needsCrop = (orientation == .landscape && isSourcePortrait)
                     || (orientation == .portrait && !isSourcePortrait)
        
        let renderSize: CGSize
        let finalTransform: CGAffineTransform
        
        if needsCrop && orientation == .landscape {
            // 縦映像 → 横向きクロップ（中央の16:9領域を切り出し）
            // 例: 1080x1920 → 1080x607.5 (中央クロップ) → renderSize: 1080x607
            let cropWidth = sourceWidth
            let cropHeight = sourceWidth * (9.0 / 16.0)
            renderSize = CGSize(width: cropWidth, height: cropHeight)
            
            // 上下を中央クロップ: Y方向にオフセット
            let offsetY = (sourceHeight - cropHeight) / 2.0
            let cropTranslate = CGAffineTransform(translationX: 0, y: -offsetY)
            finalTransform = transform.concatenating(cropTranslate)
            
        } else if needsCrop && orientation == .portrait {
            // 横映像 → 縦向きクロップ（中央の9:16領域を切り出し）
            let cropHeight = sourceHeight
            let cropWidth = sourceHeight * (9.0 / 16.0)
            renderSize = CGSize(width: cropWidth, height: cropHeight)
            
            let offsetX = (sourceWidth - cropWidth) / 2.0
            let cropTranslate = CGAffineTransform(translationX: -offsetX, y: 0)
            finalTransform = transform.concatenating(cropTranslate)
            
        } else {
            // クロップ不要（向き設定と映像が一致）
            renderSize = CGSize(width: sourceWidth, height: sourceHeight)
            finalTransform = transform
        }

        let videoComp  = AVMutableVideoComposition()
        videoComp.renderSize  = renderSize
        videoComp.frameDuration = CMTimeMake(value: 1, timescale: 30)

        // 全体を1つのインストラクションで向き補正+クロップを適用
        let compVideoTracks = composition.tracks(withMediaType: .video)
        let totalDuration = composition.duration
        let singleInstr   = AVMutableVideoCompositionInstruction()
        singleInstr.timeRange = CMTimeRange(start: .zero, duration: totalDuration)

        if let compTrack = compVideoTracks.first {
            let layerInstr = AVMutableVideoCompositionLayerInstruction(assetTrack: compTrack)
            layerInstr.setTransform(finalTransform, at: .zero)
            singleInstr.layerInstructions = [layerInstr]
        }

        videoComp.instructions = [singleInstr]
        return videoComp
    }

    // MARK: - Errors

    enum ExportError: LocalizedError {
        case noClips
        case sessionFailed
        case cancelled
        case photoLibraryDenied

        var errorDescription: String? {
            switch self {
            case .noClips:            return "書き出すクリップがありません"
            case .sessionFailed:      return "書き出しセッションの作成に失敗しました"
            case .cancelled:          return "書き出しがキャンセルされました"
            case .photoLibraryDenied: return "カメラロールへのアクセスが許可されていません。設定アプリから許可してください"
            }
        }
    }
}
