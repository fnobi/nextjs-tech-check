PROJECT_ID="your-project-id"
PROJECT_NUMBER="your-project-number"  # gcloud projects describe $PROJECT_ID --format='value(projectNumber)'
REPO="your-org/your-repo"
SERVICE_ACCOUNT_NAME="github-actions"

# 1. Workload Identity Pool 作成
gcloud iam workload-identity-pools create "github-pool" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --display-name="GitHub Actions Pool"

# 2. Provider 作成
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --attribute-condition="assertion.repository=='${REPO}'"

# 3. サービスアカウント作成（既存があればスキップ）
gcloud iam service-accounts create "${SERVICE_ACCOUNT_NAME}" \
  --project="${PROJECT_ID}" \
  --display-name="Github Actions"

# 4. Workload Identity 経由での借用を許可
gcloud iam service-accounts add-iam-policy-binding \
  "${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --project="${PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-pool/attribute.repository/${REPO}"

echo "WIF_PROVIDER:\nprojects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-pool/providers/github-provider"
echo "WIF_SERVICE_ACCOUNT:\n${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"