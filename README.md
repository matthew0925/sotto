# そっと（Sotto）

帰るまでが、いちばん大事。

「そっと」は、DV・ストーカー・性犯罪・性暴力といった身近な危険から身を守るための、
個人向けセーフティアプリです。アカウント登録不要で、記録と見守りの連絡先は端末内で保護して保存し、
開発者のサーバーには送信しません。

## リポジトリ構成

```
.
├── SafeLineiOS/          iOSアプリ本体（SwiftUI + XcodeGen）
│   ├── SafeLine/          アプリのソースコード
│   ├── SottoWidget/        ホーム画面／ロック画面ウィジェット
│   ├── project.yml         XcodeGen設定（1コマンドで.xcodeprojを生成）
│   └── README.md           iOSアプリのセットアップ手順（まずはここから）
│
├── prototype/
│   └── safeline.html       ブラウザで動く画面遷移プロトタイプ
│
└── docs/
    ├── SafeLine_技術仕様書.md   プロダクトの設計方針・技術仕様
    ├── privacy/                プライバシーポリシー（公開用）
    ├── support/                サポートページ（公開用）
    ├── aso-materials.md        App Store掲載情報（説明文・カテゴリ・審査ノート等）の下書き
    └── aso-screenshots-draft/  スクリーンショットの参考画像（審査提出用の本番素材ではありません）
```

## はじめに読むもの

- **アプリをビルドしたい** → [`SafeLineiOS/README.md`](SafeLineiOS/README.md)
- **画面遷移や文言だけ手早く確認したい** → [`prototype/safeline.html`](prototype/safeline.html) をブラウザで開く
- **プロダクトの設計思想を知りたい** → [`docs/SafeLine_技術仕様書.md`](docs/SafeLine_技術仕様書.md)
- **App Store提出の準備状況を見たい** → [`docs/aso-materials.md`](docs/aso-materials.md)

## 基本方針

- 同意の事前記録・電子署名などの機能は搭載しない（法的効力がないまま誤った安心感を与えるリスクがあるため）
- 緊急時に使う画面（ホームの緊急電話ボタン・見守りチェックイン）は、操作数・情報量を増やさないことを最優先にする
- 位置情報・通知などの権限は、実際に必要になった瞬間にのみ要求する
