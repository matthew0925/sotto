# そっと（Sotto）iOS — セットアップ手順

アプリ名は「そっと」に決定。ホーム画面のアイコン下に表示されても
用途が特定されにくいよう、あえて汎用的な言葉を採用しています。

## 1. Xcodeプロジェクトの作成（XcodeGenを使う方法・推奨）

このリポジトリには`project.yml`（[XcodeGen](https://github.com/yonaskolb/XcodeGen)の設定ファイル）が
含まれています。手動でXcodeプロジェクトを作ってファイルをコピーする必要はなく、
1コマンドで`.xcodeproj`が生成されます。Info.plistの必須キー（位置情報・Face ID）や
Bundle Identifier、Display Nameもこのファイルに定義済みです。

```bash
# 初回のみ（Homebrewが入っていればこの1行）
brew install xcodegen

# SafeLineiOS ディレクトリで実行
cd SafeLineiOS
xcodegen generate

# 生成された Sotto.xcodeproj を開く
open Sotto.xcodeproj
```

`project.yml`には`DEVELOPMENT_TEAM`（Team ID）が設定済みなので、Xcodeを開いた時点で
署名まで自動的に解決されているはずです。実機を接続し、スキームのデバイスを選んで
⌘R でビルド・実行してください。

**⚠️ このリポジトリを他の人がクローンしてビルドする場合（レビュー依頼など）**：
`project.yml`内のBundle Identifier（`bundleIdPrefix`と`PRODUCT_BUNDLE_IDENTIFIER`、
2ターゲット分で計3箇所）とTeam ID（`DEVELOPMENT_TEAM`、2ターゲット分で計2箇所）は
**元の開発者のApple IDに紐づいているため、そのままでは他の人のApple IDでビルドできません**
（"cannot be registered to your development team" / "requires a development team" エラーになります）。
自分でビルドする場合は、この4種類の値をすべて自分のものに書き換えてから
`xcodegen generate`を実行してください（この書き換えはローカルのみで行い、
リポジトリにpushし返す必要はありません）。

`project.yml`を編集した場合は、再度`xcodegen generate`を実行すれば`.xcodeproj`に反映されます。
`.xcodeproj`自体はGit管理していません（`xcodegen generate`で毎回再生成する運用のため）。

`Assets.xcassets`にはAppIcon・AccentColorのプレースホルダーのみ入っています
（実際のアイコン画像は§5参照）。デバッグ実行には支障ありませんが、
App Store提出には実際の1024×1024アイコン画像が必要です。

### 代替：手動でXcodeプロジェクトを作る場合
XcodeGenを使わない場合は、以下の手順でも構築できます。
1. Xcode →「Create New Project」→「App」
2. Product Name: `Sotto`（英数字のみ推奨。日本語名は次の手順でDisplay Nameとして設定）、
   Interface: SwiftUI、Language: Swift
3. 作成後、`SafeLine/`フォルダの中身を、Xcodeが自動生成した同名フォルダに **上書き** してください
   （`ContentView.swift`と`SafeLineApp.swift`は既存ファイルを置き換える形になります。
   フォルダ名・Swiftの構造体名`SafeLineApp`は内部識別子なので、そのままでも動作に支障はありません）
4. ホーム画面に表示される名前を「そっと」にするには、Target →「General」→
   「Display Name」に `そっと` を入力してください（Bundle Nameとは別設定です）
5. `Resources/resources.json` はXcode上で「Add Files to "SafeLine"...」から追加し、
   Target Membershipにチェックが入っていることを確認してください（Bundleに含める必要があります）

## 2. Info.plist に追加が必要な項目
**XcodeGenで生成した場合は`project.yml`に既に定義済みなので、この節の作業は不要です。**
手動でXcodeプロジェクトを作った場合のみ、以下2つのUsage Descriptionを追加してください
（未設定だと該当機能の呼び出しでクラッシュします）。

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>見守りチェックイン中に、現在地を信頼できる連絡先へ共有するために使用します。</string>

<key>NSFaceIDUsageDescription</key>
<string>記録（ジャーナル）を本人以外に見られないよう、Face IDで保護するために使用します。</string>
```

「Always」（常時）位置情報権限は**要求していません**（技術仕様書§7の通り、審査上のリスクが
大きいため）。「When In Use」のみのため、アプリがバックグラウンドに回ってしばらく経つと
位置更新は一時停止し、次にアプリを開いたタイミングで再開します。これは既知の制約です。

SMS送信（`MFMessageComposeViewController`）はUsage Description不要です
（ユーザーが確認・送信を行うAppleの標準UIを使うため）。

## 3. 通知権限
`AppDelegate`が起動時に通知許可をリクエストします。実機で確認する際は、
設定アプリで「そっと」の通知が許可されているか確認してください。
チェックイン通知の「無事です」「連絡先に知らせる」アクションは`AppDelegate`が
直接`CheckInManager`に配線しているため、アプリがバックグラウンドでもタップした
瞬間に処理されます。

## 4. 実装済み（今回追加分）
- **ジャーナルの暗号化**：CryptoKit（AES-GCM）で全エントリを暗号化。鍵はKeychainに
  `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`で保存（端末にパスコード未設定の場合は
  そもそも鍵が作成されない設計）。加えてFace ID / パスコードロック（`LocalAuthentication`）
  をJournalViewの前段に追加し、アプリがバックグラウンドに回るたびに再ロックします。
- **見守り連絡先の永続化**：連絡先番号・メッセージ文をKeychainに保存し、アプリ再起動後も
  引き継がれます。
- **チェックイン中の位置情報リアルタイム更新**：チェックイン開始と同時に`LocationManager`が
  追跡を開始し、約2分間隔（または30m以上の移動）で位置を更新し続けます。タイムアウト通知
  または「今すぐ連絡先に知らせる」ボタンからSMS送信画面を開くと、その時点で取得できている
  最新の位置情報リンクが自動でメッセージ本文に挿入されます。「無事です」を押すと追跡は停止します。
- **データ全削除**：設定タブから記録・見守り連絡先を1タップで削除できます
  （加害者に端末を確認された場合の安全確保を想定）。
- **位置情報の更新間隔をユーザーが選択可能**：設定タブから30秒〜10分の間で選べます
  （短いほど送信時の位置が新しくなりますが、バッテリー消費が増えます）。設定はこの端末に保存され、
  次回以降のチェックインにも引き継がれます。
- **選べるホーム画面アイコン**：`IconManager.swift`が`UIApplication.setAlternateIconName`
  （Appleの正規機能）でアイコンを切り替えます。**電卓等への偽装ではなく**、パステル／モノクロ／
  シンプルなど、周囲のアイコン配列・背景に馴染むデザインを選べるだけの機能です。
  アプリ名の表示（「そっと」）はどのアイコンを選んでも変わりません。

## 5. アイコン画像の追加手順（§4のアイコン選択機能に必要）
このリポジトリにはアイコンの**画像そのもの**は含まれていません（デザインアセットのため）。
`SettingsView`の選択UIとロジックは動作しますが、実際に切り替わる見た目を持たせるには
以下をXcode側で用意してください。

1. Asset Catalogに、各バリエーションごとの画像セットを追加：
   `IconPastel` / `IconMono` / `IconMinimal`（既存のデフォルトは`AppIcon`のまま）
   - iOSの仕様上、アイコンは**アルファチャンネルなしの正方形PNG**（1024×1024推奨）
2. 同じ名前で、設定画面のプレビュー用に小さいサイズの画像セットも追加：
   `IconPastelPreview` / `IconMonoPreview` / `IconMinimalPreview`
   （`AppIconOption.previewAssetName`が参照する名前です。プレビュー画像を用意するまでは
   選択自体は問題なく動きますが、枠内に絵は表示されません）
3. Info.plistに以下を追加し、`CFBundleAlternateIcons`にXcodeが自動生成しない場合は
   手動でキーを追加してください：

```xml
<key>CFBundleIcons</key>
<dict>
    <key>CFBundlePrimaryIcon</key>
    <dict>
        <key>CFBundleIconFiles</key>
        <array><string>AppIcon</string></array>
    </dict>
    <key>CFBundleAlternateIcons</key>
    <dict>
        <key>IconPastel</key>
        <dict>
            <key>CFBundleIconFiles</key>
            <array><string>IconPastel</string></array>
        </dict>
        <key>IconMono</key>
        <dict>
            <key>CFBundleIconFiles</key>
            <array><string>IconMono</string></array>
        </dict>
        <key>IconMinimal</key>
        <dict>
            <key>CFBundleIconFiles</key>
            <array><string>IconMinimal</string></array>
        </dict>
    </dict>
</dict>
```

## 6. 実装済み（第2弾：見た目の見直し＋機能追加）
テキストが読みにくいという指摘を受けて配色・文字サイズを見直し、あわせて要望のあった
7つの機能を追加しました。

- **配色をライト/ダーク両対応に**：`Assets.xcassets`にAny/Dark両方の値を持つカラーセット
  （Ink・TextPrimary/Secondary/Tertiary・CardFill・Border・Teal・Coral）を追加し、
  端末のシステム設定に自動追従するようにしました。以前は白の半透明（opacity 0.4〜0.6）で
  文字色を表現していましたが、これがコントラスト不足の主因だったため、より高コントラストな
  色に置き換えています。
- **文字サイズの底上げ**：10〜16pt帯のフォントサイズを全体的に1〜1.5pt引き上げました。
  ただし**Dynamic Type（アクセシビリティの文字サイズ設定）への完全対応はまだです**
  （固定サイズ指定のため）。今後の課題として残しています。
- **オンボーディング**：初回起動時に5ページのチュートリアルを表示（`OnboardingView.swift`）。
  `UserDefaults`のフラグで一度だけ表示されます。
- **複数の緊急連絡先**：`EmergencyContact`モデルを追加し、名前・電話番号を複数登録できるように
  しました。SMSは複数人へ同時送信、SMS非対応端末では連絡先ごとに電話ボタンを表示します。
  旧バージョン（単一連絡先）のKeychainデータは初回起動時に自動移行されます。
- **毎日の見守りリマインダー**：設定タブから時刻を指定すると、毎日その時刻に
  ローカル通知でお知らせします。**通知は見守りを自動開始しません** — 開くだけです
  （タイマー開始は常に本人の明示的なタップを必要とする、という方針を守るため）。
- **記録への写真添付**：`PhotosPicker`で1枚添付でき、写真は本文とは別ファイルとして
  AES-GCMで個別に暗号化・保存されます（`journal_photos/`ディレクトリ、iCloudバックアップ除外）。
- **記録のPDF書き出し**：記録タブ右上の共有アイコンから、テキストのみのPDFを生成して
  共有シートを開けます。**写真はPDFには含まれません**（暗号化の意味が薄れるため意図的に除外）。
- **ホーム画面／ロック画面ウィジェット**：`SottoWidget`という新しいWidget Extensionターゲットを
  追加しました（`sotto://sos` / `sotto://checkin` のURL SchemeでアプリのURLを開くだけの
  静的ウィジェットです）。ウィジェット自体は発信もSMS送信も一切行わず、タップしてアプリを
  開くところまでです。ウィジェットの追加方法はXcodeでビルド後、実機のホーム画面を長押し→
  「ウィジェットを追加」→「そっと」から行ってください。

## 6.5 改ざん検知（記録のハッシュ値・作成時刻）
記録を保存する瞬間に、本文（＋写真があればそのバイト列）からSHA-256ハッシュを計算し、
端末クロックの作成時刻とあわせて記録に埋め込んでいます（`JournalEntry.contentHash` /
`.createdAt`）。アプリに「既存の記録を編集する」機能自体が存在しないため、このハッシュ値は
作成後に変わりようがありません。記録一覧・PDF書き出しの両方に、短縮ハッシュと作成時刻を
薄い文字で表示しています。

**これが証明すること／しないこと**：本文を独自に再計算したSHA-256と、表示されているハッシュ値が
一致すれば「この端末上で作成されて以来、書き換えられていない」ことの目安になります。ただし
これは自己申告のハッシュであり、第三者機関によるタイムスタンプ（RFC3161等）やブロックチェーンへの
記録ではないため、**法的な証拠能力を保証するものではありません**。「相談窓口に見せたときの
信頼性を少し補強する」程度の位置づけとして扱ってください。UI・PDFの文言でもそのように控えめに
表現しています。今後もし「記録を編集する」機能を追加する場合は、既存エントリの`contentHash`/
`createdAt`を書き換えるのではなく、新しいエントリとして扱う（または編集履歴を別途残す）設計に
してください。そうしないとこの機能の前提が崩れます。

## 7. このMVPでまだ未実装の部分（次のステップ）
- 相談窓口データの定期更新の仕組み（現状はアプリに同梱したJSONのみ・手動更新）
- チェックインのバックグラウンド継続性の実機検証（「When In Use」権限のみのため、
  ロック画面が長時間続くと位置更新が止まる制約は上記の通り残っている）
- アイコン画像アセット自体のデザイン（本README §5の手順でXcode側に追加が必要）
- Dynamic Type（文字サイズ設定）への完全対応
- ウィジェットのライブ更新（チェックイン中の残り時間表示など。App
  Group経由でのデータ共有が必要ですが未実装です）

## 8. 動作確認した設計判断（自己チェックより）
「帰宅チェックイン」に限定せず、SOSボタンはホーム画面に常駐し、
チェックインをセットしていなくても・屋内でも常に押せる位置づけにしています。
これは、被害者支援団体の公開統計（面識者・交際相手・配偶者からの被害が過半数）を踏まえた設計判断です。
「夜道で見知らぬ人に襲われる」ケースだけを想定した機能にしない、という方針は
文言・導線の両方で今後も維持してください。
