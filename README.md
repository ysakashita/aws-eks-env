# aws-eks-env

CloudFormation を使って EKS サンドボックスクラスタを簡単に作成・削除するためのテンプレート集です。

## 構成

```
├── cloudformation/
│   ├── vpc.yaml           # VPC / サブネット / IGW / NAT GW
│   ├── iam.yaml           # EKS クラスター・ノード用 IAM ロール
│   ├── eks-cluster.yaml   # EKS クラスター + アドオン (vpc-cni, kube-proxy, coredns)
│   └── eks-nodegroup.yaml # マネージドノードグループ
├── params.env             # 設定パラメータ
└── Makefile               # 操作コマンド
```

スタックは以下の順で依存しています:

```
vpc → iam → eks-cluster → eks-nodegroup
```

## 前提条件

- AWS CLI (設定済み)
- `kubectl`
- 適切な IAM 権限 (CloudFormation, EKS, EC2, IAM)

## 使い方

### 1. パラメータを設定

```bash
vi params.env
```

必要に応じて `CLUSTER_NAME` や `AWS_REGION` を変更してください。

### 2. クラスターを作成

```bash
make create
```

所要時間の目安:
| スタック | 時間 |
|---|---|
| VPC | 2〜3 分 |
| IAM | 1〜2 分 |
| EKS Cluster + アドオン | 12〜18 分 |
| Node Group | 4〜6 分 |
| **合計** | **約 20〜30 分** |

### 3. kubectl を設定

```bash
make kubeconfig
kubectl get nodes
```

### 4. クラスターを削除

```bash
make delete
```

## その他のコマンド

```bash
make status      # 全スタックの状態を確認
make validate    # テンプレートの構文チェック
make help        # コマンド一覧を表示
```

個別スタックの操作も可能です:

```bash
make create-vpc
make create-iam
make create-cluster
make create-nodegroup
```

## ネットワーク構成

- VPC: `10.0.0.0/16`
- パブリックサブネット: AZ-a (`10.0.1.0/24`), AZ-c (`10.0.2.0/24`)
- プライベートサブネット: AZ-a (`10.0.11.0/24`), AZ-c (`10.0.12.0/24`)
- NAT Gateway: 1台 (パブリックサブネット AZ-a)
- ノードはプライベートサブネットに配置
- kubectl はパブリックエンドポイント経由でアクセス可能

## コスト

サンドボックスの主なコスト要素 (ap-northeast-1):
- EKS クラスター: $0.10/時間 (標準サポート期間内)
- NAT Gateway: $0.062/時間 + データ転送
- EC2 (t3.medium × 2): $0.052/台/時間

> **注意**: EKS バージョンが標準サポート期間 (リリースから約14ヶ月) を過ぎると、延長サポート料金 (~$0.60/時間) が適用されます。`params.env` の `EKS_VERSION` を最新バージョンに保つことを推奨します。

**使わないときは `make delete` で削除することを推奨します。**
