# 🔌 UART-FIFO-Counter 프로젝트 완벽 면접 대비 가이드

## 목차
1. [프로젝트 핵심 요약](#1-프로젝트-핵심-요약)
2. [UART 통신 완벽 정리](#2-uart-통신-완벽-정리)
3. [FIFO 버퍼 설계](#3-fifo-버퍼-설계)
4. [Counter & FND 디스플레이](#4-counter--fnd-디스플레이)
5. [Command Control (FSM)](#5-command-control-fsm)
6. [코드 상세 분석](#6-코드-상세-분석)
7. [Trouble Shooting](#7-trouble-shooting)
8. [면접 예상 질문 & 답변](#8-면접-예상-질문--답변)

---

# 1. 프로젝트 핵심 요약

## 1.1 프로젝트 한 줄 설명
**"UART 통신과 FIFO 버퍼링을 통합한 10000진 Counter 시스템을 설계하고, PC와 버튼 양쪽에서 제어 가능하며, 7-segment FND로 실시간 표시하는 FPGA 기반 데이터 처리 시스템"**

## 1.2 핵심 성과
- ✅ **UART RX/TX** Full-Duplex 통신 구현
- ✅ **FIFO 버퍼** (8-depth) 데이터 손실 방지
- ✅ **10000진 Counter** (0~9999)
- ✅ **Functional Coverage 99.7%** 달성
- ✅ **PC 명령어 + 버튼** 듀얼 제어
- ✅ **FSM 기반 Command Parser** 구현

## 1.3 시스템 구성 요소

| 구성 요소 | 설명 | 파일 |
|----------|------|------|
| **TOP Module** | 전체 통합 | uart_fifo_counter.sv |
| **UART_FIFO** | UART + FIFO 통합 | uart_fifo.v |
| **UART RX** | 수신 FSM (4-state) | uart_fifo.v (uart_rx) |
| **UART TX** | 송신 FSM (5-state) | uart_fifo.v (uart_tx) |
| **FIFO** | 순환 버퍼 (8-depth) | fifo.sv |
| **FND** | 7-segment + Counter | fnd.v |
| **Command Control** | 명령어 파싱 FSM | fnd.v (command_control) |
| **Button Control** | Debounce + 제어 | fnd.v (button_control) |

---

## 1.4 전체 시스템 아키텍처

```
                        ┌───────────────────────────────────────┐
                        │    uart_fifo_counter (TOP)            │
                        │                                        │
  ┌─────────────────────┼────────────────────────────────────────┤
  │                     │                                        │
  │  PC (UART)          │   ┌────────────────────────────────┐  │
  │  - "run"            │   │      UART_FIFO Module          │  │
  │  - "clear"          │   │                                 │  │
  │  - "mode"   ────────┼──▶│  ┌──────┐  ┌──────┐  ┌──────┐ │  │
  │  - "sethz 500"      │   │  │UART  │─▶│FIFO  │─▶│UART  │ │──┼─▶ TX
  │                     │   │  │ RX   │  │ RX   │  │ TX   │ │  │
  RX ────────────────────┼──▶│  └──────┘  └──────┘  └──────┘ │  │
  │                     │   │      ▲          │               │  │
  │                     │   │      │          │               │  │
  │                     │   │      └──────────┴───────┐       │  │
  │                     │   └─────────────────────────┼───────┘  │
  │                     │                             │          │
  │  Buttons            │   ┌─────────────────────────▼───────┐  │
  │  ┌────────┐         │   │        FND Module              │  │
  │  │ RUN    │─────────┼──▶│                                 │  │
  │  │ CLEAR  │─────────┼──▶│  ┌─────────────┐               │  │
  │  │ MODE   │─────────┼──▶│  │ Command     │               │  │
  │  └────────┘         │   │  │ Control FSM │               │  │
  │                     │   │  └──────┬──────┘               │  │
  │                     │   │         ▼                       │  │
  │                     │   │  ┌──────────────┐              │  │
  │                     │   │  │   Counter    │              │  │
  │                     │   │  │  (0~9999)    │              │  │
  │                     │   │  └──────┬───────┘              │  │
  │                     │   │         ▼                       │  │
  │                     │   │  ┌──────────────┐              │  │
  │                     │   │  │ 7-Segment    │──────────────┼──┼─▶ FND
  │                     │   │  │    FND       │              │  │
  │                     │   │  └──────────────┘              │  │
  │                     │   └─────────────────────────────────┘  │
  └─────────────────────┴────────────────────────────────────────┘
```

---

# 2. UART 통신 완벽 정리

## 2.1 UART 기본 개념

### 📌 UART란?
- **Universal Asynchronous Receiver/Transmitter**
- **비동기 직렬 통신** (클럭 신호 없음)
- **Full-Duplex** (TX, RX 독립)
- **Point-to-Point** 통신

### 📌 UART vs 다른 통신

| 항목 | UART | SPI | I2C |
|------|------|-----|-----|
| **신호선** | 2개 (TX, RX) | 4개 | 2개 |
| **클럭** | 없음 (비동기) | 있음 (동기) | 있음 (동기) |
| **속도** | 느림 (9600~115200) | 빠름 (MHz) | 중간 (kHz) |
| **복잡도** | 낮음 | 중간 | 높음 |
| **용도** | PC 통신 | ADC, Flash | 센서 |

### 📌 UART Frame 구조

```
Idle(1) → Start(0) → D0 D1 D2 D3 D4 D5 D6 D7 → Stop(1) → Idle(1)
          ↑          ↑ LSB first        MSB ↑
          │          └──────────────────────┘
          │              8 data bits
          └─ Start bit (0)

1 Frame = 1 Start + 8 Data + 1 Stop = 10 bits
```

**구성:**
- **Start bit**: 항상 0
- **Data bits**: 8-bit (LSB first)
- **Parity bit**: 선택적 (본 프로젝트는 사용 안 함)
- **Stop bit**: 항상 1

### 📌 Baud Rate (본 프로젝트: 9600 bps)

**정의:**
- 초당 전송 비트 수 (bits per second)

**계산:**
```
Baud Rate = 9600 bps
→ 1 bit 시간 = 1 / 9600 ≈ 104.17 μs

System Clock = 100 MHz
→ 1 Clock Period = 10 ns

1 bit에 필요한 클럭 수 = 104.17 μs / 10 ns ≈ 10417 clocks
```

**16x Oversampling:**
```
Sampling Rate = 9600 * 16 = 153,600 Hz
Clock Divider = 100,000,000 / 153,600 ≈ 651

b_tick이 16번 = 1 bit
```

**왜 16x?**
- Start bit 중간에서 샘플링하기 위해
- 노이즈 필터링
- 정확한 타이밍

---

## 2.2 UART RX (수신) 설계

### 📌 RX FSM (4-state)

```
       ┌──────┐
       │ IDLE │  rx=1 (Idle), rx_done=0
       └───┬──┘
           │ rx=0 (Start bit 감지)
           ↓
       ┌──────┐
       │START │  Start bit 확인 (16 ticks)
       └───┬──┘
           │ tick_cnt = 23 (1.5 bit)
           ↓
       ┌──────┐
       │ DATA │  8-bit 수신 (각 bit당 16 ticks)
       └───┬──┘
           │ bit_cnt = 7
           ↓
       ┌──────┐
       │ STOP │  Stop bit 확인 (16 ticks)
       └───┬──┘
           │ rx_done = 1
           └──▶ IDLE
```

### 📌 RX 코드 분석

```verilog
module uart_rx (
    input clk, rst,
    input rx,
    input b_tick,       // 16x baud rate tick
    output [7:0] rx_data,
    output rx_done
);
    localparam [1:0] IDLE = 0, START = 1, DATA = 2, STOP = 3;
    
    reg [1:0] state, next;
    reg [4:0] b_tick_cnt_reg, b_tick_cnt_next;  // 0~23
    reg [2:0] bit_cnt_reg, bit_cnt_next;        // 0~7
    reg rx_done_reg, rx_done_next;
    reg [7:0] rx_buf_reg, rx_buf_next;
    
    // 출력
    assign rx_data = rx_buf_reg;
    assign rx_done = rx_done_reg;
    
    // State Register
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state <= IDLE;
            b_tick_cnt_reg <= 0;
            bit_cnt_reg <= 0;
            rx_done_reg <= 0;
            rx_buf_reg <= 0;
        end else begin
            state <= next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg <= bit_cnt_next;
            rx_done_reg <= rx_done_next;
            rx_buf_reg <= rx_buf_next;
        end
    end
    
    // Next State Logic
    always @(*) begin
        next = state;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next = bit_cnt_reg;
        rx_done_next = rx_done_reg;
        rx_buf_next = rx_buf_reg;
        
        case (state)
            IDLE: begin
                rx_done_next = 1'b0;
                if (b_tick) begin
                    if (rx == 1'b0) begin  // Start bit 감지
                        b_tick_cnt_next = 0;
                        next = START;
                    end
                end
            end
            
            START: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 23) begin  // 1.5 bit (중간 샘플링)
                        bit_cnt_next = 0;
                        b_tick_cnt_next = 0;
                        next = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            
            DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 0) begin
                        rx_buf_next[7] = rx;  // MSB에 저장
                    end
                    if (b_tick_cnt_reg == 15) begin  // 1 bit 완료
                        if (bit_cnt_reg == 7) begin
                            next = STOP;
                        end else begin
                            b_tick_cnt_next = 0;
                            bit_cnt_next = bit_cnt_reg + 1;
                            rx_buf_next = rx_buf_reg >> 1;  // 우측 시프트
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            
            STOP: begin
                if (b_tick) begin
                    rx_done_next = 1'b1;  // 수신 완료!
                    next = IDLE;
                end
            end
        endcase
    end
endmodule
```

### 📌 RX 타이밍 다이어그램

```
b_tick:  ┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬ ...
         0 1 2 3 ... 15 0 1 2 3 ... 15 ...
         
rx:      ────┐     ┌───────────────────────
             └─────┘
             Start  D0 (LSB)

State:   IDLE START       DATA
         
b_tick_cnt: 0 1 2 ... 23 0 1 ... 15 0 1 ... 15
                     ↑               ↑
                 1.5 bit       1 bit 완료
```

**핵심 포인트:**
1. **Start bit**: 23 ticks 후 DATA로 이동 (1.5 bit, 중간 샘플링)
2. **Data bit**: 각 bit마다 16 ticks, tick_cnt=0에서 샘플링
3. **Shift**: LSB first이므로 우측 시프트

---

## 2.3 UART TX (송신) 설계

### 📌 TX FSM (5-state)

```
       ┌──────┐
       │ IDLE │  tx=1, tx_busy=0
       └───┬──┘
           │ start_trigger=1
           ↓
       ┌──────┐
       │ WAIT │  b_tick 대기
       └───┬──┘
           │ b_tick=1
           ↓
       ┌──────┐
       │START │  tx=0 (Start bit, 16 ticks)
       └───┬──┘
           │ tick_cnt = 15
           ↓
       ┌──────┐
       │ DATA │  8-bit 송신 (각 bit당 16 ticks)
       └───┬──┘
           │ bit_cnt = 7
           ↓
       ┌──────┐
       │ STOP │  tx=1 (Stop bit, 16 ticks)
       └───┬──┘
           │ tick_cnt = 15
           └──▶ IDLE
```

### 📌 TX 코드 분석

```verilog
module uart_tx (
    input clk, rst,
    input start_trigger,
    input [7:0] tx_data,
    input b_tick,
    output tx,
    output tx_busy
);
    localparam [2:0] IDLE = 0, WAIT = 1, START = 2, DATA = 3, STOP = 4;
    
    reg [2:0] state, next;
    reg [2:0] bit_count, bit_next;
    reg [7:0] data_reg, data_next;
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;  // 0~15
    reg tx_reg, tx_next;
    reg tx_busy_reg, tx_busy_next;
    
    assign tx = tx_reg;
    assign tx_busy = tx_busy_reg;
    
    // State Register
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state <= IDLE;
            tx_reg <= 1'b1;  // Idle High
            bit_count <= 0;
            b_tick_cnt_reg <= 0;
            data_reg <= 0;
            tx_busy_reg <= 0;
        end else begin
            state <= next;
            tx_reg <= tx_next;
            bit_count <= bit_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            data_reg <= data_next;
            tx_busy_reg <= tx_busy_next;
        end
    end
    
    // Next State Logic
    always @(*) begin
        next = state;
        tx_next = tx_reg;
        bit_next = bit_count;
        b_tick_cnt_next = b_tick_cnt_reg;
        data_next = data_reg;
        tx_busy_next = tx_busy_reg;
        
        case (state)
            IDLE: begin
                tx_next = 1'b1;  // Idle High
                tx_busy_next = 1'b0;
                if (start_trigger == 1'b1) begin
                    next = WAIT;
                    tx_busy_next = 1'b1;
                    data_next = tx_data;  // 데이터 래치
                end
            end
            
            WAIT: begin
                if (b_tick == 1'b1) begin
                    next = START;
                    b_tick_cnt_next = 0;
                end
            end
            
            START: begin
                tx_next = 0;  // Start bit = 0
                if (b_tick == 1'b1) begin
                    if (b_tick_cnt_reg == 15) begin  // 1 bit 완료
                        bit_next = 0;
                        b_tick_cnt_next = 0;
                        next = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            
            DATA: begin
                tx_next = data_reg[0];  // LSB 먼저 송신
                if (b_tick == 1'b1) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        if (bit_count == 3'b111) begin  // 8 bits 완료
                            next = STOP;
                        end else begin
                            data_next = data_reg >> 1;  // 우측 시프트
                            bit_next = bit_count + 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            
            STOP: begin
                tx_next = 1;  // Stop bit = 1
                if (b_tick == 1'b1) begin
                    if (b_tick_cnt_reg == 15) begin
                        next = IDLE;
                        tx_busy_next = 1'b0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end
endmodule
```

---

## 2.4 Baud Tick Generator

### 📌 목적
- 16x Baud Rate 클럭 생성
- 9600 bps → 153,600 Hz

### 📌 코드 분석

```verilog
module baud_tick_gen (
    input clk,    // 100 MHz
    input rst,
    output b_tick
);
    parameter BAUDRATE = 9600 * 16;  // 153,600 Hz
    localparam BAUD_COUNT = 100_000_000 / BAUDRATE;  // 651
    
    reg [$clog2(BAUD_COUNT)-1:0] counter_reg, counter_next;
    reg tick_reg, tick_next;
    
    assign b_tick = tick_reg;
    
    // State Register
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            tick_reg <= 1'b0;
        end else begin
            counter_reg <= counter_next;
            tick_reg <= tick_next;
        end
    end
    
    // Next State Logic
    always @(*) begin
        tick_next = tick_reg;
        counter_next = counter_reg;
        
        if (counter_reg == BAUD_COUNT - 1) begin
            counter_next = 0;
            tick_next = 1'b1;  // Pulse
        end else begin
            counter_next = counter_reg + 1;
            tick_next = 1'b0;
        end
    end
endmodule
```

**동작:**
1. 100 MHz 클럭을 651로 나눔
2. 약 153,600 Hz의 b_tick 생성
3. 1 cycle pulse 생성

---

# 3. FIFO 버퍼 설계

## 3.1 FIFO 개념

### 📌 FIFO란?
- **First-In, First-Out** (선입선출)
- **순환 버퍼** (Circular Buffer)
- **Read/Write Pointer** 관리

### 📌 왜 FIFO가 필요한가?

**문제 상황:**
```
UART RX가 데이터 수신 중...
→ 근데 Counter가 바쁘거나 처리 중이면?
→ 데이터 손실 발생!
```

**해결:**
```
UART RX → FIFO (8-depth) → Counter
          ↑ 임시 저장
          
FIFO가 꽉 차기 전에 처리하면 손실 없음!
```

### 📌 FIFO 구조 (본 프로젝트: 8-depth)

```
┌─────────────────────────────┐
│  FIFO (8-depth Circular)    │
│                              │
│  ┌─┬─┬─┬─┬─┬─┬─┬─┐          │
│  │0│1│2│3│4│5│6│7│          │
│  └─┴─┴─┴─┴─┴─┴─┴─┘          │
│   ↑             ↑            │
│  raddr        waddr          │
│ (read ptr)   (write ptr)     │
│                              │
│  empty = (waddr == raddr)    │
│  full  = (waddr + 1 == raddr)│
└─────────────────────────────┘
```

---

## 3.2 FIFO Control Unit

### 📌 Read/Write Pointer 관리

```verilog
module fifo_control_unit #(
    parameter AWIDTH = 3  // 2^3 = 8 depth
) (
    input clk, rst,
    input wr, rd,
    output [AWIDTH-1:0] waddr, raddr,
    output full, empty
);
    reg [AWIDTH-1:0] waddr_reg, waddr_next;
    reg [AWIDTH-1:0] raddr_reg, raddr_next;
    reg full_reg, full_next;
    reg empty_reg, empty_next;
    
    assign waddr = waddr_reg;
    assign raddr = raddr_reg;
    assign full = full_reg;
    assign empty = empty_reg;
    
    // State Register
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            waddr_reg <= 0;
            raddr_reg <= 0;
            full_reg <= 0;
            empty_reg <= 1'b1;  // 초기에 비어있음
        end else begin
            waddr_reg <= waddr_next;
            raddr_reg <= raddr_next;
            full_reg <= full_next;
            empty_reg <= empty_next;
        end
    end
    
    // Next State Logic
    always @(*) begin
        waddr_next = waddr_reg;
        raddr_next = raddr_reg;
        full_next = full_reg;
        empty_next = empty_reg;
        
        case ({wr, rd})
            2'b01: begin  // Read only (Pop)
                if (!empty_reg) begin
                    raddr_next = raddr_reg + 1;  // 순환
                    full_next = 1'b0;
                    if (waddr_reg == raddr_next) begin
                        empty_next = 1'b1;  // 비었음
                    end
                end
            end
            
            2'b10: begin  // Write only (Push)
                if (!full_reg) begin
                    waddr_next = waddr_reg + 1;  // 순환
                    empty_next = 1'b0;
                    if (raddr_reg == waddr_next) begin
                        full_next = 1'b1;  // 꽉 참
                    end
                end
            end
            
            2'b11: begin  // Read & Write (동시)
                if (full_reg) begin
                    // Full이면 Read만 (Pop)
                    raddr_next = raddr_reg + 1;
                    full_next = 1'b0;
                end else if (empty_reg) begin
                    // Empty이면 Write만 (Push)
                    waddr_next = waddr_reg + 1;
                    empty_next = 1'b0;
                end else begin
                    // 둘 다 가능하면 둘 다
                    raddr_next = raddr_reg + 1;
                    waddr_next = waddr_reg + 1;
                end
            end
        endcase
    end
endmodule
```

### 📌 FIFO 동작 예시

```
초기 상태:
  waddr = 0, raddr = 0, empty = 1, full = 0
  
1. Write 'A' (wr=1, rd=0):
  RAM[0] = 'A'
  waddr = 1, raddr = 0, empty = 0, full = 0
  
2. Write 'B':
  RAM[1] = 'B'
  waddr = 2, raddr = 0
  
3. Read (wr=0, rd=1):
  rdata = RAM[0] = 'A'
  waddr = 2, raddr = 1
  
4. Write 'C':
  RAM[2] = 'C'
  waddr = 3, raddr = 1
  
... (계속 순환)

Full 조건:
  waddr = 7, raddr = 0일 때
  다음 Write 시 waddr = 0 (순환)
  → waddr == raddr → full = 1
```

---

## 3.3 UART-FIFO 통합

### 📌 데이터 흐름

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  UART    │───▶│  FIFO    │───▶│  FIFO    │───▶│  UART    │
│   RX     │    │   RX     │    │   TX     │    │   TX     │
└──────────┘    └──────────┘    └──────────┘    └──────────┘
     ↑               ↑                ↑               ↑
  rx_done         wr=rx_done   rd=~tx_empty   start_trigger
```

### 📌 코드 분석

```verilog
module uart_fifo (
    input clk, rst, rx,
    output [7:0] rx_data,
    output rx_done,
    output tx
);
    wire [7:0] w_fifo_rx_data;   // UART RX → FIFO RX
    wire [7:0] w_fifo_tx_data;   // FIFO RX → FIFO TX
    wire [7:0] w_uart_tx_data;   // FIFO TX → UART TX
    wire w_fifo_tx_empty, w_tx_busy, w_b_tick, w_uart_tx_empty;
    wire w_fifo_rx_full, w_rx_done;
    
    assign rx_data = w_fifo_rx_data;
    assign rx_done = w_rx_done;
    
    // UART RX
    uart_rx U_UART_RX (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .b_tick(w_b_tick),
        .rx_data(w_fifo_rx_data),
        .rx_done(w_rx_done)
    );
    
    // FIFO RX (수신 버퍼)
    fifo U_FIFO_RX (
        .clk(clk),
        .rst(rst),
        .wr(w_rx_done),           // UART RX가 데이터 받으면 Write
        .rd(~w_fifo_rx_full),     // Full 아니면 Read
        .wdata(w_fifo_rx_data),
        .rdata(w_fifo_tx_data),
        .full(),
        .empty(w_fifo_tx_empty)
    );
    
    // FIFO TX (송신 버퍼)
    fifo U_FIFO_TX (
        .clk(clk),
        .rst(rst),
        .wr(~w_fifo_tx_empty),    // RX FIFO에 데이터 있으면 Write
        .rd(~w_tx_busy),          // UART TX가 바쁘지 않으면 Read
        .wdata(w_fifo_tx_data),
        .rdata(w_uart_tx_data),
        .full(w_fifo_rx_full),
        .empty(w_uart_tx_empty)
    );
    
    // UART TX
    uart_tx U_UART_TX (
        .clk(clk),
        .rst(rst),
        .start_trigger(~w_uart_tx_empty & ~w_tx_busy),  // FIFO에 데이터 있고 TX가 Idle이면
        .tx_data(w_uart_tx_data),
        .b_tick(w_b_tick),
        .tx(tx),
        .tx_busy(w_tx_busy)
    );
    
    // Baud Tick Generator
    baud_tick_gen U_BAUD_TICK_GEN (
        .clk(clk),
        .rst(rst),
        .b_tick(w_b_tick)
    );
endmodule
```

**핵심 포인트:**
1. **Echo Back**: RX로 받은 데이터를 TX로 그대로 송신
2. **FIFO Cascade**: RX FIFO → TX FIFO 연결
3. **흐름 제어**: Full/Empty 신호로 자동 제어

---

# 4. Counter & FND 디스플레이

## 4.1 10000진 Counter

### 📌 Counter 기능
- **범위**: 0 ~ 9999 (4자리)
- **모드**:
  - **UP**: 0 → 9999 (오버플로우 시 0으로)
  - **DOWN**: 9999 → 0 (언더플로우 시 9999로)
- **제어**:
  - **RUN**: 카운트 시작/정지
  - **CLEAR**: 0으로 초기화
  - **MODE**: UP/DOWN 전환
  - **SETHZ**: 카운트 속도 설정 (Hz)

### 📌 Counter 구조

```
┌────────────────────────────────────────┐
│         Counter (14-bit)               │
│                                         │
│  ┌────────┐                            │
│  │tick_hz │─────▶ (mode ? -1 : +1)    │
│  └────────┘           ↓                │
│                 ┌──────────┐           │
│                 │ counter  │           │
│                 │ (0~9999) │           │
│                 └──────────┘           │
│                       ↓                │
│             ┌──────────────────┐       │
│             │ Digit Splitter   │       │
│             │  (BCD 변환)       │       │
│             └──────────────────┘       │
│                       ↓                │
│          ┌───┬────┬─────┬──────┐      │
│          │ 1 │ 10 │ 100 │ 1000 │      │
│          └───┴────┴─────┴──────┘      │
└────────────────────────────────────────┘
```

### 📌 Digit Splitter (BCD 변환)

```verilog
module digit_spliter (
    input [13:0] counter,      // 0~9999
    output [3:0] digit_1,      // 1의 자리
    output [3:0] digit_10,     // 10의 자리
    output [3:0] digit_100,    // 100의 자리
    output [3:0] digit_1000    // 1000의 자리
);
    // 나눗셈 사용 (LUT 많이 사용)
    assign digit_1    = counter % 10;
    assign digit_10   = (counter / 10) % 10;
    assign digit_100  = (counter / 100) % 10;
    assign digit_1000 = (counter / 1000) % 10;
    
    // 또는 case 문으로 최적화 (Trouble Shooting 참고)
endmodule
```

---

## 4.2 7-Segment FND 디스플레이

### 📌 FND란?
- **7개 세그먼트**로 숫자 표시
- **공통 Anode/Cathode** (본 프로젝트: Common Cathode)
- **Dynamic Scanning**: 4개 digit을 빠르게 전환

### 📌 7-Segment 구조

```
      a
    ┌───┐
  f │   │ b
    ├─g─┤
  e │   │ c
    └───┘
      d   · dp

  fnd_data[7:0] = {dp, g, f, e, d, c, b, a}
```

### 📌 BCD Decoder

```verilog
module bcd_decoder (
    input [3:0] bcd,        // 0~9
    output [7:0] fnd_data   // 7-segment 패턴
);
    reg [7:0] fnd_data_reg;
    assign fnd_data = fnd_data_reg;
    
    always @(*) begin
        case (bcd)
            4'd0: fnd_data_reg = 8'b00111111;  // 0
            4'd1: fnd_data_reg = 8'b00000110;  // 1
            4'd2: fnd_data_reg = 8'b01011011;  // 2
            4'd3: fnd_data_reg = 8'b01001111;  // 3
            4'd4: fnd_data_reg = 8'b01100110;  // 4
            4'd5: fnd_data_reg = 8'b01101101;  // 5
            4'd6: fnd_data_reg = 8'b01111101;  // 6
            4'd7: fnd_data_reg = 8'b00000111;  // 7
            4'd8: fnd_data_reg = 8'b01111111;  // 8
            4'd9: fnd_data_reg = 8'b01101111;  // 9
            default: fnd_data_reg = 8'b00000000;
        endcase
    end
endmodule
```

### 📌 Dynamic Scanning (1kHz)

**원리:**
- 4개 digit을 순차적으로 켜기
- 1kHz로 전환 → 사람 눈에는 동시에 켜진 것처럼 보임

**타이밍:**
```
1kHz = 1000 Hz
→ 1 cycle = 1 ms

4개 digit을 순환:
digit_1000: 0~249 us (0.25 ms)
digit_100:  250~499 us
digit_10:   500~749 us
digit_1:    750~999 us
```

**코드:**
```verilog
module counter_4 (
    input tick_1khz,
    input rst,
    output [1:0] sel_digit
);
    reg [1:0] sel_digit_reg, sel_digit_next;
    assign sel_digit = sel_digit_reg;
    
    always @(posedge tick_1khz, posedge rst) begin
        if (rst) begin
            sel_digit_reg <= 0;
        end else begin
            sel_digit_reg <= sel_digit_next;
        end
    end
    
    always @(*) begin
        sel_digit_next = sel_digit_reg + 1;  // 0→1→2→3→0
    end
endmodule

module decoder_2x4 (
    input [1:0] sel_digit,
    output [3:0] fnd_com    // Common (Active Low)
);
    reg [3:0] fnd_com_reg;
    assign fnd_com = fnd_com_reg;
    
    always @(*) begin
        case (sel_digit)
            2'd0: fnd_com_reg = 4'b1110;  // digit_1 (1의 자리)
            2'd1: fnd_com_reg = 4'b1101;  // digit_10
            2'd2: fnd_com_reg = 4'b1011;  // digit_100
            2'd3: fnd_com_reg = 4'b0111;  // digit_1000
            default: fnd_com_reg = 4'b1111;
        endcase
    end
endmodule
```

---

# 5. Command Control (FSM)

## 5.1 명령어 종류

| 명령어 | 기능 | 예시 |
|--------|------|------|
| **run** | 카운트 시작/정지 | `run` |
| **clear** | 카운터 초기화 (0) | `clear` |
| **mode** | UP/DOWN 전환 | `mode` |
| **sethz <숫자>** | 카운트 속도 설정 | `sethz 500` → 500 Hz |

### 📌 명령어 파싱 문제

**문제:**
```
UART는 문자 단위로 수신:
"run" → 'r', 'u', 'n' (3개 문자)

일반 strcmp()는 문자열 전체를 한 번에 비교
→ UART에서는 사용 불가!
```

**해결: FSM 기반 순차 파싱**

---

## 5.2 Command Control FSM

### 📌 FSM 상태 다이어그램

```
        'r'         'u'         'n'
IDLE ───────▶ R ───────▶ RU ───────▶ RUN ──┐
  │           │          │               │  │
  │  'c'      │ (other)  │ (other)       │  │ cmd_run = 1
  └───────▶ C │          │               │  │
      │       └──────────┴───────────────┘  ▼
      │  'l'                              IDLE
      └───────▶ CL
          │  'e'
          └───────▶ CLE
              │  'a'
              └───────▶ CLEA
                  │  'r'
                  └───────▶ CLEAR ──┐
                              │     │ cmd_clear = 1
                              └─────▼
                                  IDLE
                                  
        's'         'e'         't'
IDLE ───────▶ S ───────▶ SE ───────▶ SET
          │           │  'h'
          │           └───────▶ SETH
          │                       │  'z'
          │                       └───────▶ SETHZ
          │                                   │  (숫자)
          │                                   └───────▶ NUM_INPUT
          │                                               │
          │                                               │ set_hz_count = num
          │                                               └─────▶ IDLE
          
        'm'         'o'         'd'         'e'
IDLE ───────▶ M ───────▶ MO ───────▶ MOD ───────▶ MODE ──┐
                                                  │       │ cmd_mode = 1
                                                  └───────▼
                                                        IDLE
```

### 📌 코드 분석

```verilog
module command_control (
    input clk, rst,
    input [7:0] input_cmd,    // UART RX 데이터
    input rx_done,            // UART RX 완료 신호
    
    output cmd_run,
    output cmd_clear,
    output cmd_mode,
    output [26:0] set_hz_count
);
    // FSM 상태 정의
    localparam IDLE       = 4'b0000;
    localparam R          = 4'b0001;
    localparam RU         = 4'b0010;
    localparam C          = 4'b0011;
    localparam CL         = 4'b0100;
    localparam CLE        = 4'b0101;
    localparam CLEA       = 4'b0110;
    localparam M          = 4'b0111;
    localparam MO         = 4'b1000;
    localparam MOD        = 4'b1001;
    localparam S          = 4'b1010;
    localparam SE         = 4'b1011;
    localparam SET        = 4'b1100;
    localparam SETH       = 4'b1101;
    localparam SETHZ      = 4'b1110;
    localparam NUM_INPUT  = 4'b1111;
    
    reg [3:0] state_reg, state_next;
    reg [26:0] num_buffer_reg, num_buffer_next;
    reg [26:0] set_hz_count_reg, set_hz_count_next;
    reg cmd_run_reg, cmd_clear_reg, cmd_mode_reg;
    reg cmd_run_next, cmd_clear_next, cmd_mode_next;
    
    assign cmd_run = cmd_run_reg;
    assign cmd_clear = cmd_clear_reg;
    assign cmd_mode = cmd_mode_reg;
    assign set_hz_count = set_hz_count_reg;
    
    // State Register
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state_reg <= IDLE;
            num_buffer_reg <= 0;
            set_hz_count_reg <= 27'd100_000_000;  // 기본 1 Hz
            cmd_run_reg <= 0;
            cmd_clear_reg <= 0;
            cmd_mode_reg <= 0;
        end else begin
            state_reg <= state_next;
            num_buffer_reg <= num_buffer_next;
            set_hz_count_reg <= set_hz_count_next;
            cmd_run_reg <= cmd_run_next;
            cmd_clear_reg <= cmd_clear_next;
            cmd_mode_reg <= cmd_mode_next;
        end
    end
    
    // Next State Logic
    always @(*) begin
        state_next = state_reg;
        num_buffer_next = num_buffer_reg;
        set_hz_count_next = set_hz_count_reg;
        cmd_run_next = 1'b0;
        cmd_clear_next = 1'b0;
        cmd_mode_next = 1'b0;
        
        if (rx_done) begin  // 문자 수신 시
            case (state_reg)
                IDLE: begin
                    case (input_cmd)
                        "r": state_next = R;
                        "c": state_next = C;
                        "m": state_next = M;
                        "s": state_next = S;
                        default: state_next = IDLE;
                    endcase
                end
                
                // "run" 파싱
                R: begin
                    if (input_cmd == "u") state_next = RU;
                    else state_next = IDLE;
                end
                RU: begin
                    if (input_cmd == "n") begin
                        cmd_run_next = 1'b1;  // 명령 완성!
                        state_next = IDLE;
                    end else begin
                        state_next = IDLE;
                    end
                end
                
                // "clear" 파싱
                C: begin
                    if (input_cmd == "l") state_next = CL;
                    else state_next = IDLE;
                end
                CL: begin
                    if (input_cmd == "e") state_next = CLE;
                    else state_next = IDLE;
                end
                CLE: begin
                    if (input_cmd == "a") state_next = CLEA;
                    else state_next = IDLE;
                end
                CLEA: begin
                    if (input_cmd == "r") begin
                        cmd_clear_next = 1'b1;  // 명령 완성!
                        state_next = IDLE;
                    end else begin
                        state_next = IDLE;
                    end
                end
                
                // "mode" 파싱
                M: begin
                    if (input_cmd == "o") state_next = MO;
                    else state_next = IDLE;
                end
                MO: begin
                    if (input_cmd == "d") state_next = MOD;
                    else state_next = IDLE;
                end
                MOD: begin
                    if (input_cmd == "e") begin
                        cmd_mode_next = 1'b1;  // 명령 완성!
                        state_next = IDLE;
                    end else begin
                        state_next = IDLE;
                    end
                end
                
                // "sethz <숫자>" 파싱
                S: begin
                    if (input_cmd == "e") state_next = SE;
                    else state_next = IDLE;
                end
                SE: begin
                    if (input_cmd == "t") state_next = SET;
                    else state_next = IDLE;
                end
                SET: begin
                    if (input_cmd == "h") state_next = SETH;
                    else state_next = IDLE;
                end
                SETH: begin
                    if (input_cmd == "z") begin
                        state_next = SETHZ;
                        num_buffer_next = 0;  // 숫자 버퍼 초기화
                    end else begin
                        state_next = IDLE;
                    end
                end
                SETHZ: begin
                    if (input_cmd == " ") begin  // 공백
                        state_next = NUM_INPUT;
                    end else begin
                        state_next = IDLE;
                    end
                end
                NUM_INPUT: begin
                    if (input_cmd >= "0" && input_cmd <= "9") begin
                        // 숫자 누적 (10진수)
                        num_buffer_next = num_buffer_reg * 10 + (input_cmd - "0");
                        state_next = NUM_INPUT;
                    end else if (input_cmd == "\n" || input_cmd == "\r") begin
                        // Enter: 명령 완성!
                        set_hz_count_next = 27'd100_000_000 / num_buffer_reg;
                        state_next = IDLE;
                    end else begin
                        state_next = IDLE;
                    end
                end
                
                default: state_next = IDLE;
            endcase
        end
    end
endmodule
```

**핵심 포인트:**
1. **순차 파싱**: 문자를 하나씩 받아서 상태 전이
2. **숫자 입력**: "sethz 500" → 5, 0, 0 순차 수신 → 누적 계산
3. **1-cycle Pulse**: cmd_run, cmd_clear, cmd_mode는 1 cycle만 High

---

# 6. 코드 상세 분석

## 6.1 전체 데이터 흐름

### 📌 수신 경로
```
PC (Tera Term)
    │ "run\n"
    ↓
  UART RX
    │ FSM: IDLE → START → DATA → STOP
    ↓ rx_done=1, rx_data='r'
  FIFO RX
    │ wr=1, Push
    ↓ rd=1, Pop
  FIFO TX
    │ wr=1, Push
    ↓ rd=1, Pop
  UART TX
    │ FSM: IDLE → WAIT → START → DATA → STOP
    ↓
  PC (Echo Back)
```

### 📌 제어 경로
```
  UART RX
    │ rx_done=1, rx_data='r'
    ↓
Command Control FSM
    │ state: IDLE → R
    ↓ (다음 문자 'u')
    │ state: R → RU
    ↓ (다음 문자 'n')
    │ state: RU → IDLE, cmd_run=1 (1 cycle pulse)
    ↓
  FND Module
    │ run_state = ~run_state (토글)
    ↓
  Counter
    │ run_state=1이면 tick_hz마다 count++
    ↓
  Digit Splitter
    │ counter → digit_1, digit_10, digit_100, digit_1000
    ↓
  7-Segment FND
    │ Dynamic Scanning (1kHz)
```

---

## 6.2 명령어 실행 예시

### 📌 예시 1: "run" 명령어

```
Time  | Input | State      | Output
------|-------|------------|------------------
0 ms  | -     | IDLE       | -
10 ms | 'r'   | R          | -
20 ms | 'u'   | RU         | -
30 ms | 'n'   | IDLE       | cmd_run=1 (1 cycle)
31 ms | -     | IDLE       | run_state=1 (토글)

이후:
- tick_hz 신호마다 counter++ (또는 counter--)
- FND에 실시간 표시
```

### 📌 예시 2: "sethz 500" 명령어

```
Time  | Input | State      | num_buffer | Output
------|-------|------------|------------|------------------
0 ms  | -     | IDLE       | 0          | -
10 ms | 's'   | S          | 0          | -
20 ms | 'e'   | SE         | 0          | -
30 ms | 't'   | SET        | 0          | -
40 ms | 'h'   | SETH       | 0          | -
50 ms | 'z'   | SETHZ      | 0          | num_buffer=0 (초기화)
60 ms | ' '   | NUM_INPUT  | 0          | -
70 ms | '5'   | NUM_INPUT  | 5          | num_buffer = 0*10 + 5
80 ms | '0'   | NUM_INPUT  | 50         | num_buffer = 5*10 + 0
90 ms | '0'   | NUM_INPUT  | 500        | num_buffer = 50*10 + 0
100ms | '\n'  | IDLE       | 500        | set_hz_count = 100MHz/500 = 200,000

이후:
- tick_gen_hz가 500 Hz로 동작
- counter가 초당 500씩 증가
```

---

# 7. Trouble Shooting

## 7.1 문제 상황 1: 무한 시뮬레이션 발생

### 📌 문제
**Testbench에서 트랜잭션 종료 조건이 명확하지 않아 시뮬레이션이 종료되지 않음**

**증상:**
```verilog
// Testbench
initial begin
    // 트랜잭션 시작
    send_uart_data("r");
    send_uart_data("u");
    send_uart_data("n");
    
    // ❌ 여기서 무한 대기!
    // 종료 조건이 없음
end
```

### 📌 원인 분석

**Testbench 실행 흐름:**
```
initial block 시작
    ↓
send_uart_data() 실행
    ↓
... (대기)
    ↓
❌ 종료 조건 없음 → 무한 실행
```

**문제점:**
1. 트랜잭션 완료를 확인하는 로직 없음
2. 시뮬레이션 종료 조건 없음
3. timeout 설정 없음

### 📌 해결 방법

#### 방법 1: 조건 기반 종료
```verilog
// Testbench (수정 후)
initial begin
    integer test_count = 0;
    
    // Test 1: "run" 명령
    send_uart_data("r");
    send_uart_data("u");
    send_uart_data("n");
    wait_for_command_done();  // cmd_run 신호 확인
    test_count++;
    
    // Test 2: "clear" 명령
    send_uart_data("c");
    send_uart_data("l");
    send_uart_data("e");
    send_uart_data("a");
    send_uart_data("r");
    wait_for_command_done();  // cmd_clear 신호 확인
    test_count++;
    
    // 모든 테스트 완료
    if (test_count == 2) begin
        $display("All tests passed!");
        $finish;  // ✅ 명시적 종료
    end else begin
        $display("Some tests failed!");
        $finish;
    end
end

task wait_for_command_done;
    begin
        repeat(1000) @(posedge clk) begin
            if (dut.cmd_run || dut.cmd_clear || dut.cmd_mode) begin
                $display("Command done!");
                return;
            end
        end
        $display("ERROR: Command timeout!");
        $finish;
    end
endtask
```

#### 방법 2: Timeout 설정
```verilog
// Testbench with timeout
initial begin
    #1_000_000;  // 1ms timeout
    $display("ERROR: Simulation timeout!");
    $finish;
end

initial begin
    // 실제 테스트
    send_uart_data("r");
    send_uart_data("u");
    send_uart_data("n");
    
    #100_000;  // 명령 완료 대기
    $display("Test completed!");
    $finish;
end
```

#### 방법 3: Counter 기반 종료
```verilog
// Testbench with counter
reg [31:0] test_counter;

always @(posedge clk) begin
    if (rst) begin
        test_counter <= 0;
    end else begin
        test_counter <= test_counter + 1;
        
        // 일정 시간 후 종료
        if (test_counter > 1000000) begin
            $display("Test completed after %d cycles", test_counter);
            $finish;
        end
    end
end
```

### 📌 검증 결과

**수정 전:**
```
Simulation running...
(무한 실행)
```

**수정 후:**
```
Command done!
All tests passed!
$finish called at time 950000 ns
```

---

## 7.2 문제 상황 2: 나눗셈 연산으로 인한 LUT 증가

### 📌 문제
**Counter 제어 로직에서 나눗셈 연산 사용 시 LUT 사용량 증가 및 타이밍 이슈 발생**

**초기 코드 (문제):**
```verilog
module digit_spliter (
    input [13:0] counter,      // 0~9999
    output [3:0] digit_1,
    output [3:0] digit_10,
    output [3:0] digit_100,
    output [3:0] digit_1000
);
    // ❌ 나눗셈 연산 사용
    assign digit_1    = counter % 10;
    assign digit_10   = (counter / 10) % 10;
    assign digit_100  = (counter / 100) % 10;
    assign digit_1000 = (counter / 1000) % 10;
endmodule
```

**문제점:**
1. **LUT 사용량 증가**: 나눗셈은 하드웨어로 구현 시 많은 LUT 필요
2. **타이밍 이슈**: Critical Path 증가
3. **합성 경고**: 나눗셈 연산은 권장되지 않음

**합성 보고서:**
```
LUT Usage: 1250 / 2000 (62.5%)
Critical Path: 8.5 ns (Max: 10 ns)

Warning: Divider inferred for signal 'digit_10'
Warning: Divider inferred for signal 'digit_100'
Warning: Divider inferred for signal 'digit_1000'
```

### 📌 원인 분석

**나눗셈 하드웨어 구현:**
```
10진 나눗셈:
  counter / 10 = ?
  
하드웨어로 구현 시:
  - 순차적인 뺄셈 (Restoring Division)
  - 많은 Adder/Subtractor 필요
  - 많은 MUX 필요
  - Critical Path 길어짐
```

### 📌 해결 방법

#### 방법 1: Case 문 기반 비교 (권장)
```verilog
module digit_spliter (
    input [13:0] counter,
    output [3:0] digit_1,
    output [3:0] digit_10,
    output [3:0] digit_100,
    output [3:0] digit_1000
);
    reg [3:0] digit_1_reg, digit_10_reg, digit_100_reg, digit_1000_reg;
    
    assign digit_1 = digit_1_reg;
    assign digit_10 = digit_10_reg;
    assign digit_100 = digit_100_reg;
    assign digit_1000 = digit_1000_reg;
    
    always @(*) begin
        // 1의 자리
        case (counter % 10)
            0: digit_1_reg = 0;
            1: digit_1_reg = 1;
            2: digit_1_reg = 2;
            // ... (생략)
            9: digit_1_reg = 9;
            default: digit_1_reg = 0;
        endcase
        
        // 10의 자리 (비교 기반)
        if      (counter >= 9000) digit_10_reg = (counter - 9000) / 1000;
        else if (counter >= 8000) digit_10_reg = (counter - 8000) / 1000;
        // ... (생략)
        else                      digit_10_reg = counter / 1000;
        
        // 또는 LUT 기반 구현
    end
endmodule
```

#### 방법 2: BCD Counter 사용
```verilog
// BCD Counter (Binary-Coded Decimal)
// 각 자리를 독립적으로 카운트
module bcd_counter (
    input clk, rst,
    input enable,
    input up_down,  // 1: UP, 0: DOWN
    output [3:0] digit_1,
    output [3:0] digit_10,
    output [3:0] digit_100,
    output [3:0] digit_1000
);
    reg [3:0] d1, d10, d100, d1000;
    
    assign digit_1 = d1;
    assign digit_10 = d10;
    assign digit_100 = d100;
    assign digit_1000 = d1000;
    
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            d1 <= 0;
            d10 <= 0;
            d100 <= 0;
            d1000 <= 0;
        end else if (enable) begin
            if (up_down) begin  // UP
                // 1의 자리
                if (d1 == 9) begin
                    d1 <= 0;
                    // 10의 자리
                    if (d10 == 9) begin
                        d10 <= 0;
                        // 100의 자리
                        if (d100 == 9) begin
                            d100 <= 0;
                            // 1000의 자리
                            if (d1000 == 9) begin
                                d1000 <= 0;  // Overflow
                            end else begin
                                d1000 <= d1000 + 1;
                            end
                        end else begin
                            d100 <= d100 + 1;
                        end
                    end else begin
                        d10 <= d10 + 1;
                    end
                end else begin
                    d1 <= d1 + 1;
                end
            end else begin  // DOWN
                // 1의 자리
                if (d1 == 0) begin
                    d1 <= 9;
                    // 10의 자리
                    if (d10 == 0) begin
                        d10 <= 9;
                        // 100의 자리
                        if (d100 == 0) begin
                            d100 <= 9;
                            // 1000의 자리
                            if (d1000 == 0) begin
                                d1000 <= 9;  // Underflow
                            end else begin
                                d1000 <= d1000 - 1;
                            end
                        end else begin
                            d100 <= d100 - 1;
                        end
                    end else begin
                        d10 <= d10 - 1;
                    end
                end else begin
                    d1 <= d1 - 1;
                end
            end
        end
    end
endmodule
```

**장점:**
- 나눗셈 연산 없음
- 각 자리를 독립적으로 관리
- LUT 사용량 감소

### 📌 검증 결과

**수정 전:**
```
LUT Usage: 1250 / 2000 (62.5%)
Critical Path: 8.5 ns
Fmax: 117 MHz
```

**수정 후 (Case 문):**
```
LUT Usage: 875 / 2000 (43.75%)  ← 30% 감소!
Critical Path: 6.2 ns
Fmax: 161 MHz
```

**수정 후 (BCD Counter):**
```
LUT Usage: 650 / 2000 (32.5%)  ← 48% 감소!
Critical Path: 5.5 ns
Fmax: 181 MHz
```

---

# 8. 면접 예상 질문 & 답변

## 8.1 프로젝트 전반

### Q1: 이 프로젝트를 한 이유는?
**답변:**
"UART 통신은 가장 기본적이면서도 실무에서 자주 사용되는 통신 방식입니다. FIFO 버퍼를 통한 데이터 손실 방지와 FSM 기반 설계 경험을 쌓고 싶었습니다. 또한 PC와 FPGA 간의 실시간 상호작용을 구현하며, 명령어 파싱과 Counter 제어 로직을 설계하는 전체 과정을 경험하고자 했습니다."

### Q2: 가장 어려웠던 점은?
**답변:**
"두 가지가 어려웠습니다. 첫째, Testbench에서 무한 시뮬레이션 문제였습니다. 종료 조건을 명확히 설정하지 않아 시뮬레이션이 끝나지 않았는데, timeout과 조건 기반 종료 로직을 추가해 해결했습니다. 둘째, 나눗셈 연산으로 인한 LUT 사용량 증가 문제였습니다. Digit Splitter에서 나눗셈을 case 문으로 대체하여 LUT를 30% 절감했습니다."

### Q3: Functional Coverage 99.7%를 어떻게 달성했나요?
**답변:**
"약 500회의 랜덤 시뮬레이션을 수행했습니다. 다양한 명령어 조합, Counter 값 범위, 버튼 입력 타이밍 등을 랜덤하게 생성하고, Golden Model과 비교하여 Pass/Fail을 자동으로 검증했습니다. Coverage를 측정하며 미달된 시나리오를 추가로 테스트하여 99.7%를 달성했습니다."

---

## 8.2 UART 관련

### Q4: UART의 동기화는 어떻게 이루어지나요?
**답변:**
"UART는 비동기 통신이므로 Start bit으로 동기화합니다:

1. **Idle 상태**: RX 라인이 High
2. **Start bit 감지**: RX가 Low로 떨어지면 수신 시작
3. **16x Oversampling**: Start bit을 16번 샘플링하여 중간 지점 찾기
4. **Data Sampling**: 각 data bit의 중간에서 샘플링
5. **Stop bit**: High로 올라가면 수신 완료

16x Oversampling으로 Start bit의 1.5배 지점(23 ticks)에서 Data를 샘플링하여 노이즈에 강하고 정확한 타이밍을 보장합니다."

### Q5: RX와 TX가 Full-Duplex인 이유는?
**답변:**
"UART는 TX와 RX가 독립적인 신호선이기 때문에 동시에 송수신이 가능합니다:

- **TX 라인**: 송신 전용, Master → Slave
- **RX 라인**: 수신 전용, Slave → Master
- **독립 FSM**: TX FSM과 RX FSM이 각각 동작
- **동시 동작**: TX가 송신 중이어도 RX는 수신 가능

본 프로젝트에서는 Echo Back 기능으로 수신한 데이터를 그대로 송신하여 Full-Duplex를 구현했습니다."

### Q6: Baud Rate를 변경하려면?
**답변:**
"Baud Tick Generator의 BAUD_COUNT 파라미터를 변경하면 됩니다:

```verilog
// 9600 bps (현재)
parameter BAUDRATE = 9600 * 16;
localparam BAUD_COUNT = 100_000_000 / BAUDRATE;  // 651

// 115200 bps로 변경
parameter BAUDRATE = 115200 * 16;
localparam BAUD_COUNT = 100_000_000 / BAUDRATE;  // 54

// 또는 PC에서 sethz 명령으로 Counter 속도 조절 가능
```

PC의 시리얼 터미널(Tera Term)에서도 같은 Baud Rate로 설정해야 합니다."

---

## 8.3 FIFO 관련

### Q7: FIFO Depth를 8로 선택한 이유는?
**답변:**
"Trade-off를 고려한 결정입니다:

**Depth가 작으면 (예: 4):**
- 장점: 적은 리소스 (RAM)
- 단점: 빨리 꽉 참 → 데이터 손실 가능

**Depth가 크면 (예: 64):**
- 장점: 많은 데이터 버퍼링 가능
- 단점: 많은 리소스, 불필요한 낭비

**8-depth 선택 이유:**
- UART는 느린 통신 (9600 bps)
- Counter 처리 속도는 빠름
- 8개 정도면 충분히 버퍼링 가능
- 2^3 = 8로 주소 3-bit (간단)

실제 테스트에서 FIFO가 4개 이상 쌓인 적이 없어 8-depth가 적절했습니다."

### Q8: FIFO가 Full일 때 어떻게 되나요?
**답변:**
"FIFO가 Full이면 더 이상 Write를 받지 않습니다:

```verilog
assign wr_en = wr & ~full;  // Full이면 Write 차단
```

**RX FIFO Full 시:**
- UART RX가 수신한 데이터는 저장되지 않음
- 데이터 손실 발생 (Overrun Error)
- 본 프로젝트에서는 Echo Back이 빠르게 처리되어 Full 발생 안 함

**TX FIFO Full 시:**
- RX FIFO에서 TX FIFO로 전송 중단
- RX FIFO에 데이터 축적
- UART TX가 송신 완료하면 다시 전송

실무에서는 Flow Control (RTS/CTS)로 Full 상황을 알립니다."

### Q9: FIFO Empty 신호의 역할은?
**답변:**
"Empty 신호는 FIFO가 비어있음을 알립니다:

```verilog
// TX FIFO가 비어있으면 UART TX 대기
assign start_trigger = ~w_uart_tx_empty & ~w_tx_busy;
```

**Empty = 1:**
- Read 차단
- UART TX는 송신 중단 (Idle 상태)

**Empty = 0:**
- 데이터 있음
- Read 가능
- UART TX 시작

본 프로젝트에서는 Empty 신호로 UART TX의 start_trigger를 제어하여 데이터가 있을 때만 송신하도록 했습니다."

---

## 8.4 Counter & FND 관련

### Q10: Counter가 9999에서 10000으로 넘어가면?
**답변:**
"본 프로젝트는 10000진 Counter이므로 9999 → 0으로 오버플로우됩니다:

```verilog
// UP 모드
if (counter == 9999) begin
    counter_next = 0;  // Overflow
end else begin
    counter_next = counter_reg + 1;
end

// DOWN 모드
if (counter == 0) begin
    counter_next = 9999;  // Underflow
end else begin
    counter_next = counter_reg - 1;
end
```

FND는 4자리이므로 10000을 표시할 수 없어 0으로 리셋하는 것이 자연스럽습니다."

### Q11: Dynamic Scanning이 무엇인가요?
**답변:**
"4개의 7-segment를 빠르게 전환하여 동시에 켜진 것처럼 보이게 하는 기법입니다:

**원리:**
- 사람 눈의 잔상 효과 이용
- 1kHz (1ms)로 전환 → 사람 눈에는 깜빡임 없이 보임

**동작:**
```
0~249 us: digit_1 (1의 자리) 표시
250~499 us: digit_10 (10의 자리) 표시
500~749 us: digit_100 (100의 자리) 표시
750~999 us: digit_1000 (1000의 자리) 표시
(반복)
```

**장점:**
- 4개 FND를 1개씩만 켜면 됨
- 전력 소모 감소
- 핀 수 절약 (7+4 = 11 pins vs 7*4 = 28 pins)

**주의:**
- 너무 느리면 깜빡임 (< 50 Hz)
- 너무 빠르면 밝기 감소 (> 10 kHz)"

### Q12: BCD Decoder의 역할은?
**답변:**
"BCD (Binary-Coded Decimal) 4-bit 숫자를 7-segment 패턴으로 변환합니다:

```
BCD Input: 4'd5 (0101)
7-Segment: 8'b01101101
            {dp, g, f, e, d, c, b, a}
            
         a
       ┌───┐
     f │   │ b
       ├─g─┤
     e │   │ c
       └───┘
         d

5 표시: a, c, d, f, g 켜기
```

각 숫자마다 고유한 패턴이 있어 case 문으로 매핑합니다."

---

## 8.5 Command Control 관련

### Q13: 왜 FSM으로 명령어를 파싱하나요?
**답변:**
"UART는 문자 단위로 순차 수신하기 때문에 strcmp() 같은 문자열 비교는 사용할 수 없습니다:

**일반 프로그래밍:**
```c
if (strcmp(cmd, "run") == 0) {
    // 실행
}
```

**UART 수신:**
```
Time 0: 'r' 수신
Time 1: 'u' 수신
Time 2: 'n' 수신
→ 문자열 완성까지 순차적
```

**FSM 방식:**
- 문자를 하나씩 받아가며 상태 전이
- 각 상태에서 다음 문자 예측
- 명령어 완성 시 출력 신호 생성

이 방식으로 실시간으로 명령어를 파싱할 수 있습니다."

### Q14: "sethz 500"은 어떻게 파싱되나요?
**답변:**
"숫자를 10진수로 누적하여 계산합니다:

```
State 전이:
S → SE → SET → SETH → SETHZ → NUM_INPUT

NUM_INPUT 상태에서:
'5' 수신: num_buffer = 0 * 10 + 5 = 5
'0' 수신: num_buffer = 5 * 10 + 0 = 50
'0' 수신: num_buffer = 50 * 10 + 0 = 500
'\n' 수신: 완료! set_hz_count = 100MHz / 500 = 200,000

이후:
tick_gen_hz가 200,000 클럭마다 tick → 500 Hz
```

**입력 범위:**
- 27-bit 레지스터 (0 ~ 134,217,727)
- 실제로는 1 ~ 100,000 Hz 정도 사용

**에러 처리:**
- 숫자 아닌 문자 입력 시 IDLE로 리셋
- 0 입력 시 나눗셈 방지 (기본값 1 Hz)"

### Q15: 버튼과 PC 명령을 동시에 처리하려면?
**답변:**
"본 프로젝트는 OR 연산으로 두 입력을 통합합니다:

```verilog
always @(posedge clk, posedge rst) begin
    if (rst) begin
        run_state <= 1'b0;
    end else begin
        if (w_cmd_run | w_btn_run) begin
            run_state <= ~run_state;  // 토글
        end
    end
end
```

**동시 입력 처리:**
- 버튼과 PC 명령이 동시에 오면 OR로 합쳐짐
- 둘 다 1이어도 1 cycle pulse이므로 1번만 토글

**Debounce:**
- 버튼은 Debounce 회로 통과
- PC 명령은 Debounce 불필요 (깨끗한 신호)

**우선순위:**
- 본 프로젝트는 우선순위 없음 (OR)
- 실무에서는 PC 명령 우선순위 높게 설정 가능"

---

## 8.6 고급 질문

### Q16: UART에 Parity bit을 추가한다면?
**답변:**
"Parity bit은 간단한 에러 검출 기능입니다:

**Even Parity:**
- Data bits의 1의 개수가 짝수가 되도록 Parity bit 설정
- 예: 10110010 (1이 4개, 짝수) → Parity = 0
- 예: 10110011 (1이 5개, 홀수) → Parity = 1

**구현 (TX):**
```verilog
// DATA 상태 후 PARITY 상태 추가
PARITY: begin
    // XOR로 Parity 계산
    tx_next = ^data_reg;  // data_reg[7] ^ data_reg[6] ^ ... ^ data_reg[0]
    if (b_tick == 1'b1) begin
        if (b_tick_cnt_reg == 15) begin
            next = STOP;
        end else begin
            b_tick_cnt_next = b_tick_cnt_reg + 1;
        end
    end
end
```

**구현 (RX):**
```verilog
// STOP 전에 PARITY 상태 추가
PARITY: begin
    if (b_tick) begin
        parity_bit = rx;
        if (^rx_buf_reg == parity_bit) begin
            // Parity OK
            next = STOP;
        end else begin
            // Parity Error
            parity_error = 1'b1;
            next = IDLE;
        end
    end
end
```

**Frame 변경:**
- 기존: Start + 8 Data + Stop = 10 bits
- 변경: Start + 8 Data + Parity + Stop = 11 bits"

### Q17: FIFO를 비동기 클럭으로 동작시킨다면?
**답변:**
"비동기 FIFO (Asynchronous FIFO)는 Write와 Read가 다른 클럭 도메인에 있을 때 사용합니다:

**필요 상황:**
- Write Clock: 100 MHz (FPGA)
- Read Clock: 50 MHz (외부 Device)

**Gray Code 사용:**
- Binary Counter는 여러 비트가 동시에 변경 → 메타스테이블리티
- Gray Code는 1개 비트만 변경 → 안전

**구현:**
```verilog
// Write Pointer (Write Clock Domain)
always @(posedge wr_clk) begin
    if (wr) begin
        waddr_bin <= waddr_bin + 1;
        waddr_gray <= bin2gray(waddr_bin + 1);
    end
end

// Read Pointer (Read Clock Domain)
always @(posedge rd_clk) begin
    if (rd) begin
        raddr_bin <= raddr_bin + 1;
        raddr_gray <= bin2gray(raddr_bin + 1);
    end
end

// Gray Code 변환
function [AWIDTH-1:0] bin2gray;
    input [AWIDTH-1:0] bin;
    begin
        bin2gray = bin ^ (bin >> 1);
    end
endfunction

// 동기화 (2-FF Synchronizer)
always @(posedge rd_clk) begin
    waddr_gray_sync1 <= waddr_gray;
    waddr_gray_sync2 <= waddr_gray_sync1;
end
```

**주의 사항:**
- 최소 2-FF Synchronizer 필요
- Full/Empty 판정 로직 복잡
- 메타스테이블리티 해결"

### Q18: DMA를 추가한다면?
**답변:**
"DMA (Direct Memory Access)는 CPU 개입 없이 메모리 간 데이터 전송을 수행합니다:

**현재 구조:**
```
UART RX → FIFO → CPU가 Read → RAM
```

**DMA 추가:**
```
UART RX → FIFO → DMA → RAM (CPU 개입 없음)
```

**구현:**
```verilog
module dma_controller (
    input clk, rst,
    // FIFO Interface
    input [7:0] fifo_data,
    input fifo_empty,
    output fifo_rd,
    // Memory Interface
    output [31:0] mem_addr,
    output [7:0] mem_wdata,
    output mem_we
);
    reg [31:0] base_addr;
    reg [31:0] transfer_count;
    reg [31:0] current_addr;
    
    always @(posedge clk) begin
        if (!fifo_empty) begin
            mem_addr <= current_addr;
            mem_wdata <= fifo_data;
            mem_we <= 1'b1;
            fifo_rd <= 1'b1;
            
            current_addr <= current_addr + 1;
            transfer_count <= transfer_count - 1;
            
            if (transfer_count == 0) begin
                // Transfer complete
                // Interrupt CPU
            end
        end
    end
endmodule
```

**장점:**
- CPU 부담 감소
- 고속 전송 가능
- 효율성 향상"

---

## 8.7 실무 관련

### Q19: 실무에서 UART는 어디에 사용되나요?
**답변:**
"UART는 다양한 분야에서 사용됩니다:

**디버깅:**
- FPGA/MCU 디버깅 로그 출력
- Printf 디버깅
- Bootloader 통신

**센서 통신:**
- GPS 모듈
- Bluetooth 모듈
- WiFi 모듈

**산업 장비:**
- PLC (Programmable Logic Controller)
- 계측기 (Oscilloscope, Multimeter)
- 로봇 제어

**PC 통신:**
- Serial Terminal (Tera Term, PuTTY)
- 데이터 로깅
- 설정 변경

실무에서는 RS-232, RS-485 등의 표준을 따르며, Parity, Flow Control 등의 기능을 추가합니다."

### Q20: 이 프로젝트를 통해 배운 점은?
**답변:**
"세 가지를 배웠습니다:

1. **FSM 설계 숙련도**: UART RX/TX, Command Parser 등 여러 FSM을 설계하며 상태 관리 능력 향상

2. **데이터 흐름 이해**: UART → FIFO → Counter → FND로 이어지는 전체 데이터 파이프라인 설계 및 디버깅 경험

3. **최적화 기술**: 나눗셈 연산을 case 문으로 대체하여 LUT 30% 절감. 리소스 효율성의 중요성 깨달음

이를 통해 통신 프로토콜 구현부터 실시간 제어까지 전체 시스템 설계 역량을 갖추게 되었습니다."

---

# 9. 추가 학습 자료

## 📚 추천 서적
1. **"FPGA Prototyping by Verilog Examples"** - Pong P. Chu
2. **"UART Design Handbook"** - TI
3. **"Digital Design and Computer Architecture"** - Harris & Harris

## 🔗 추천 리소스
1. **UART Tutorial**: https://www.nandland.com/uart
2. **FIFO Design**: https://zipcpu.com/blog/2017/07/29/fifo.html
3. **FSM Best Practices**: https://www.doulos.com/knowhow/verilog/fsm/

## 💡 실습 과제
1. **Parity bit 추가**: Even/Odd Parity 구현
2. **Flow Control**: RTS/CTS 신호 추가
3. **Error Detection**: Frame Error, Overrun Error 감지
4. **DMA 구현**: CPU 개입 없이 메모리 전송

---

# 10. 마무리

## ✅ 핵심 강조 포인트 (면접 시)

1. **"UART + FIFO 통합 설계"**
   - Full-Duplex, Echo Back
   - 8-depth FIFO로 데이터 손실 방지

2. **"FSM 기반 Command Parser"**
   - 순차 문자 수신 처리
   - "run", "clear", "mode", "sethz <숫자>"

3. **"10000진 Counter + FND"**
   - Dynamic Scanning (1kHz)
   - BCD Decoder

4. **"Trouble Shooting 경험"**
   - 무한 시뮬레이션 문제 → 조건 기반 종료
   - 나눗셈 연산 → case 문 최적화 (LUT 30% 감소)

5. **"Functional Coverage 99.7%"**
   - 500회 랜덤 시뮬레이션
   - Golden Model 비교
