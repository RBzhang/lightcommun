# Aurora 8B/10B GT Wizard Example Design

Xilinx 7 Series FPGA Transceivers Wizard example design for Aurora 8B/10B protocol (multi-lane, 4-byte).

## Hardware

- **Device**: XC7K325TFFG900-2 (Kintex-7)
- **Transceiver**: GTX, 2 lanes (X1Y12 / X1Y13)
- **Line Rate**: 10 Gbps per lane
- **Reference Clock**: 156.25 MHz (QPLL, REFCLK1_Q0)
- **DRP Clock**: 100 MHz (external)

## Design Files

### Top-Level Modules

| File | Description |
|------|-------------|
| `gtwizard_0_exdes.v` | Example design with built-in frame generator/checker and ILA |
| `gtwizard_0_user_exdes.v` | User-facing wrapper exposing native 32-bit TX/RX data ports |
| `gtwizard_0_user_demo.v` | Demo with packet-based TX/RX and status counters |

### Supporting Modules

| File | Description |
|------|-------------|
| `gtwizard_0_gt_frame_gen.v` | BRAM-based frame generator (comma/alignment + channel bonding sequences) |
| `gtwizard_0_gt_frame_check.v` | BRAM-based frame checker with error counting |

### IP Cores

| Core | Purpose |
|------|---------|
| `gtwizard_0` | GT Wizard IP (Aurora 8B/10B, 2-lane GTX) |
| `ila_0` | Integrated Logic Analyzer (164-bit, 4 probes) |

## Pinout

| Port | Direction | Pin | Standard | Description |
|------|-----------|-----|----------|-------------|
| `Q3_CLK0_GTREFCLK_PAD_P_IN` | Input | C8 | - | GT reference clock (156.25 MHz) |
| `Q3_CLK0_GTREFCLK_PAD_N_IN` | Input | C7 | - | GT reference clock N |
| `DRP_CLK_IN_P` | Input | AE10 | DIFF_SSTL15 | DRP free-running clock (100 MHz) |
| `RXP_IN[0]` | Input | - | - | GT0 RX P |
| `RXN_IN[0]` | Input | - | - | GT0 RX N |
| `RXP_IN[1]` | Input | - | - | GT1 RX P |
| `RXN_IN[1]` | Input | - | - | GT1 RX N |
| `TXP_OUT[0]` / `TXN_OUT[0]` | Output | - | - | GT0 TX |
| `TXP_OUT[1]` / `TXN_OUT[1]` | Output | - | - | GT1 TX |
| `sfp_tx_disable[0]` | Output | AA28 | LVCMOS33 | SFP TX disable 0 |
| `sfp_tx_disable[1]` | Output | AF28 | LVCMOS33 | SFP TX disable 1 |

## Building

1. Open `gtwizard_0_ex.xpr` in Vivado 2024.2
2. Run Synthesis → Implementation → Generate Bitstream
3. Program the device via Hardware Manager

## ILA Debugging

The design includes an ILA (`ila_0`) with 4 probes:

| Probe | Signal | Width | Description |
|-------|--------|-------|-------------|
| probe0 | `error_detected_c0` | 1 | GT0 8B/10B decode error |
| probe1 | `error_detected_c1` | 1 | GT1 8B/10B decode error |
| probe2 | `gt0_rxdata_i` | 32 | GT0 RX data |
| probe3 | `gt1_rxdata_i` | 32 | GT1 RX data |

**Note**: The ILA is clocked by `gt0_rxusrclk2_i` (GT RX recovered clock), which is only active when the GT link is established. For standalone testing without a link partner, enable near-end PMA loopback:

```verilog
assign gt0_loopback_i = 3'b010;  // Near-End PMA Loopback
assign gt1_loopback_i = 3'b010;
```

## Using `gtwizard_0_user_exdes.v`

This wrapper exports user TX/RX data interfaces for custom logic:

- Drive `USER_GT*_TXDATA_IN`, `USER_GT*_TXCHARISK_IN`, and `USER_GT*_TX_VALID_IN` after `USER_GT*_TX_READY_OUT` is high
- When `TX_VALID` is low, the wrapper transmits K28.5 idle characters
- RX data is continuous and synchronous to `USER_GT*_RXUSRCLK2_OUT`

## Using `gtwizard_0_user_demo.v`

Demonstrates packet-based communication:

- **TX**: SOF (K27.7) → 16-word payload with lane/frame/word IDs → EOF (K29.7)
- **RX**: Frames received data, maintains word/frame/error counters
- Outputs `gt0/1_link_ready`, `rx_last_word`, `rx_word_count`, `rx_frame_count`, `rx_error_count`
