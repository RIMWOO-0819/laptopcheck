# 판정 기준 / Judging rules

모든 기준은 `src/LaptopCheck.html`의 `RULES` 객체와 `evaluate()` 함수에 있습니다.
All rules live in the `RULES` object and `evaluate()` in `src/LaptopCheck.html`.

상태 / Status: **정상 OK** · **확인 Check** · **문제 Problem** · **참고 Info**

## 자동 점검 / Automatic

| 항목 Item | 출처 Source (Windows) | 정상 OK | 확인 Check | 문제 Problem |
|---|---|---|---|---|
| 모델 Model | `Win32_ComputerSystem`, `Win32_ComputerSystemProduct` | 판매글 모델 포함 | 불일치 | — |
| CPU | `Win32_Processor` | 판매글 CPU 포함 | 불일치 | — |
| RAM | `Win32_PhysicalMemory` | ≥ 판매글 − 1 GB | — | 부족 |
| 저장장치 용량 Storage size | `Get-PhysicalDisk` (USB 제외) | ≥ 판매글 × 0.9 | 부족 | — |
| 저장장치 상태 Drive health | `HealthStatus` | Healthy | — | 그 외 |
| SSD 마모도 Wear | `Get-StorageReliabilityCounter` (관리자) | ≤ 10% | ≤ 30% | > 30% |
| SSD 온도 Temperature | 〃 | ≤ 70 °C | > 70 °C | — |
| 복구 불가 읽기 오류 Read errors | 〃 | 0 | — | > 0 |
| 배터리 건강도 Battery health | `powercfg /batteryreport` | ≥ 80% | ≥ 70%, 또는 판매자 주장보다 5%p 이상 낮음 | < 70% |
| 충전 사이클 Cycles | 〃 | ≤ 500 | > 500 | — |
| 배터리 없음 No battery | 〃 + 섀시 유형 | — | — | 노트북인데 미검출 |
| 오류 장치 Device errors | `Win32_PnPEntity.ConfigManagerErrorCode` (45 제외) | 없음 | 코드 22 (사용 안 함) | 그 외 |
| 터치스크린 Touchscreen | HID usage `0D:04` | 감지 | — | 판매글엔 있는데 미검출 |
| 터치패드 Touchpad | HID usage `0D:05` | 감지 | 노트북인데 미검출 | — |
| 웹캠 Webcam | PnP class Camera/Image | 감지 | 노트북인데 미검출 | — |
| 오디오 Audio | PnP class AudioEndpoint | 2개 이상 | 1개 | 0개 |
| Wi-Fi | `Get-NetAdapter -Physical` | 감지 | — | 노트북인데 미검출 |
| 블루투스 Bluetooth | PnP class Bluetooth | 감지 | 미검출 | — |
| 비정상 종료 Unexpected shutdowns | Kernel-Power 41, 90일 | ≤ 2 | ≤ 9 | ≥ 10 |
| 블루스크린 Blue screens | WER-SystemErrorReporting 1001, 90일 | 0 | ≤ 2 | ≥ 3 |
| 하드웨어 오류 WHEA | WHEA-Logger, 90일 | 0 | ≥ 1 | — |
| 정품 인증 Activation | `SoftwareLicensingProduct` | 인증 | 미인증 | — |

참고(Info) 항목: 시리얼, BIOS, OS 설치일(14일 이내면 재설치 안내), 누적 사용 시간, C: 여유 공간, 해상도, 화면 크기, 로그 시작일(30일 이내면 초기화 흔적 안내), 드라이브 암호화, Microsoft 계정 수.

## 수동 테스트 / Manual

| 항목 Item | 자동 체크 Auto-tick |
|---|---|
| 키보드 Keyboard | 모든 키가 눌리면 정상 |
| 터치스크린 Touchscreen | 84칸 100% 칠하면 정상, 하드웨어 미검출이면 해당없음 |
| 터치패드 Touchpad | 이동·왼클릭·오른클릭·세로·가로 스크롤 5개 완료 시 정상 |
| 마이크 Microphone | RMS > 0.04가 8프레임 이상 |
| CPU 부하 CPU load | 초반(2–12초) 대비 마지막 10초 처리량 ≥ 55% 정상, ≥ 40% 확인, < 40% 문제 |

빠른 점검(Quick)은 핵심 항목만 표시하고 부하 테스트를 30초로, 전체 점검(Full)은 모든 항목과 60초로 진행합니다.
"(선택)" 성격의 항목(백라이트, 이어폰 잭, 영상 출력, 블루투스, 터치스크린)은 미완료여도 판정에 영향을 주지 않습니다.
