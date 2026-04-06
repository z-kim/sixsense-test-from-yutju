🚀 SixSense Infrastructure Scripts Guide
이 디렉토리는 SixSense 클라우드 네이티브 인프라를 효율적으로 관리하고 운영하기 위한 자동화 스크립트 모음을 포함하고 있습니다. 모든 스크립트는 프로젝트 루트에 위치한 PEM 키(sixsense-test.pem)를 참조하며, Terraform 및 Ansible과 연동됩니다.

📋 스크립트 목록 및 기능
🛠 상세 사용법
1. 초기 전체 배포 (deploy-all.sh)
인프라를 처음부터 끝까지 한 번에 구축합니다. Terraform으로 AWS 리소스를 생성한 뒤 30초간 대기하며, 이후 Ansible을 통해 서비스 설정을 마칩니다.

2. 내부 서버 SSH 접속 (bastion-connect.sh)
보안을 위해 외부 노출이 차단된 Private IP 서버에 Bastion을 거쳐 접속합니다.

3. 서비스 상태 일괄 체크 (check-status.sh)
현재 운영 중인 주요 서비스들의 상태를 한눈에 확인합니다.

K3s: 노드 상태 (kubectl get nodes)

Kafka: 9092 포트 활성화 여부

Grafana: 3000 포트 활성화 여부

4. 모니터링 대시보드 접속 (monitor-connect.sh)
보안상 사설망에 있는 모니터링 서버의 대시보드를 로컬 환경으로 끌어옵니다.

Grafana: 

Prometheus: 

5. IP 정보 강제 동기화 (refresh-ip.sh)
서버를 껐다 켰을 때 Bastion의 퍼블릭 IP가 변경되어 접속이 안 되는 경우 실행합니다. AWS 실시간 상태를 조회하여 Terraform Output을 갱신합니다.

⚠️ 주의 및 참고 사항
PEM 키 설정: 모든 스크립트는 기본적으로 ../sixsense-test.pem 경로를 참조합니다. 다른 키를 사용할 경우 환경 변수로 지정하세요.

실행 권한: 스크립트 실행 전 실행 권한이 없다면 다음 명령을 입력하세요.

종속성: aws-cli, terraform, ansible이 로컬 환경에 설치되어 있어야 하며, AWS 자격 증명(aws configure)이 완료된 상태여야 합니다.
