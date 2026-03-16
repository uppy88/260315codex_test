# VisionMagicHands (visionOS)

Vision Pro 向けに、ハンドトラッキングで「手を開く」ジェスチャーを検知し、
- **右手**: 雪の結晶風のキラキラ
- **左手**: 流れ星風のキラキラ

を手元から放出するサンプル実装です。

## ファイル構成

- `VisionMagicHands/VisionMagicHandsApp.swift`: アプリエントリポイント
- `VisionMagicHands/ContentView.swift`: RealityView とハンドトラッキング制御

## 実装のポイント

1. `ARKitSession` + `HandTrackingProvider` で手のアンカーを購読
2. 手首〜指先までの平均距離から「手が開いているか」を判定
3. 右手は `snowflake` スタイル、左手は `shootingStar` スタイルの `ParticleEmitter` を有効化
4. エミッタの座標を人差し指先端に追従させ、魔法のような軌跡を加える

## Xcode での設定

- ターゲット: visionOS App
- Capability: Hand Tracking（必要に応じて）
- 実機 (Apple Vision Pro) で動作確認推奨

## 注意

このリポジトリは最小構成のサンプルコードです。Xcode プロジェクト (`.xcodeproj`) は含めていないため、
新規 visionOS App プロジェクトに本ファイルを追加して利用してください。
