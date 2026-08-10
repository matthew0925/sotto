# そっと（Sotto）iOS — セットアップ手順

アプリ名は「そっと」に決定。ホーム画面のアイコン下に表示されても
用途が特定されにくいよう、あえて汎用的な言葉を採用しています。

## 1. Xcodeプロジェクトの作成
1. Xcode →「Create New Project」→「App」
2. Product Name: `Sotto`（英数字のみ推奨。日本語名は次の手順でDisplay Nameとして設定）、
   Interface: SwiftUI、Language: Swift
3. 作成後、`SafeLine/`フォルダの中身（このzipの`SafeLine/`以下）を、
   Xcodeが自動生成した同名フォルダに **上書き** してください
   （`ContentView.swift`と`SafeLineApp.swift`は既存ファイルを置き換える形になります。
   フォルダ名・Swiftの構造体名`SafeLineApp`は内部識別子なので、そのままでも動作に支障はありません）
4. ホーム画面に表示される名前を「そっと」にするには、Target →「General」→
   「Display Name」に `そっと` を入力してください（Bundle Nameとは別設定です）
5. `Resources/resources.json` はXcode上で「Add Files to "SafeLine"...」から追加し、
   Target Membershipにチェックが入っていることを確認してください（Bundleに含める必要があります）

## 2. Info.plist に追加が必要な項目
このMVPは電話発信のみを使用しているため、追加のUsage Description記述は不要です。
今後、位置情報（SOS発火時のみ取得）を実装する場合は以下を追加してください。

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>危険を感じた際に、現在地を信頼できる連絡先へ共有するために使用します。</string>
```

SMS送信（`MFMessageComposeViewController`）はUsage Description不要です
（ユーザーが確認・送信を行うAppleの標準UIを使うため）。

## 3. 通知権限
`AppDelegate`が起動時に通知許可をリクエストします。実機で確認する際は、
設定アプリで「そっと」の通知が許可されているか確認してください。

## 4. このMVPでまだ未実装の部分（次のステップ）
- ジャーナルの暗号化強化：現状はファイル保護（`NSFileProtectionComplete`）のみ。
  本番リリース前に SQLCipher か CryptoKit（AES-GCM）での暗号化、
  および Face ID / パスコードでのロック（`LocalAuthentication`）を追加してください。
- 相談窓口データの定期更新の仕組み（現状はアプリに同梱したJSONのみ・手動更新）
- チェックインのバックグラウンド継続性の実機検証
  （iOSのDoze的な制約はAndroidほど厳しくないが、ローカル通知の到達を実機で必ず確認）
- 位置情報の付与（現状はSMS本文に「現在地の共有はお使いの地図アプリから」という案内のみ）

## 5. 動作確認した設計判断（自己チェックより）
「帰宅チェックイン」に限定せず、SOSボタンはホーム画面に常駐し、
チェックインをセットしていなくても・屋内でも常に押せる位置づけにしています。
これは、被害者支援団体の公開統計（面識者・交際相手・配偶者からの被害が過半数）を踏まえた設計判断です。
「夜道で見知らぬ人に襲われる」ケースだけを想定した機能にしない、という方針は
文言・導線の両方で今後も維持してください。
