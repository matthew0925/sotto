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
チェックイン中の位置情報取得と、ジャーナルのFace ID/パスコードロックのため、
以下2つのUsage Descriptionが**必須**です（未設定だと該当機能の呼び出しでクラッシュします）。

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

## 6. このMVPでまだ未実装の部分（次のステップ）
- 相談窓口データの定期更新の仕組み（現状はアプリに同梱したJSONのみ・手動更新）
- チェックインのバックグラウンド継続性の実機検証（「When In Use」権限のみのため、
  ロック画面が長時間続くと位置更新が止まる制約は上記の通り残っている）
- 見守り連絡先の複数登録（現状は1件のみ）
- アイコン画像アセット自体のデザイン（本README §5の手順でXcode側に追加が必要）

## 7. 動作確認した設計判断（自己チェックより）
「帰宅チェックイン」に限定せず、SOSボタンはホーム画面に常駐し、
チェックインをセットしていなくても・屋内でも常に押せる位置づけにしています。
これは、被害者支援団体の公開統計（面識者・交際相手・配偶者からの被害が過半数）を踏まえた設計判断です。
「夜道で見知らぬ人に襲われる」ケースだけを想定した機能にしない、という方針は
文言・導線の両方で今後も維持してください。
