#!/bin/bash

# --- 1. 경로 및 변수 설정 ---
# 스크립트 위치 기준 자동 경로 인식
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

# [핵심] 키 파일 이름을 환경 변수로 받거나, 없으면 기본값 사용
KEY_NAME="${KEY_NAME:-practice.pem}"
KEY_PATH="$SCRIPT_DIR/../$KEY_NAME"

echo ">>> 프로젝트 루트: $(cd "$SCRIPT_DIR/.." && pwd)"
echo ">>> 사용 중인 키 파일: $KEY_NAME"
echo ">>> Bastion IP 정보를 가져오는 중..."

# --- 2. Bastion IP 가져오기 ---
BASTION_IP=$(terraform -chdir="$TERRAFORM_DIR" output -raw bastion_public_ip 2>/dev/null)

if [ -z "$BASTION_IP" ] || [[ "$BASTION_IP" == *"No outputs"* ]]; then
    echo "에러: Terraform에서 Bastion IP를 가져오지 못했습니다."
    echo "확인: 'terraform apply'가 성공했는지, 'output \"bastion_public_ip\"'가 정의되었는지 확인하세요."
    exit 1
fi

echo ">>> Bastion IP: $BASTION_IP"

# --- 3. Private IP 입력 처리 ---
PRIVATE_IP=$1
if [ -z "$PRIVATE_IP" ]; then
    read -p ">>> 접속할 Private IP를 입력하세요 (예: 10.0.11.10): " PRIVATE_IP
fi

if [ -z "$PRIVATE_IP" ]; then
    echo "에러: Private IP가 입력되지 않았습니다."
    exit 1
fi

echo ">>> Target Private IP: $PRIVATE_IP"

# --- 4. PEM 키 확인 및 권한 수정 ---
if [ ! -f "$KEY_PATH" ]; then
    echo "에러: PEM 키 파일을 찾을 수 없습니다."
    echo "경로: $KEY_PATH"
    echo "팁: KEY_NAME=파일명.pem ./bastion-connect.sh 형식으로 실행하세요."
    exit 1
fi

# SSH 접속을 위해 키 권한을 엄격하게 제한 (필수 🎖️)
chmod 400 "$KEY_PATH"

# --- 5. SSH Agent 실행 및 키 등록 ---
if [ -z "$SSH_AUTH_SOCK" ]; then
    echo ">>> SSH Agent 시작"
    eval "$(ssh-agent -s)" >/dev/null
fi

# 기존에 등록된 키가 있을 수 있으므로 조용히 추가
ssh-add "$KEY_PATH" >/dev/null 2>&1

# --- 6. SSH 접속 (Jump Host 방식) ---
echo ">>> Bastion($BASTION_IP)을 통해 $PRIVATE_IP 접속 중..."

ssh -A \
  -i "$KEY_PATH" \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -J ubuntu@"$BASTION_IP" \
  ubuntu@"$PRIVATE_IP"
