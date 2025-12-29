# UART-FIFO-Counter_System
SystemVerilog-based data processing system integrating UART communication, FIFO buffering, and counter control on FPGA.

## ✨Overview
UART 통신을 통해 수신된 데이터를 FIFO로 버퍼링하고,  
Counter 및 제어 로직을 통해 데이터를 처리하는 FPGA 기반 데이터 처리 시스템입니다.

## ⚙️Tool & Language
- SystemVerilog  
- FPGA (Basys3)  
- UART Communication  
- Vivado  

## 🧱Architecture
- UART RX/TX 통신 모듈 설계  
- FIFO 기반 데이터 버퍼링 구조  
- Counter 및 FSM 기반 데이터 제어 로직  
- UART → FIFO → Counter 데이터 처리 파이프라인  

## 🪄Verification & Performance
- UART 연속 데이터 입력 환경에서 FIFO 오버플로우 없이 안정적 동작 확인  
- FIFO 버퍼링을 통해 데이터 손실 없이 Counter 제어 정상 동작 검증  
- UART–FIFO–Counter 전체 데이터 경로를 FPGA 환경에서 안정적으로 검증  

## 📍Key Features
- UART 기반 데이터 수신 및 제어 구조 구현  
- FIFO를 활용한 통신 지연 및 데이터 손실 방지  
- FSM 기반 데이터 흐름 제어  
- FPGA 데이터 처리 파이프라인 설계 경험 확보
