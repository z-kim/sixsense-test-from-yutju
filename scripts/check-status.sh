#!/bin/bash

# --- 1. 경로 및 키 변수 설정 ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

# 키 파일 이름을 환경 변수에서 가져오거나 기본값 사용
KEY_NAME="${KEY_NAME:-sixsense-test.pem}"
KEY_PATH="$SCRIPT_DIR/../$KEY_NAME"

echo ">>> 프로젝트 루트: $(cd "$SCRIPT_DIR/.." && pwd)"
echo ">>> 사용 중인 키 파일: $KEY_NAME"
echo ">>> Terraform에서 인프라 정보를 추출하는 중..."

# --- 2. Terraform Output 추출 (에러 핸들링 보강) ---
get_tf_output() {
    terraform -chdir="$TERRAFORM_DIR" output -raw "$1" 2>/dev/null
}

BASTION_IP=$(get_tf_output bastion_public_ip)
MASTER_IP=$(get_tf_output k3s_master_private_ip)
KAFKA_IP=$(get_tf_output kafka_private_ip)
GRAFANA_IP=$(get_tf_output grafana_private_ip)

# --- 3. 유효성 체크 ---
if [ -z "$BASTION_IP" ] || [[ "$BASTION_IP" == *"No outputs"* ]]; then
    echo "에러: Bastion IP를 가져오지 못했습니다. terraform apply 상태를 확인하세요."
    exit 1
fi

echo "--------------------------------------------------"
echo " [ Infra Info ]"
echo " Bastion : $BASTION_IP"
echo " Master  : $MASTER_IP"
echo " Kafka   : $KAFKA_IP"
echo " Grafana : $GRAFANA_IP"
echo "--------------------------------------------------"

# --- 4. SSH Agent 설정 및 키 등록 ---
if [ ! -f "$KEY_PATH" ]; then
    echo "에러: 키 파일을 찾을 수 없습니다 ($KEY_PATH)"
    exit 1
fi

chmod 400 "$KEY_PATH"
eval "$(ssh-agent -s)" > /dev/null
ssh-add "$KEY_PATH" 2>/dev/null

# --- 5. 상태 체크 실행 ---
echo ""
echo " [1/3] K3s Cluster Status (via Master)"
# kubectl 권한 문제 방지를 위해 sudo 사용 또는 권한 우회 시도
ssh -A -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -J ubuntu@"$BASTION_IP" ubuntu@"$MASTER_IP" \
    "sudo kubectl get nodes" 2>/dev/null || echo "K3s 접속 실패"

echo ""
echo " [2/3] Kafka Service Check (9092)"
ssh -A -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -J ubuntu@"$BASTION_IP" ubuntu@"$KAFKA_IP" \
    "nc -zv -w 2 localhost 9092 2>&1" | grep -q "succeeded" && echo "Kafka is Up" || echo " Kafka is Down"

echo ""
echo " [3/3] Grafana Service Check (3000)"
ssh -A -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -J ubuntu@"$BASTION_IP" ubuntu@"$GRAFANA_IP" \
    "nc -zv -w 2 localhost 3000 2>&1" | grep -q "succeeded" && echo "Grafana is Up" || echo "Grafana is Down"

echo ""
echo "--------------------------------------------------"
echo "상태 체크 완료!"
