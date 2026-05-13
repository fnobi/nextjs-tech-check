---
name: nextjs-tech-check
description: Next.jsプロジェクトの技術構成（パッケージマネージャー・GitHub Actionsの認証方式・firebase-adminのローカル認証など）を確認し、問題があれば修正するスキル
---

# Next.js 技術構成チェック & 修正スキル

現在開いているNext.jsプロジェクトのルートディレクトリを起点として、以下の確認と修正を行ってください。

## チェックリスト

### 1. パッケージマネージャーの確認（pnpm）

以下をすべて確認すること:

**A. Node.js バージョンの確認**
- `.node-version` が存在すること
- 記載されているバージョンが `22` 以上であること（例: `22.0.0` や `22` はOK、`20.x` はNG）
- 存在しない・22未満の場合は `nodenv versions` を実行してローカルにインストール済みのバージョンを確認する:
  - 22以上のバージョンが存在すれば、その中で最新のものを `.node-version` に書き込む（最新pnpmの動作要件）
  - 22以上が一つも存在しなければ「Node.js 22以上がローカルに見つかりません。`nodenv install 22.x.x` 等でインストール後に再実行してください」とユーザーに伝えて中断する

**B. ロックファイルの状態**
- `package-lock.json` が存在していないこと（存在する場合は問題として報告）
- `pnpm-lock.yaml` が存在すること（存在しない場合は問題として報告）

**C. package.json の `packageManager` フィールド**
- `package.json` に `packageManager` フィールドがあること
- 値が `pnpm@X.Y.Z` の形式でバージョンが明示されていること
- 存在しない・pnpm以外の場合は修正が必要

**D. GitHub Actions ワークフローでの pnpm 利用**
- `.github/workflows/` 配下のすべての `.yml` / `.yaml` ファイルを検査
- 依存インストールに `npm install` や `yarn install` を使っている箇所は `pnpm install` に修正
- `actions/cache` のキャッシュパスやキーが `package-lock.json` を参照している場合は `pnpm-lock.yaml` に修正
- ワークフロー内の `env` 変数で `ACTIONS_LOCK_FILE` などにロックファイル名が設定されている場合も同様に修正
- ビルドコマンドが `npm run build` になっている場合は `pnpm run build`（または `pnpm build`）に修正
- `actions/setup-node` を使っている場合は pnpm のセットアップ（`pnpm/action-setup@v4`）が追加されているか確認し、なければ追加する
  - `version` は指定しないこと（`package.json` の `packageManager` フィールドに記載したバージョンが自動的に適用される）

### 2. GitHub Actions × Firebase Deploy の認証方式確認

`.github/workflows/` 配下のファイルで `firebase deploy` コマンドが含まれているワークフローを対象に:

**鍵ファイル・トークン認証の検出（問題あり）**
- `--token` フラグを使って Firebase 認証している（例: `firebase deploy --token ${{ secrets.FIREBASE_TOKEN }}`）
- `google-github-actions/auth` に `credentials_json` を使っている（サービスアカウントキーのJSONを直接渡している）
- 上記のいずれかに該当する場合は Workload Identity 認証への移行が必要

**Workload Identity 認証（正しい状態）**
- `google-github-actions/auth@v2` 以降を使用
- `workload_identity_provider` と `service_account` を secrets 経由で設定している
- `permissions` ブロックに `id-token: write` が含まれている

**鍵ファイル認証が検出された場合の修正方針**
- `--token` の削除
- `google-github-actions/auth@v2` ステップの追加（`workload_identity_provider` / `service_account` は secrets 参照のプレースホルダーとして `${{ secrets.WIF_PROVIDER }}` / `${{ secrets.WIF_SERVICE_ACCOUNT }}` を使用）
- `permissions` ブロックへの `id-token: write` と `contents: read` の追加
- ワークフロー修正後、`templates/workload-identity/setup.sh` をプロジェクトルートの `setup-workload-identity.sh` としてコピーし、以下の定数をプロジェクト情報から推測して書き換える:
  - `PROJECT_ID`: `.env` / `.env.local` / Firebase設定ファイル / ワークフローの env から推測
  - `REPO`: git remote URL または `.github/workflows/` 内の `github.repository` 参照から推測（形式: `org/repo`）
  - `PROJECT_NUMBER`: 自動推測が難しいため `your-project-number` のままコメント付きで残す
  - `SERVICE_ACCOUNT_NAME`: デフォルト `github-actions` のまま（プロジェクト固有の名前が判明していれば変更）
- コピー・書き換え後、「`setup-workload-identity.sh` を確認・実行してください」とユーザーに案内すること

### 3. 手元スクリプトの firebase-admin 認証方式確認

プロジェクト内の TypeScript / JavaScript ファイル（`scripts/`、`tools/`、`src/` 等）で `firebase-admin` を import / require しているファイルを対象に:

**鍵ファイル認証の検出（問題あり）**
- `admin.credential.cert(...)` を使っている（ファイルパスやサービスアカウントオブジェクトを直接渡している）
  - 例: `admin.credential.cert('./serviceAccountKey.json')`
  - 例: `admin.credential.cert(require('./serviceAccountKey.json'))`
  - 例: `admin.credential.cert(JSON.parse(fs.readFileSync(...)))`
- `initializeApp` の引数に `credential` キーで上記のいずれかを渡している

**ADC 認証（正しい状態）**
- `credential` を指定せず `projectId` のみ環境変数から渡している
  - 例: `admin.initializeApp({ projectId: process.env.FIREBASE_PROJECT_ID })`
- または `admin.initializeApp()` のみ（`GOOGLE_CLOUD_PROJECT` 等の環境変数で project が解決される）

**ADC 認証（正しい状態）の参考実装**
- `templates/cli/firebase-app.ts` と `templates/cli/env.ts` を読み込み、このパターンを参考に修正する
  - `firebase-app.ts`: `initializeApp({ projectId })` のみで初期化し、各サービスを遅延取得するパターン
  - `env.ts`: `.env` ファイルを `loadEnvFile` で読み込み、環境変数を export するエントリーポイント

**鍵ファイル認証が検出された場合の修正方針**
- `credential: admin.credential.cert(...)` の行を削除
- `initializeApp` の引数を `{ projectId: FIREBASE_PROJECT_ID }` に変更し、プロジェクト内の既存の環境変数名（例: `NEXT_PUBLIC_FIREBASE_PROJECT_ID`）に合わせる
- firebase app 参照が複数ファイルに散在している場合は `templates/cli/firebase-app.ts` のような集約モジュールへの切り出しを提案する
- ローカル実行時は `gcloud auth application-default login` で ADC を取得する旨をユーザーに案内すること
- `.env` や `.env.local` に project ID の環境変数が設定されているか確認し、なければ追記を提案する

### 4. .babelrc の必要性確認

`.babelrc` / `.babelrc.js` / `.babelrc.json` / `babel.config.js` / `babel.config.json` が存在する場合:

**背景**
- Next.js 12以降はデフォルトで SWC コンパイラーを使用する
- `.babelrc` 系ファイルが存在すると SWC が無効化され Babel にフォールバックする
- カスタムプラグインが不要であればファイルを削除して SWC に戻すべき

**確認手順**
1. `package.json` の `dependencies` / `devDependencies` から Next.js のバージョンを確認する
2. `.babelrc` の内容を確認し、以下のいずれかに該当すれば**不要と判断**する:
   - `{ "presets": ["next/babel"] }` のみ（デフォルト設定の再宣言）
   - Next.js 12以降で、SWC がサポートするプラグインのみを使用している
3. カスタムプラグインが含まれている場合はユーザーに内容を提示し判断を仰ぐ

**不要と判断した場合の修正方針**
- `.babelrc` 系ファイルを削除する
- `package.json` の `devDependencies` から Babel 関連パッケージを確認し、Next.js や他の設定で使われていないものを削除対象としてリストアップしてユーザーに確認する（例: `@babel/core`, `babel-loader`, `@babel/preset-env`, `@babel/preset-react`, `@babel/preset-typescript` 等）
- ユーザーの承認後、該当パッケージを `pnpm remove` で削除する

## 実行手順

1. まずすべてのファイルを読み込んで現状を把握する
2. 問題点をリストアップして報告する
3. 修正が必要な箇所について、以下の方針で対応する:
   - 明らかな機械的修正（npmをpnpmに変える等）は確認なしで進めてよい
   - Workload Identity 移行・firebase-admin 書き換えのような影響範囲が大きい変更は、修正内容を先に提示してから実施する
   - **pnpm 移行が必要な場合**: ファイル編集後に以下のコマンドを順に実行する（ユーザーの権限許可が必要）
     1. `rm package-lock.json`（存在する場合のみ）
     2. `pnpm install`
4. 修正完了後に、GitHub側で必要な設定作業があればその内容も案内する

## 出力フォーマット

```
## チェック結果

### パッケージマネージャー（pnpm）
- [OK/NG] .node-version が存在し Node.js 22 以上が指定されている（現在値: xxx）
- [OK/NG] package-lock.json が存在しない
- [OK/NG] pnpm-lock.yaml が存在する
- [OK/NG] package.json に packageManager フィールドがある（現在値: xxx）
- ワークフローファイルごとの確認結果:
  - [ファイル名]: [OK/NG + 問題の詳細]

### Firebase 認証方式（GitHub Actions）
- [対象ワークフローなし / OK / NG + 問題の詳細]

### firebase-admin 認証方式（ローカルスクリプト）
- [対象ファイルなし / OK / NG + 問題の詳細]

### .babelrc
- [存在しない / 不要（削除対象）/ 要確認（カスタムプラグインあり） + 詳細]

## 修正内容
[修正が必要な場合、変更箇所の概要を記載]
```
