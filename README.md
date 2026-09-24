# DCLAB — 數位電路實驗 (Digital Circuit Lab)

國立臺灣大學電機系「數位電路實驗」課程專案，以 **SystemVerilog** 在 **Altera DE2-115 (Cyclone IV E)** FPGA 開發板上實作一系列數位系統，從基本的 FSM 設計，到 256-bit RSA 硬體解密、音訊錄放音，再到期末專題「電子鋼琴」。

> Team 09｜郭力銘、謝承恩、彭子綸

## 專案總覽

| 專案 | 主題 | 關鍵技術 |
| --- | --- | --- |
| [Lab1](Lab1/) | 隨機數產生器 | FSM、LFSR、按鍵去彈跳、七段顯示器 |
| [Lab2](Lab2/) | RSA-256 硬體解密 | Montgomery 模乘、平方乘演算法、Avalon-MM、RS-232、Qsys |
| [Lab3](Lab3/) | 音訊錄放音機 | I2C、WM8731 Audio Codec、I2S、SRAM、變速播放與線性內插 |
| [Final](Final/) | 電子鋼琴（PS/2 鍵盤合成器） | PS/2 協定、DDS、正弦查表、ADSR 包絡、12 音複音、多時脈域設計、SRAM 錄放音 |

**開發環境**：Quartus Prime（合成 / 燒錄）、Synopsys VCS + Verdi（模擬 / 波形）、nLint / SpyGlass（coding style 檢查）、Python（測資產生與 PC 端通訊）

---

## Lab1 — 隨機數產生器

按下 KEY0 後，七段顯示器上的數字先快速跳動、再逐漸變慢，最後停在一個 0–15 的隨機數。

- 以 4 狀態 FSM（`IDLE → RUN_FAST → RUN_SLOW → DONE`）控制數字跳動速度，模擬「轉盤減速」效果。
- [`lfsr_random_gen.sv`](Lab1/src/lfsr_random_gen.sv)：組合 11/13/17-bit 三組 LFSR 與以按鍵時間為種子的 entropy pool，提升隨機性。
- 按鍵去彈跳 ([`Debounce.sv`](Lab1/src/DE2_115/Debounce.sv)) 與七段顯示解碼 ([`SevenHexDecoder.sv`](Lab1/src/DE2_115/SevenHexDecoder.sv))。
- 📄 [報告](Lab1/team09_lab1_report.pdf)

## Lab2 — RSA-256 硬體解密

PC 透過 RS-232 將 256-bit 的 `n`、`d` 與密文傳給 FPGA，FPGA 計算 `a^d mod n` 後回傳明文。

- [`Rsa256Core.sv`](Lab2/src/Rsa256Core.sv)
  - `RsaPrep`：預先計算 `a · 2^256 mod n`，將輸入轉換至 Montgomery domain。
  - `RsaMont`：Montgomery 模乘，以逐位元加法與移位取代昂貴的除法 / 取模運算。
  - 兩個 Montgomery 乘法器**平行運作**（`m·t` 與 `t·t`），以 right-to-left square-and-multiply 完成模指數運算。
- [`Rsa256Wrapper.sv`](Lab2/src/Rsa256Wrapper.sv)：作為 **Avalon-MM master**，輪詢 RS-232 UART 的狀態暫存器以收發位元組，並控制 core 的啟動與結果回傳。
- 驗證：[`tb_verilog/`](Lab2/tb_verilog/) 包含 core 與 wrapper 的 testbench；[`pc_python/`](Lab2/pc_python/) 包含 Python RSA 參考實作 (golden model) 與 PC 端傳輸程式。
- 📄 [報告](Lab2/team09_lab2_report.pdf)

## Lab3 — 音訊錄放音機

使用板上的 WM8731 音訊晶片實作 16-bit 錄音 / 放音，錄音長度約 30 秒。

- [`I2cInitializer.sv`](Lab3/src/I2cInitializer.sv)：以 I2C 協定依序寫入設定暫存器，初始化 WM8731。
- [`AudRecorder.sv`](Lab3/src/AudRecorder.sv)：依 I2S 時序（BCLK / ADCLRCK）將序列資料轉為 16-bit 樣本並寫入 SRAM。
- [`AudDSP.sv`](Lab3/src/AudDSP.sv)：支援 **1–8 倍快放**，以及 **1/2–1/8 倍慢放**；慢放可選擇 piecewise-constant（零階保持）或 **linear interpolation**（一階內插）。
- [`AudPlayer.sv`](Lab3/src/AudPlayer.sv)：依 DACLRCK 時序將樣本序列化送出給 DAC。
- 支援暫停 / 停止，並以七段顯示器顯示錄放時間。
- Debug：以 LED 顯示 FSM 狀態，並使用 Quartus **SignalTap II Logic Analyzer** 觀察實際硬體上的暫存器數值。
- 📄 [報告](Lab3/team09_lab3_report.pdf)

## Final — 電子鋼琴（PS/2 鍵盤合成器）

📑 [Proposal](Final/Proposal.pdf)｜🎤 [期末簡報](<Final/Team09 final project _ 電子鋼琴.pdf>)｜📄 [期末報告](Final/team09_final_report.pdf)

不用麥克風、也不用預先準備的音檔：把 PS/2 電腦鍵盤接上 FPGA，直接用 scan code 與 FSM 做成一台可即時彈奏、支援和弦、可錄音與回放的電子鋼琴，**音訊的產生、播放與錄音全部在 FPGA 內完成**。

```
PS/2 keyboard ─► ps2_rx ─► ps2_key_tracker ─► 12 × generator_sin ─► mixer ─┬──────────────► player ─► WM8731 DAC ─► 喇叭
                (11-bit    (make / break       (DDS + 包絡)                 └─► recorder ─► SRAM ─┘
                 frame)     → 12-bit 按鍵向量)
```

**功能**
- 12 個按鍵 `A W S E D F T G Y H U J` 對應一個八度內的 12 個半音（C 到 B），可切換八度。
- 同時按下多個鍵即可彈奏**和弦**。
- 狀態機 `IDLE → NORMAL（自由彈奏）→ RECORD（邊彈邊錄）→ PLAY（回放，可暫停 / 停止）`，以 LED 顯示目前狀態、七段顯示器顯示錄放時間。

**設計重點**
- **PS/2 接收** ([`ps2_rx.sv`](Final/src/ps2_rx.sv))：在 ps2_clk 的下降緣逐位元取樣 11-bit frame（start / 8 data / parity / stop），取出中間 8-bit scan code。
- **按鍵追蹤** ([`gen.sv`](Final/src/gen.sv) 中的 `ps2_key_tracker`)：以 FSM 偵測 `F0` break code，區分按下與放開，輸出 12-bit 按鍵向量與升 / 降八度訊號。
- **音源產生** ([`gen.sv`](Final/src/gen.sv) 中的 `generator_sin`)
  - **DDS (Direct Digital Synthesis)**：32-bit 相位累加器，各音高由預先計算的 phase increment 決定頻率，升降八度只需對 phase increment 做位移。
  - **正弦查表**：只儲存 1/4 週期的 1024 點 LUT ([`sin_lut_1024.mem`](Final/src/sin_lut_1024.mem))，利用象限對稱還原完整波形，以 1/4 的記憶體達到等效 4096 點的解析度。
  - **振幅包絡**（類 ADSR）：Rise 線性上升、Decay 指數衰減、Release 線性釋放，避免爆音並讓音色更接近鋼琴。
  - **12 音複音**：12 個 generator 平行運作並加總混音。
- **多時脈域設計**：系統同時使用 6 個時脈，包括 50 MHz 主時脈、PS/2 時脈（約 10–16 kHz）、I2C 用的 100 kHz、I2S 用的 BCLK 1.6 MHz 和 DACLRCK 50 kHz，以及 50 kHz 取樣時脈。`ps2_rx` 會把 valid 訊號延長，讓 50 kHz 取樣時脈域能穩定接收按鍵事件；[`event_sync.sv`](Final/src/event_sync.sv) 則是以 toggle-request / ack 實作的另一種跨時脈域同步器。
- **錄音 / 回放** ([`recorder.sv`](Final/src/recorder.sv)、[`player_controller.sv`](Final/src/player_controller.sv)、[`player.sv`](Final/src/player.sv))：以 50 kHz 將合成出的樣本寫入 SRAM，可暫停 / 回放，並透過 I2S 送至 WM8731。
- 頂層由 [`DE2_115.sv`](Final/src/DE2_115.sv) 例化最終版本 [`Toptest.sv`](Final/src/Toptest.sv)。[`Top.sv`](Final/src/Top.sv) 和 [`Topnew.sv`](Final/src/Topnew.sv) 是嘗試以 Qsys SDRAM controller ([`sdram_qsys.v`](Final/src/sdram_qsys.v)) 延長錄音時間的開發版本。

---

## 資料夾結構

```
DCLAB/
├── Lab1/                 # 隨機數產生器
│   ├── src/              # RTL（Top、LFSR）與 DE2_115 板級檔案 (.sv/.qsf/.sdc)
│   ├── sim/              # testbench
│   └── team09_lab1_report.pdf
├── Lab2/                 # RSA-256 解密器
│   ├── src/              # Rsa256Core、Rsa256Wrapper、DE2_115 板級檔案
│   ├── tb_verilog/       # core / wrapper testbench 與測資
│   ├── pc_python/        # PC 端 RS-232 程式、Python RSA golden model
│   └── team09_lab2_report.pdf
├── Lab3/                 # 音訊錄放音機
│   ├── src/              # I2C、Recorder、DSP、Player、DE2_115 板級檔案
│   ├── sim/              # testbench 與執行腳本
│   └── team09_lab3_report.pdf
└── Final/                # 電子鋼琴
    ├── src/              # RTL 與正弦 LUT
    ├── sim/              # testbench 與執行腳本
    ├── Proposal.pdf
    ├── Team09 final project _ 電子鋼琴.pdf   # 期末簡報
    └── team09_final_report.pdf
```

> 各 Lab 資料夾內的 `README.md` 為課程提供的實驗說明。

## 模擬方式

使用 Synopsys VCS，例如：

```bash
# Lab2：測試 RSA core
cd Lab2/tb_verilog
vcs tb.sv ../src/Rsa256Core.sv -full64 -R -debug_access+all -sverilog +access+rw

# Final：測試 PS/2 接收模組
cd Final/sim/sh
source ps2_rx.sh
```

FPGA 合成：以 Quartus 開啟各 Lab 的 `src/DE2_115/` 專案（`DE2_115.qsf`），編譯後燒錄至 DE2-115。
