---
name: wif-setup
description: GitHub Actions から Firebase へ Workload Identity Federation（WIF）で認証するための設定を、GCPリソース作成からワークフロー修正・secrets登録まで一括支援するスキル
---

# WIF セットアップスキル

GitHub Actions から Firebase Deploy を実行するための Workload Identity Federation（WIF）認証を、GCP リソース作成からワークフロー修正・GitHub Secrets 登録まで一括で設定します。

## ステップ 1: 前提条件の確認

以下をすべて確認してから次のステップに進むこと。

**gcloud 認証状態の確認**
- `gcloud auth list` を実行してログイン済みアカウントを確認する
- ログインしていない場合は「`gcloud auth login` を実行してください」と案内して中断する

**プロジェクト情報の収集**

以下の順序で各値を取得・推測する:

- `PROJECT_ID`:
  1. `.env` / `.env.local` の `FIREBASE_PROJECT_ID` / `NEXT_PUBLIC_FIREBASE_PROJECT_ID` / `GCLOUD_PROJECT` 等から推測
  2. `.github/workflows/` 内の `env` ブロックに記載があれば使用
  3. 推測できない場合はユーザーに直接確認する

- `REPO`:
  1. `git remote get-url origin` を実行し、`https://github.com/org/repo.git` や `git@github.com:org/repo.git` から `org/repo` 形式を抽出する
  2. 取得できない場合はユーザーに確認する

- `PROJECT_NUMBER`:
  1. `PROJECT_ID` が確定している場合は `gcloud projects describe $PROJECT_ID --format='value(projectNumber)'` で自動取得する
  2. 取得できない場合は `your-project-number` のままにしてユーザーに確認を依頼する

すべての値が揃ったら次のステップに進む。確認できた内容を以下の形式で報告すること:

```
## WIF セットアップ状況

### 前提条件
- [OK/NG] gcloud ログイン済み（アカウント: xxx）
- [確認済み/推測/要確認] PROJECT_ID: xxx
- [確認済み/推測/要確認] REPO: xxx
- [確認済み/取得失敗] PROJECT_NUMBER: xxx
```

## ステップ 2: GCP リソースの作成

`templates/workload-identity/setup.sh`（このスキルと同じリポジトリに含まれているテンプレート）をプロジェクトルートに `setup-workload-identity.sh` としてコピーし、ステップ1で収集した値で以下の定数を書き換える:

- `PROJECT_ID` → 確定した値
- `PROJECT_NUMBER` → 確定した値（不明な場合は `your-project-number` のまま残しコメントで案内）
- `REPO` → `org/repo` 形式の値
- `SERVICE_ACCOUNT_NAME` → デフォルト `github-actions` のまま（特定の名前が判明していれば変更）

書き換え後のスクリプト内容をユーザーに提示し、確認を得てから実行する。

**実行方法**:
```bash
chmod +x setup-workload-identity.sh
./setup-workload-identity.sh
```

実行後、スクリプトの末尾に出力される以下の値を控える（次のステップで使用）:
- `WIF_PROVIDER`: `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider`
- `WIF_SERVICE_ACCOUNT`: `SERVICE_ACCOUNT_NAME@PROJECT_ID.iam.gserviceaccount.com`

既に WIF リソースが作成済みの場合（スクリプト実行でエラーが出た場合）は、`gcloud iam workload-identity-pools list --location=global --project=$PROJECT_ID` で既存のリソースを確認し、値を特定する。

```
### GCP リソース
- [作成済み/既存/エラー] Workload Identity Pool: github-pool
- [作成済み/既存/エラー] Provider: github-provider
- [作成済み/既存/エラー] Service Account: github-actions@xxx.iam.gserviceaccount.com
```

## ステップ 3: GitHub Actions ワークフローの修正

`.github/workflows/` 配下のすべての `.yml` / `.yaml` ファイルを検査し、`firebase deploy` コマンドを含むワークフローを対象に以下を修正する。

**検出対象（問題あり）**:
- `--token ${{ secrets.FIREBASE_TOKEN }}` で認証している
- `google-github-actions/auth` に `credentials_json` を使っている
- `google-github-actions/auth` が存在せず、Firebase 認証が未設定

**正しい状態**:
- `permissions` ブロックに `id-token: write` と `contents: read` がある
- `google-github-actions/auth@v2` ステップで `workload_identity_provider` と `service_account` を secrets 経由で設定している

**修正内容**:

1. ジョブレベルに `permissions` ブロックを追加（または `id-token: write` を追記）:
```yaml
permissions:
  id-token: write
  contents: read
```

2. `--token` フラグの削除、および `google-github-actions/auth@v2` ステップの追加:
```yaml
- name: Authenticate to Google Cloud
  uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
    service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}
```

3. `credentials_json` を使った認証ステップがあれば上記に置き換える

修正前後の差分をユーザーに提示してから変更を適用すること。

```
### GitHub Actions ワークフロー
- [ファイル名]: [修正済み/修正不要/要確認 + 問題の詳細]
```

## ステップ 4: GitHub Secrets の登録案内

以下の secrets を GitHub リポジトリに登録するよう案内する。値はステップ2で控えた値を使う。

| Secret 名 | 値 |
|---|---|
| `WIF_PROVIDER` | `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider` |
| `WIF_SERVICE_ACCOUNT` | `SERVICE_ACCOUNT_NAME@PROJECT_ID.iam.gserviceaccount.com` |

**登録方法（いずれか）**:

GitHub CLI が使える場合:
```bash
gh secret set WIF_PROVIDER --body "projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider"
gh secret set WIF_SERVICE_ACCOUNT --body "SERVICE_ACCOUNT_NAME@PROJECT_ID.iam.gserviceaccount.com"
```

GitHub UI の場合:
1. リポジトリの `Settings` → `Secrets and variables` → `Actions` を開く
2. `New repository secret` をクリックして各 secret を登録する

既に同名の secret が存在する場合は値を上書き更新すること。

```
### GitHub Secrets
- WIF_PROVIDER: [登録済み/要登録]
- WIF_SERVICE_ACCOUNT: [登録済み/要登録]
```

## ステップ 5: 動作確認

**確認手順**:

1. ワークフローをトリガーして実行する（手動トリガーがあれば `Actions` タブから `Run workflow`、なければ対象ブランチへの push）
2. ワークフローの `Authenticate to Google Cloud` ステップが成功することを確認する
3. `firebase deploy` ステップが認証エラーなく完了することを確認する

**よくあるエラーと対処法**:

| エラー | 原因 | 対処 |
|---|---|---|
| `Error: google-github-actions/auth failed with: failed to generate Google Cloud federated token` | WIF_PROVIDER の値が間違っている | `gcloud iam workload-identity-pools providers describe github-provider --workload-identity-pool=github-pool --location=global --project=$PROJECT_ID` で正しい値を確認 |
| `Permission denied on resource project` | サービスアカウントに Firebase デプロイ権限がない | GCP コンソールで `SERVICE_ACCOUNT@PROJECT_ID.iam.gserviceaccount.com` に `Firebase Admin` または `Firebase Hosting Admin` ロールを付与 |
| `Repository not allowed by attribute condition` | REPO の値がプロバイダー設定と一致しない | `setup-workload-identity.sh` の `REPO` 変数が `org/repo` 形式（大文字小文字も含めて正確）か確認 |
| `Error: secret WIF_PROVIDER not found` | GitHub Secrets が未登録 | ステップ4の手順で secrets を登録 |

## 出力フォーマット（完了時）

```
## WIF セットアップ完了

### 前提条件
- [OK] gcloud ログイン済み（アカウント: xxx）
- [確認済み] PROJECT_ID: xxx
- [確認済み] REPO: xxx
- [確認済み] PROJECT_NUMBER: xxx

### GCP リソース
- [作成済み] Workload Identity Pool: github-pool
- [作成済み] Provider: github-provider
- [作成済み] Service Account: github-actions@xxx.iam.gserviceaccount.com

### GitHub Actions ワークフロー
- [ファイル名]: [修正済み / 修正不要]

### GitHub Secrets
- WIF_PROVIDER: [要登録（値: projects/xxx/...）]
- WIF_SERVICE_ACCOUNT: [要登録（値: github-actions@xxx...）]

## 次のステップ
1. GitHub Secrets を登録してください（上記の値を使用）
2. ワークフローをトリガーして動作確認してください
```
