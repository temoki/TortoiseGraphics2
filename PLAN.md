# TortoiseGraphics リニューアル計画書

作成日: 2026-07-11 / 対象: [temoki/TortoiseGraphics](https://github.com/temoki/TortoiseGraphics)

## 1. 目的

2020年から更新が止まっている TortoiseGraphics(Swift製タートルグラフィックスエンジン)を、新規リポジトリでゼロから作り直す。目標は次の4点。

1. 最新プラットフォームへの刷新(Swift 6.x / SwiftUI / SwiftPM)
2. プラットフォーム拡大: iOS / iPadOS / macOS / visionOS
3. ScratchライクなブロックベースUIを持つアプリの提供
4. 描画結果のSVG出力

## 2. 現行版の課題(要点)

| 領域 | 現状 | 問題 |
|---|---|---|
| 配布 | Carthage / CocoaPods | 両者とも衰退。SwiftPM未対応 |
| ビルド | xcworkspace + xcconfig + 同梱バイナリframework | 現行Xcodeで保守困難。PlaygroundSupport同梱は非推奨 |
| 言語 | Swift 5.1 / iOS 13 | Swift 6 strict concurrency 非対応 |
| 描画 | CoreGraphics + CALayer + delegateパターン | 可変状態共有が多くconcurrency化しにくい。iOS専用 |
| iPad対応 | PlaygroundBook + LiveViewプロセス間メッセージング | 複雑。現在はSwift Playgrounds Appプロジェクト(.swiftpm)で代替可能 |
| テスト | 空のテンプレートのみ | 実質ゼロ |

## 3. リニューアル方針

新規リポジトリで作り直し、旧リポジトリはREADMEに移行案内を書いてアーカイブする。プロダクトは2層構成とする。

- **TortoiseGraphics(ライブラリ / SwiftPMパッケージ)** — タートルエンジン+SwiftUI描画ビュー+SVG出力。コードでも使えるOSSライブラリとして継続
- **ブロックエディタアプリ(仮称: TortoiseBlocks)** — ライブラリを使うScratchライクなアプリ。iPad中心にiPhone / Mac / Vision Proへ展開。将来的にApp Store配布も視野

### ターゲット環境

Swift 6.x(strict concurrency有効)、Xcode 26以降、iOS / iPadOS / macOS / visionOS 26以降(2026年秋のOS 27リリースを見据え、deployment targetは26で開始)。

## 4. アーキテクチャ設計

### 4.1 コア設計の転換: delegate通知 → コマンドストリーム

旧版はTortoiseの状態変化をdelegateでCanvasに通知し、Canvas側が即時描画していた。新版では**イベントソーシング型**に転換する。

```
Tortoise API 呼び出し
      │ 生成
      ▼
[TurtleCommand] の列(Sendableな値型: forward, rotate, penChangeなど)
      │                    │                    │
      ▼                    ▼                    ▼
SwiftUI Canvas描画     SVGレンダラ         ImageRenderer(PNG等)
(アニメーション再生)   (パス構築)          (静止画出力)
```

利点: 描画・アニメーション・SVG出力・テストがすべて同一のコマンド列を入力とする純粋関数になる。Sendableな値型の列なのでSwift 6のstrict concurrencyと自然に整合し、スナップショットテストも容易。

### 4.2 モジュール構成(SwiftPMパッケージ)

| モジュール | 内容 | 依存 |
|---|---|---|
| `TortoiseCore` | Tortoise API(旧APIほぼ互換+Pythonエイリアス)、TurtleCommand、Color / Vec2D / Angle等の値型、コマンド再生ロジック | Foundationのみ(プラットフォーム非依存) |
| `TortoiseUI` | `TortoiseCanvasView`(SwiftUI)。TimelineView / Canvasベースでコマンド列をアニメーション再生。速度制御・ステップ実行対応 | TortoiseCore, SwiftUI |
| `TortoiseSVG` | コマンド列→SVG文字列/ファイル生成 | TortoiseCore |

アプリ(TortoiseBlocks)は別リポジトリまたは同リポジトリ内のappディレクトリで、上記3モジュールに依存する。

### 4.3 ブロックエディタアプリ(TortoiseBlocks)

- **ブロックモデル**: ブロック=TurtleCommandへ変換可能な値型。制御ブロック(くりかえし・もし)は子ブロック列を持つ木構造。Codable(JSON)で保存
- **UI**: SwiftUIのドラッグ&ドロップでパレット→ワークスペースへ配置。実行ボタンでブロック木→コマンド列に展開し、TortoiseCanvasViewでアニメーション再生。ステップ実行・速度スライダー付き
- **対象ブロック(初期セット)**: 移動系(まえへ・うしろへ・みぎ・ひだり・ホーム)、ペン系(ペンを上げる/下ろす・色・太さ)、塗り系(塗りはじめ/おわり)、制御系(◯回くりかえす)、乱数
- **教育向け配慮**: 日本語/英語ローカライズ、生成されるSwiftコードの表示(ブロック→コードの学習導線)
- **共有**: 作品をSVG / PNGで書き出し(ライブラリのSVG機能をそのまま利用)

### 4.4 SVG出力

コマンド列を走査してSVG `<path>` / `<polygon>` を構築する純粋関数として実装。ペン色・太さ・塗り(beginFill/endFill)・背景色に対応。座標系は中心原点→SVG座標へ変換。アニメーションなしの静的SVGを第一目標とし、SMILやCSSアニメーション付きSVGは将来課題。

### 4.5 visionOS

第一段階はウィンドウ(2D)アプリとしてそのまま動作させる(SwiftUIベースなら追加コストほぼゼロ)。第二段階として、RealityKitでタートルを3D空間に置き、描画結果を空間内のボードに表示する「空間タートル」を実験的機能として検討。

## 5. 旧設計からの変更点

コードレビューで見つかった設計課題と、新版での方針。

### 5.1 グローバル可変状態の廃止

旧版は `Angle.currentUnit`(degrees/radians切替)と `Color.currentMode`(0-255/0-1切替)が `static var` のグローバル状態で、全タートル・全キャンバスに影響し呼び出し順で挙動が変わる。Swift 6 strict concurrencyではコンパイルエラーになる。

新版: グローバル関数 `degrees()` / `radians()` / `colorMode()` を廃止し、角度単位はタートルごとの設定または型で表現(例: `Angle.degrees(90)`)。色は0-1の `Double` + alpha に統一する。

### 5.2 実バグの教訓 → テスト必須化

旧版にはテスト不在に起因する実バグが残っている。

- `Vec2D` の内積演算子: `lhs.x * rhs.x + lhs.y + rhs.y`(`lhs.y * rhs.y` の誤り)
- `fillColor(_ hex:)` がペン色(`state.pen.color`)を書き換えている(コピペミス)
- `towards()` が `atan2` でなく `atan` を使用 → 象限が不正、x座標が同一だとゼロ除算
- `backword` のスペルミスがpublic APIに残存

新版: TortoiseCoreの全public APIにswift-testingでユニットテストを書くことをフェーズ1の完了条件とする。

### 5.3 APIのSwift化

旧版は `penColor(_:)` 関数と `penColor` プロパティの同名並立などPython turtle直訳のAPI。新版は `var penColor: Color { get set }` のようにSwiftらしい形を基本とし、Python風の関数形(`fd()`, `pd()` 等)はエイリアスレイヤーとして分離して提供する。

### 5.4 Colorの刷新

独自RGB(アルファなし)+colorModeを廃止し、0-1 `Double` + alpha に統一。`SwiftUI.Color` との相互変換を標準装備する。

### 5.5 円弧の一級サポート

旧版の `circle()` は内部で `right` + `forward` を繰り返す多角形近似。新版ではコマンドストリームに「円弧コマンド」を設け、描画時は真の円弧、SVG出力時は `A`(arc)パスで出力する。

### 5.6 その他の近代化

`random()` は `arc4random_uniform` から `Double.random(in:)` へ。`Int.timesRepeat` は教育用APIとして維持しつつ、標準の `for` ループへの導線をドキュメントに明記する。

## 6. ロードマップ

| フェーズ | 内容 | 完了条件 |
|---|---|---|
| **0. 準備** | 新規リポジトリ作成、SwiftPMパッケージ雛形、GitHub Actions CI(ビルド+テスト+SwiftLint or swift-format)、DocC雛形 | CIが全プラットフォームでグリーン |
| **1. コアエンジン** | TortoiseCore実装(旧API移植+コマンドストリーム化)、swift-testingでユニットテスト | 旧READMEの全コマンドが動作しテスト済み |
| **2. SwiftUI描画** | TortoiseUI実装、アニメーション再生、iOS/iPadOS/macOS/visionOSサンプルアプリ | 旧版のTurtle Starデモが4プラットフォームで動く |
| **3. SVG出力** | TortoiseSVG実装、スナップショットテスト | 代表作例のSVGがブラウザで正しく表示される |
| **4. v2.0.0公開** | DocC整備、README刷新、旧リポジトリに移行案内、SwiftPMでタグ公開 | v2.0.0リリース |
| **5. ブロックエディタ** | TortoiseBlocksアプリ(ブロックモデル→エディタUI→実行→保存/書き出し) | iPadで一連の作成・実行・SVG書き出しが完結 |
| **6. 発展** | App Store配布、visionOS空間タートル、コマンド拡充(複数タートル、テキスト描画等) | 随時 |

フェーズ1〜3はライブラリとして独立価値があるため先行リリースし、アプリ(フェーズ5)はその上に構築する。

## 7. 技術選定メモ

- **テスト**: swift-testing(Xcode 26標準)。描画系はコマンド列のスナップショット+SVG文字列比較で、GUI不要のCIテストにする
- **Lint/Format**: swift-format(Apple公式)に移行し、同梱バイナリのSwiftLintを廃止
- **ドキュメント**: DocC + GitHub Pages(旧docs/の購読フィードは廃止)
- **Swift Playgrounds対応**: 旧PlaygroundBook形式は廃止。必要ならApp Playgrounds(.swiftpm)形式のサンプルを提供
- **絵文字API**: `let 🐢 = Tortoise()` の書き味は本プロジェクトの個性なので維持する

## 8. 旧リポジトリの扱い

最終リリース(1.0.0-beta.3)のまま新リポジトリへのリンクを添えてアーカイブ。Issue/スターの履歴は残る。CocoaPods podspecは新規公開を停止。
