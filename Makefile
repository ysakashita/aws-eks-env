include params.env
export

TEMPLATE_DIR    := cloudformation
VPC_STACK       := $(STACK_PREFIX)-vpc
IAM_STACK       := $(STACK_PREFIX)-iam
CLUSTER_STACK   := $(STACK_PREFIX)-cluster
NODEGROUP_STACK := $(STACK_PREFIX)-nodegroup

INGRESS_NGINX_NS      := ingress-nginx
INGRESS_NGINX_VERSION := 1.11.0

.PHONY: help create delete status kubeconfig validate \
        create-vpc create-iam create-cluster create-nodegroup \
        delete-nodegroup delete-cluster delete-iam delete-vpc \
        deploy-ingress-controller undeploy-ingress-controller \
        deploy-sample undeploy-sample ingress-url

help:
	@echo "EKS Sandbox - CloudFormation管理"
	@echo ""
	@echo "使い方:"
	@echo "  make create      全スタックを作成 (VPC -> IAM -> Cluster -> NodeGroup)"
	@echo "  make delete      全スタックを削除 (NodeGroup -> Cluster -> IAM -> VPC)"
	@echo "  make status      全スタックの状態を表示"
	@echo "  make kubeconfig  kubectlの設定を更新"
	@echo "  make validate    CloudFormationテンプレートを検証"
	@echo ""
	@echo "個別スタック操作:"
	@echo "  make create-vpc / create-iam / create-cluster / create-nodegroup"
	@echo "  make delete-vpc / delete-iam / delete-cluster / delete-nodegroup"
	@echo ""
	@echo "設定: params.env を編集してください"
	@echo ""
	@echo "サンプルアプリ:"
	@echo "  make deploy-ingress-controller   ingress-nginx をインストール (kubectl apply)"
	@echo "  make deploy-sample               nginx サンプルをデプロイ"
	@echo "  make ingress-url                 アクセス用 URL を表示"
	@echo "  make undeploy-sample             サンプルを削除"
	@echo "  make undeploy-ingress-controller ingress-nginx を削除"

create: create-vpc create-iam create-cluster create-nodegroup

delete: delete-nodegroup delete-cluster delete-iam delete-vpc

create-vpc:
	aws cloudformation deploy \
		--stack-name $(VPC_STACK) \
		--template-file $(TEMPLATE_DIR)/vpc.yaml \
		--parameter-overrides \
			ClusterName=$(CLUSTER_NAME) \
			VpcCidr=$(VPC_CIDR) \
			PublicSubnet1Cidr=$(PUBLIC_SUBNET_1_CIDR) \
			PublicSubnet2Cidr=$(PUBLIC_SUBNET_2_CIDR) \
		--region $(AWS_REGION) \
		--no-fail-on-empty-changeset

create-iam:
	aws cloudformation deploy \
		--stack-name $(IAM_STACK) \
		--template-file $(TEMPLATE_DIR)/iam.yaml \
		--parameter-overrides \
			ClusterName=$(CLUSTER_NAME) \
		--capabilities CAPABILITY_NAMED_IAM \
		--region $(AWS_REGION) \
		--no-fail-on-empty-changeset

create-cluster:
	aws cloudformation deploy \
		--stack-name $(CLUSTER_STACK) \
		--template-file $(TEMPLATE_DIR)/eks-cluster.yaml \
		--parameter-overrides \
			ClusterName=$(CLUSTER_NAME) \
			KubernetesVersion=$(EKS_VERSION) \
			VpcStackName=$(VPC_STACK) \
			IamStackName=$(IAM_STACK) \
		--region $(AWS_REGION) \
		--no-fail-on-empty-changeset

create-nodegroup:
	aws cloudformation deploy \
		--stack-name $(NODEGROUP_STACK) \
		--template-file $(TEMPLATE_DIR)/eks-nodegroup.yaml \
		--parameter-overrides \
			ClusterName=$(CLUSTER_NAME) \
			VpcStackName=$(VPC_STACK) \
			IamStackName=$(IAM_STACK) \
			ClusterStackName=$(CLUSTER_STACK) \
			NodeInstanceType=$(NODE_INSTANCE_TYPE) \
			NodeMinSize=$(NODE_MIN_SIZE) \
			NodeMaxSize=$(NODE_MAX_SIZE) \
			NodeDesiredSize=$(NODE_DESIRED_SIZE) \
			NodeDiskSize=$(NODE_DISK_SIZE) \
		--region $(AWS_REGION) \
		--no-fail-on-empty-changeset

delete-nodegroup:
	-aws cloudformation delete-stack \
		--stack-name $(NODEGROUP_STACK) \
		--region $(AWS_REGION)
	aws cloudformation wait stack-delete-complete \
		--stack-name $(NODEGROUP_STACK) \
		--region $(AWS_REGION)

delete-cluster:
	-aws cloudformation delete-stack \
		--stack-name $(CLUSTER_STACK) \
		--region $(AWS_REGION)
	aws cloudformation wait stack-delete-complete \
		--stack-name $(CLUSTER_STACK) \
		--region $(AWS_REGION)

delete-iam:
	-aws cloudformation delete-stack \
		--stack-name $(IAM_STACK) \
		--region $(AWS_REGION)
	aws cloudformation wait stack-delete-complete \
		--stack-name $(IAM_STACK) \
		--region $(AWS_REGION)

delete-vpc:
	-aws cloudformation delete-stack \
		--stack-name $(VPC_STACK) \
		--region $(AWS_REGION)
	aws cloudformation wait stack-delete-complete \
		--stack-name $(VPC_STACK) \
		--region $(AWS_REGION)

status:
	@for stack in $(VPC_STACK) $(IAM_STACK) $(CLUSTER_STACK) $(NODEGROUP_STACK); do \
		STATUS=$$(aws cloudformation describe-stacks \
			--stack-name $$stack \
			--region $(AWS_REGION) \
			--query "Stacks[0].StackStatus" \
			--output text 2>/dev/null) || STATUS="NOT FOUND"; \
		printf "%-40s %s\n" "$$stack:" "$$STATUS"; \
	done

kubeconfig:
	aws eks update-kubeconfig \
		--name $(CLUSTER_NAME) \
		--region $(AWS_REGION) \
		--alias $(CLUSTER_NAME)

deploy-ingress-controller:
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v$(INGRESS_NGINX_VERSION)/deploy/static/provider/aws/deploy.yaml
	kubectl wait --namespace $(INGRESS_NGINX_NS) \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=120s

undeploy-ingress-controller:
	kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v$(INGRESS_NGINX_VERSION)/deploy/static/provider/aws/deploy.yaml --ignore-not-found

deploy-sample:
	kubectl apply -f k8s/sample-nginx/

undeploy-sample:
	kubectl delete -f k8s/sample-nginx/ --ignore-not-found

ingress-url:
	@echo "Ingress URL:"
	@kubectl get ingress nginx-sample \
		-o jsonpath='http://{.status.loadBalancer.ingress[0].hostname}{"\n"}' 2>/dev/null \
		|| echo "(まだ割り当てられていません。1〜2分待ってから再実行してください)"

validate:
	aws cloudformation validate-template \
		--template-body file://$(TEMPLATE_DIR)/vpc.yaml \
		--region $(AWS_REGION)
	aws cloudformation validate-template \
		--template-body file://$(TEMPLATE_DIR)/iam.yaml \
		--region $(AWS_REGION)
	aws cloudformation validate-template \
		--template-body file://$(TEMPLATE_DIR)/eks-cluster.yaml \
		--region $(AWS_REGION)
	aws cloudformation validate-template \
		--template-body file://$(TEMPLATE_DIR)/eks-nodegroup.yaml \
		--region $(AWS_REGION)
