# 🔌 UART-FIFO-Counter System

> SystemVerilog 기반 데이터 처리 시스템 - UART 통신, FIFO 버퍼링, Counter 제어를 통합한 FPGA 기반 데이터 처리 시스템

![FPGA](https://img.shields.io/badge/FPGA-Basys3-red?style=flat-square)
![Language](https://img.shields.io/badge/Language-SystemVerilog-blue?style=flat-square)
![Tool](https://img.shields.io/badge/Tool-Vivado-orange?style=flat-square)

---

## 📋 프로젝트 개요

UART 통신을 통해 수신된 데이터를 FIFO로 버퍼링하고, Counter 및 제어 로직을 통해 데이터를 처리하는 FPGA 기반 데이터 처리 시스템입니다.

### 🎯 주요 목표
- UART RX/TX 통신 모듈 설계
- FIFO 기반 데이터 버퍼링 구조 구현
- Counter 및 FSM 기반 데이터 제어 로직 설계
- SystemVerilog Testbench를 통한 기능 검증

---

## ✨ 주요 기능

### 1. UART 통신 모듈
- **UART RX/TX** 통신 모듈 설계
- **모든 설계** 완료 후 검증

### 2. FIFO 버퍼링
- **FIFO 기반** 데이터 버퍼링 구조
- 데이터 **손실 없이** Counter 제어 정상 동작

### 3. Counter & FSM
- **Counter 및 FSM** 기반 데이터 제어
- **UART → FIFO → Counter** 데이터 처리 파이프라인

### 4. 검증 환경
- **UART 연속 데이터 입력 환경**에서 FIFO 오버플로우 없이 안정적 동작 확인
- **FIFO 버퍼링**을 통해 데이터 손실 없이 Counter 제어 정상 동작 검증
- **UART-FIFO-Counter** 전체 데이터 경로를 FPGA 환경에서 안정적으로 검증

---

## 🏗️ 시스템 아키텍처

```
┌─────────────┐      ┌──────────┐      ┌──────────────┐     ┌─────────────┐
│   UART RX   │────▶│   FIFO   │────▶│   Counter    │────▶│  UART TX    │
│   Module    │      │  Buffer  │      │   & FSM      │     │   Module    │
└─────────────┘      └──────────┘      └──────────────┘     └─────────────┘
      ▲                                                            │
      │                                                            │
      └────────────────────────────────────────────────────────────┘
                          Data Flow Pipeline
```

### 📊 TOP Block Diagram
![Block Diagram](./images/top_block_diagram.png)
*(이미지 파일이 있다면 images 폴더에 넣어주세요)*

---

## 🔧 개발 환경

| 항목 | 사양 |
|------|------|
| **Language** | SystemVerilog, Verilog |
| **Tool** | Vivado, VCS (Simulation) |
| **FPGA** | Basys3 (Xilinx) |
| **Testbench** | SystemVerilog Testbench |
| **Verification** | Functional Coverage, Mailbox |

---

## 📈 성능 지표

### ✅ 검증 결과
- **약 500회 랜덤 시뮬레이션**으로 Functional Coverage **99.7%** 확보
- **Counter 최대 9999 범위**에서 정상 증가/감소/정지 동작 확인
- 버튼 및 PC Command 입력 **(RUN/STOP, CLEAR, MODE, SETHZ)**에 따라 카운터 제어
- **Golden/Actual** 비교 자동화로 **Pass/Fail 검증 체계** 확립

### 🐛 Trouble Shooting

#### 1. 문제: 무한 시뮬레이션 발생 문제
- **원인**: Testbench에서 **트랜잭션 종료 조건이 명확하지 않아** 시뮬레이션이 종료되지 않음
- **해결**: **조건 기반 종료 제어**를 추가해 시뮬레이션 정상 종료로 개선

#### 2. 문제: 나눗셈 연산으로 인한 자원/타이밍 문제
- **원인**: Counter 제어 로직에서 **나눗셈 연산 사용 시 LUT 사용량 증가** 및 타이밍 이슈 발생
- **해결**: **case 문** 기반 비교 구조로 변경하여 **LUT 사용량 약 30% 감소**

---

## 📁 프로젝트 구조

```
UART-FIFO-Counter/
├── rtl/                    # RTL 소스 코드
│   ├── uart_rx.v
│   ├── uart_tx.v
│   ├── fifo.v
│   ├── counter.v
│   ├── fsm_controller.v
│   ├── top.v
│   └── basys3.xdc
├── tb/                     # Testbench 파일
│   ├── tb_top.sv
│   └── testbench.sv
├── images/                 # 문서용 이미지
└── README.md
```

---

## 🚀 사용 방법

### 1. 시뮬레이션 실행
```bash
# VCS 시뮬레이션
vcs -sverilog -full64 -R \
    rtl/*.v tb/tb_top.sv \
    -debug_access+all
```

### 2. FPGA 합성
```tcl
# Vivado에서
source build.tcl
```

### 3. PC와 FPGA 통신
```bash
# Python 등으로 Serial 통신
# Baud Rate: 9600
# Data: 8bit, Stop: 1bit, Parity: None
```

---

## 📚 참고 자료

- [UART Protocol Specification](https://www.ti.com/lit/ug/sprugp1/sprugp1.pdf)
- [Basys3 Reference Manual](https://digilent.com/reference/programmable-logic/basys-3/reference-manual)
- SystemVerilog for Verification (Chris Spear)

---

## 👤 Author

**이서영 (Lee Seoyoung)**
- 📧 Email: lsy1922@naver.com
- 🔗 GitHub: [@seoY0206](https://github.com/seoY0206)

---

## 📝 License

This project is for educational purposes.

---

<div align="center">

**⭐ 도움이 되었다면 Star를 눌러주세요! ⭐**

</div>
