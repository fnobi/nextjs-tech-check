---
name: nextjs-tech-check
description: Next.jsプロジェクトの技術構成（パッケージマネージャー・GitHub Actionsの認証方式など）を確認し、問題があれば修正するスキル
---

# Next.js 技術構成チェック & 修正スキル

現在開いているNext.jsプロジェクトのルートディレクトリを起点として、以下の確認と修正を行ってください。

## チェックリスト

### 1. パッケージマネージャーの確認（pnpm）

以下をすべて確認すること:

**A. ロックファイルの状態**
- `package-lock.json` が存在していないこと（存在する場合は問題として報告）
- `pnpm-lock.yaml` が存在すること（存在しない場合は問題として報告）

**B. package.json の `packageManager` フィールド**
- `package.json` に `packageManager` フィールドがあること
- 値が `pnpm@X.Y.Z` の形式でバージョンが明示されていること
- 存在しない・pnpm以外の場合は修正が必要

**C. GitHub Actions ワークフローでの pnpm 利用**
- `.github/workflows/` 配下のすべての `.yml` / `.yaml` ファイルを検査
- 依存インストールに `npm install` や `yarn install` を使っている箇所は `pnpm install` に修正
- `actions/cache` のキャッシュパスやキーが `package-lock.json` を参照している場合は `pnpm-lock.yaml` に修正
- ワークフロー内の `env` 変数で `ACTIONS_LOCK_FILE` などにロックファイル名が設定されている場合も同様に修正
- ビルドコマンドが `npm run build` になっている場合は `pnpm run build`（または `pnpm build`）に修正
- `actions/setup-node` を使っている場合は pnpm のセットアップ（`pnpm/action-setup@v4`）が追加されているか確認し、なければ追加を提案

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
- 修正後は「GitHub側でWorkload Identityの設定が必要」である旨をユーザーに案内すること

## 実行手順

1. まずすべてのファイルを読み込んで現状を把握する
2. 問題点をリストアップして報告する
3. 修正が必要な箇所について、ユーザーの確認を取ってから修正を適用する
   - 明らかな機械的修正（npmをpnpmに変える等）は確認なしで進めてよい
   - Workload Identity 移行のような影響範囲が大きい変更は、修正内容を先に提示してから実施する
4. 修正完了後に、GitHub側で必要な設定作業があればその内容も案内する

## 出力フォーマット

```
## チェック結果

### パッケージマネージャー（pnpm）
- [OK/NG] package-lock.json が存在しない
- [OK/NG] pnpm-lock.yaml が存在する
- [OK/NG] package.json に packageManager フィールドがある（現在値: xxx）
- ワークフローファイルごとの確認結果:
  - [ファイル名]: [OK/NG + 問題の詳細]

### Firebase 認証方式
- [対象ワークフローなし / OK / NG + 問題の詳細]

## 修正内容
[修正が必要な場合、変更箇所の概要を記載]
```
