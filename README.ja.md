# AI 向け説明

> このセクションは AI アシスタント向けです。人間のユーザーは [Kind Stack - Dify Enterprise Edition](#kind-stack---dify-enterprise-edition) にスキップできます。

## 利用可能なスキル

このリポジトリは Dify EE ローカルデプロイ用の2つのスキルを提供します：

### 1. `dify-ee-local` - Dify EE のデプロイ

**トリガー**: "deploy dify enterprise locally", "setup dify ee on kind", "local kubernetes dify", "dify をローカルにデプロイ"

**ワークフロー**:
1. ユーザーに確認: (a) kind-stack パス, (b) Helm Chart パス
2. `scripts/check-prerequisites.sh` を実行して Docker, kubectl, Helm, Kind を検証
3. フェーズ1: インフラストラクチャのセットアップ
   - `cd <kind-stack-path>/kind-cluster && ./init.sh`
   - `cd <kind-stack-path>/infrastructure && docker compose up -d`
   - `./init-databases.sh` (デフォルト値を使用)
4. フェーズ2: `values.yaml` を設定、[dify-ee-local/references/values-config.md](dify-ee-local/references/values-config.md) を参照
5. フェーズ3: `helm install dify <helm-chart-path> --namespace dify --create-namespace`
6. フェーズ4: hosts 設定を追加 (`scripts/show-hosts-config.sh` を実行)

**アクセス URL**: console.dify.local, enterprise.dify.local, app.dify.local

### 2. `dify-ee-cleanup` - Dify EE の削除

**トリガー**: "cleanup dify", "uninstall dify ee", "dify を削除", "dify 環境をクリーンアップ"

**クイッククリーンアップ**:
```bash
helm uninstall dify -n dify 2>/dev/null || true
kubectl delete namespace dify --ignore-not-found
kind delete cluster --name dify-ee-kind
cd <kind-stack-path>/infrastructure && docker compose down -v --rmi all
rm -rf <kind-stack-path>/infrastructure/data/*
```

## インフラストラクチャ詳細

| サービス   | ホスト (Kind 内から)     | ポート | 認証情報                  |
|------------|--------------------------|--------|---------------------------|
| PostgreSQL | host.docker.internal     | 55432  | postgres / devpassword    |
| Redis      | host.docker.internal     | 6379   | devpassword               |
| Qdrant     | host.docker.internal     | 6333   | devpassword               |
| MinIO      | host.docker.internal     | 9000   | minioadmin / minioadmin123|

**データベース**: dify, plugin_daemon, enterprise, audit

## ファイル構造

```
kind-cluster/init.sh          # Kind クラスタ + Ingress を作成
infrastructure/docker-compose.yaml  # PostgreSQL, Redis, Qdrant, MinIO
infrastructure/init-databases.sh    # 必要なデータベースを作成
dify-ee-local/SKILL.md        # 完全なデプロイ手順
dify-ee-cleanup/SKILL.md      # 完全なクリーンアップ手順
```

---

# Kind Stack - Dify Enterprise Edition

ローカル Kind (Kubernetes in Docker) クラスタ上に Dify Enterprise Edition をデプロイするための前提条件とインフラストラクチャ設定を提供します。

## 重要なお知らせ

**このプロジェクトは教育デモンストレーション目的のみです。テストや本番環境での使用は推奨されません。**

このプロジェクトは Dify Enterprise Edition デプロイの前提条件のみを提供します：
- Kind クラスタの作成と設定
- データ永続化インフラストラクチャのデプロイ
- データベースの初期化

実際の Dify Enterprise Edition デプロイについては、公式ドキュメントを参照してください。

## プロジェクト概要

このプロジェクトは Dify Enterprise Edition インストールの前提条件を提供します：

- **Kind クラスタ管理**: プロキシサポート付きの自動作成と設定
- **Ingress Controller**: NGINX Ingress Controller の自動インストール
- **データ永続化インフラストラクチャ**: Docker Compose による PostgreSQL、Redis、Qdrant、MinIO
- **データベース初期化**: 必要な PostgreSQL データベースの自動チェックと作成

## プロジェクト構造

```
kind-stack/
├── kind-cluster/                    # Kind クラスタ設定
│   ├── init.sh                      # Kind クラスタ初期化スクリプト
│   └── config.yaml                  # Kind クラスタ設定ファイル
├── infrastructure/                  # データ永続化インフラストラクチャ
│   ├── docker-compose.yaml          # Docker Compose 設定
│   ├── init-databases.sh            # データベース初期化スクリプト
│   └── data/                        # データディレクトリ
├── dify-ee-local/                   # デプロイスキル
└── dify-ee-cleanup/                 # クリーンアップスキル
```

## クイックスタート

### 前提条件

- **Docker Desktop** または **Docker Engine** (20.10+)
- **kubectl** (1.24+)
- **Helm** 3.x
- **Kind** (0.20+)

### 依存関係のインストール

```bash
# macOS
brew install kind helm postgresql

# Linux (Ubuntu/Debian)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

## 使用ガイド

### ステップ 1: Kind クラスタの作成

```bash
cd kind-cluster
./init.sh
```

### ステップ 2: インフラストラクチャの起動

```bash
cd infrastructure
docker compose -f docker-compose.yaml up -d
```

### ステップ 3: データベースの初期化

```bash
./init-databases.sh
```

## 設定

### インフラストラクチャ設定（Kind クラスタ内からのアクセス）

- **PostgreSQL**: `host.docker.internal:55432`
- **Redis**: `host.docker.internal:6379`
- **Qdrant**: `http://host.docker.internal:6333`
- **MinIO**: `http://host.docker.internal:9000`

## 停止とクリーンアップ

```bash
# インフラストラクチャサービスを停止
cd infrastructure && docker compose down

# Kind クラスタを削除
kind delete cluster --name dify-ee-kind

# データをクリーン
rm -rf infrastructure/data/*
```

## 関連ドキュメント

- [Dify ドキュメント](https://docs.dify.ai/)
- [Dify Enterprise Edition ドキュメント](https://enterprise-docs.dify.ai/)
- [Kind ドキュメント](https://kind.sigs.k8s.io/)

## 免責事項

**このプロジェクトは教育デモンストレーション目的のみです。テストや本番環境での使用は推奨されません。**

本番デプロイには、公式の Helm Chart とデプロイガイドを使用してください。
