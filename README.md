# k

GCP (GKE Autopilot) 上に ArgoCD による GitOps デプロイ基盤を構築するリポジトリ。

## 構成

```
terraform/gke/          GKE Autopilotクラスタ + Workload Identity (Terraformで作成)
bootstrap/               ArgoCD自体のインストール + ApplicationSet (唯一の手動apply対象)
                         git-repo.yamlにGIT_REPO_URLを1箇所書くだけでOK(kustomizeのreplacementsで自動反映)
clusters/dev/            devクラスタで動かすApplication一覧 (app of apps)
                         同様にgit-repo.yamlにGIT_REPO_URLを1箇所書くだけでOK
apps/hello-world/        動作確認用プレースホルダーアプリ (base + overlays/dev)
infra-config/external-secrets/  External Secrets Operatorの設定 (ClusterSecretStore)
.github/workflows/       terraform fmt/validate と Kustomizeマニフェストのlint (デプロイは行わない)
```

デプロイの実経路は常に ArgoCD の pull のみ。GitHub Actions はバリデーションのみで、クラスタへの書き込み権限は持たない。

## 前提作業 (ユーザーが事前に行うこと)

1. GCPプロジェクトを作成し、課金アカウントを紐付ける
2. 必要なAPIを有効化:
   ```
   gcloud services enable \
     container.googleapis.com \
     iam.googleapis.com \
     secretmanager.googleapis.com \
     compute.googleapis.com \
     cloudresourcemanager.googleapis.com \
     --project=<PROJECT_ID>
   ```
3. Terraform実行用の認証を用意 (個人利用なら `gcloud auth application-default login` でも可)
4. Terraform remote state用のGCSバケットを作成:
   ```
   gcloud storage buckets create gs://<YOUR_TFSTATE_BUCKET> --project=<PROJECT_ID> --location=<GCP_REGION>
   ```
5. `terraform/gke/terraform.tfvars.example` を `terraform.tfvars` にコピーし、`project_id`/`region`/`cluster_name` を実際の値に変更 (`region`/`cluster_name`にデフォルト値は無いため必須)

## ブートストラップ手順

```bash
# 1. クラスタ作成
cd terraform/gke
terraform init \
  -backend-config="bucket=<YOUR_TFSTATE_BUCKET>" \
  -backend-config="prefix=gke/dev"
terraform apply

# 2. kubectl認証
gcloud container clusters get-credentials <CLUSTER_NAME> --region <GCP_REGION> --project <PROJECT_ID>

# 3. ArgoCDインストール
kubectl apply -k ../../bootstrap/argocd

# 4. 以下のプレースホルダを実際の値に置き換えてコミット・push
#    - bootstrap/git-repo.yaml, clusters/dev/git-repo.yaml の <GIT_REPO_URL>
#      (このリポジトリ自身のclone URL。この2ファイルだけ直せば、参照している
#       root-appset.yaml / apps.yaml 側はkustomizeのreplacementsで自動的に埋まる)
#    - clusters/dev/apps.yaml の <PROJECT_ID>
#    - infra-config/external-secrets/base/secretstore.yaml の
#      <PROJECT_ID>/<CLUSTER_LOCATION>/<CLUSTER_NAME>
#      (terraform.tfvars のproject_id/region/cluster_nameと一致させる)

# 5. root ApplicationSet を適用(これが最後の手動apply)
kubectl apply -k ../../bootstrap

# 6. ArgoCD初期パスワード取得 & ログイン
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
argocd login <ARGOCD_SERVER>
```

## 動作確認

```bash
kubectl get nodes
kubectl get pods -n argocd
argocd app list    # external-secrets-operator-dev / external-secrets-config-dev / hello-world-dev が Synced/Healthy
kubectl get clustersecretstore,externalsecret -n external-secrets
kubectl get pods,svc -n hello-world
kubectl port-forward svc/hello-world -n hello-world 8080:80
curl localhost:8080   # "Hello, world!" が返る
```

GitOpsループの確認: `apps/hello-world/overlays/dev/kustomization.yaml` 等を変更してpushし、
手動 `kubectl apply` なしで `argocd app get hello-world-dev` が `OutOfSync` → `Synced` に遷移することを確認する。

## CI (GitHub Actions) で `terraform plan` を実際に実行する場合 (任意)

Workload Identity Federation for GitHub Actions を設定した上で、リポジトリSecretsに以下を追加:

- `GCP_WORKLOAD_IDENTITY_PROVIDER`
- `GCP_TERRAFORM_SERVICE_ACCOUNT`
- `GCP_TFSTATE_BUCKET`
- `GCP_PROJECT_ID`

未設定の場合、`terraform-plan.yml` は `fmt`/`validate` のみ実行し、`plan` ステップはスキップされる。
