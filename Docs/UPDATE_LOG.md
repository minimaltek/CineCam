# Cinecam 更新ログ

---

## 2026-02-25 セッション2

### MultipeerConnectivity 接続安定化
- **招待衝突の解消**: 名前の辞書順で優先度を決定し、片方のみが招待を送信するよう変更
- **fullRestart パターン導入**: MCSession + Advertiser + Browser を完全に再生成するリトライ機構を実装
- **リトライロジック**: 接続失敗時に最大5回、バックオフ付き（1.5s, 3s, 4.5s...）で再接続を試行
- **招待送信遅延**: ピア発見後0.5秒の遅延を設けて安定性を向上

### UI フロー改善
- **プレビュー後の画面遷移**: プレビュー終了後は roleSelectionScreen（MASTER ボタン画面）に戻るよう変更
- **マスターアナウンス時のスレーブ自動遷移**: マスターが次の撮影準備を始めたら、スレーブ側のプレビュー/編集画面を自動で閉じて AWAIT 画面に遷移
- **pendingMasterAnnouncement フラグ**: マスターコマンドによるプレビュー終了時にロールがリセットされない制御を追加
- **スレーブ自動遷移の条件強化**: `masterPeerID` 設定済み AND `connectedPeers` が空でないことを両方チェック
- **MASTER ボタン表示条件**: 接続ピアがいない場合は AWAITING カードを表示、接続ピアがいる場合のみ MASTER ボタンを表示
- **START CAMERA ボタン無効化**: 接続ピアがいない場合はボタンを無効化し「NO NODES CONNECTED」を表示

### iPad レイアウト対応
- `maxContentWidth: 420` を追加し、iPad でもiPhone縦画面と同等の幅で中央配置
- roleSelectionScreen と mainScreen の両方に適用

### デザイン統一
- **CINECAM. ロゴフォント**: `.system(size: 32, weight: .black)` + `.fontWidth(.compressed)` + `.tracking(-0.5)` に変更
- roleSelectionScreen と mainScreen の両ヘッダーで統一

### 変更ファイル
- `ContentView.swift` — UI全画面の変更（レイアウト、フォント、画面遷移ロジック）
- `CameraSessionManager.swift` — 接続ロジック全般（fullRestart、リトライ、招待制御、pendingMasterAnnouncement）

---

## 2026-02-25 セッション1

### リファクタリング
- 共通ユーティリティ作成（CameraUtilities.swift, FrameLayout.swift, DesignConstants.swift）
- コード重複の削除（プレビュー判定、時間フォーマット、カメラ切替ロジック等）
- FrameSetView の改善（Close ボタン修正、ハードコード削除）
- 詳細は `REFACTORING_REPORT.md` を参照

### デザインリニューアル
- roleSelectionScreen を SF/ミリタリー風のダークUIにリデザイン
- 全画面（masterControlView, slaveWaitingView, transferProgressView）のデザインを統一
- ログ表示からemoji を除去、モノクロアイコンに変更
- Canvas Preview サポートを追加
