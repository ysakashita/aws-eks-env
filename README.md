# aws-eks-env

CloudFormation を使って EKS サンドボックスクラスタを簡単に作成・削除するためのテンプレート集です。

## 構成

```
├── cloudformation/
│   ├── vpc.yaml           # VPC / サブネット / IGW
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
- パブリックサブネット: AZ-a (`10.0.1.0/24`), AZ-b (`10.0.2.0/24`)
- NAT Gateway なし (Internet Gateway 経由でインターネットアクセス)
- ノードはパブリックサブネットに配置 (パブリック IP 自動割り当て)
- kubectl はパブリックエンドポイント経由でアクセス可能

**使わないときは `make delete` で削除することを推奨します。**
