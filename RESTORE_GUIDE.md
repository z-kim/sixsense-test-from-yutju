# SixSense 인프라 재해 복구(DR) 시스템 가이드

이 프로젝트는 AWS 인프라의 고가용성과 장애 발생 시 신속한 복구를 위해 **Terraform**과 **Ansible**을 결합한 자동화 환경을 구축했습니다.

## 1. 네트워크 및 IP 매핑 정보 (VPC 기반)

현재 SixSense 인프라의 주요 서버 및 역할별 IP 할당 현황입니다.

| 서버 이름 | 역할 | 내부 IP (Private) | 백업 크기 (평균) | 특징 |
| :--- | :--- | :--- | :--- | :--- |
| **Bastion-Host** | 운영 관리 관문 | `192.168.100.10` | 14~16 MB | 매일 04:00 자동 백업 |
| **NAT Instance** | 아웃바운드 통로 | `192.168.100.20` | 6~6.8 MB | 네트워크 주소 변환 관리 |
| **K3s Master** | 쿠버네티스 제어 | `192.168.110.10` | ~4.2 MB | 컨테이너 오케스트레이션 |
| **Kafka Server** | 메시지 브로커 | `192.168.110.40` | ~74.4 MB | 대용량 데이터 스트리밍 |
| **Grafana** | 모니터링 대시보드 | `192.168.120.10` | - | 시스템 시각화 및 알람 |

* **ALB DNS:** `sixsense-alb-1449072514.ap-northeast-2.elb.amazonaws.com`
* **Backup S3:** `sixsense-backup-storage-aceur6`

---

## 2. 자동 백업 정책

* **백업 대상:** `/etc`, `/var/log`, `/home/ubuntu` 등 시스템 핵심 설정 및 데이터
* **보관 장소:** Amazon S3 (`sixsense-backup-storage-aceur6`)
* **파일명 규칙:** `backups/backup_ip-<대상IP>_YYYYMMDD_HHMMSS.tar.gz`

---

## 3. 복구(DR) 실행 가이드
```bash
장애 발생 시 서버를 부활시키는 단계별 절차입니다.

Step 1: 인프라 부활 (Terraform)
운영 서버가 삭제되었거나 장애가 난 경우, 테라폼을 통해 동일한 사양의 인프라를 즉시 생성합니다.

cd terraform
terraform apply

Step 2: 앤서블로 데이터 및 설정 주입 (Ansible)
S3의 최신 백업 데이터를 신규 서버에 이식합니다.

상황별 실행 예시
Kafka 서버(110.40)가 터졌을 때:
cd ../ansible
ansible-playbook -i inventory/aws_ec2.yml dr_restore.yml \
  --limit 192.168.110.40 \
  -e "origin_ip=192.168.110.40"

Bastion 서버(100.10)가 터졌을 때:
cd ../ansible
ansible-playbook -i inventory/aws_ec2.yml dr_restore.yml \
  --limit 192.168.100.10 \
  -e "origin_ip=192.168.100.10"

복구 기본 공식
ansible-playbook -i inventory/aws_ec2.yml dr_restore.yml \
  --limit [지금_살릴_서버_IP] \
  -e "origin_ip=[S3에_저장된_원본_IP]"