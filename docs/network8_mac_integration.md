# network_8 MAC 接入 lightcommun PHY 说明

本文说明如何把 `RBzhang/network_8` 的双端口 MAC 逻辑接入当前 `lightcommun` 工程中的 GTX/SFP+ 物理层。

本次新增的集成顶层是：

```text
 gt wizard / SFP+ PHY
        |
 gtwizard_0_phy_stream_wrapper
        |
 lightcomm_gt_mac_top
        |
 network_8 node_top
```

新增文件：

```text
gtwizard_0_ex.srcs/sources_1/imports/example_design/lightcomm_gt_mac_top.v
gtwizard_0_ex.srcs/sources_1/imports/example_design/network8_fifo_ip_aliases.v
gtwizard_0_ex.srcs/sources_1/imports/example_design/network8_mac_sources.f
```

`gtwizard_0_user_demo.v` 没有被修改，原来的 PHY demo 仍然可以继续单独综合和上板测试。

---

## 1. 集成顶层

`lightcomm_gt_mac_top.v` 实例化：

```verilog
gtwizard_0_phy_stream_wrapper u_phy_stream (...);
node_top u_mac (...);
```

连接关系：

```text
node_top.out0 / valid_out0  -> stream0_tx_data / stream0_tx_valid
node_top.out1 / valid_out1  -> stream1_tx_data / stream1_tx_valid

stream0_rx_data / stream0_rx_valid -> node_top.in0 / valid_in0
stream1_rx_data / stream1_rx_valid -> node_top.in1 / valid_in1

gt0_rx_clk -> node_top.rx_clk0
gt1_rx_clk -> node_top.rx_clk1
gt0_tx_clk -> node_top.tx_clk0
gt1_tx_clk -> node_top.tx_clk1
```

如果 `stream*_rx_bad=1`，集成顶层默认会将该 word XOR `32'h00000001` 后再送入 MAC，使 MAC CRC 必然失败，从而丢弃该帧。可通过参数 `POISON_BAD_RX_WORD=0` 关闭。

---

## 2. MAC 时钟和复位

`lightcomm_gt_mac_top` 增加了独立的 `mac_clk/mac_rst` 输入。`node_top` 内部主逻辑和 app 接口均工作在 `mac_clk` 域。

默认参数：

```verilog
parameter MAC_CLK_FREQ_HZ = 100_000_000
```

如果你接入 160 MHz MAC 主时钟，应把该参数改为：

```verilog
.MAC_CLK_FREQ_HZ(160_000_000)
```

默认 `RESET_MAC_UNTIL_ALL_LINK_READY=1`，也就是只有当两路 GT 均满足：

```text
gt0_tx_ready && gt0_rx_ready && gt1_tx_ready && gt1_rx_ready
```

之后才释放 MAC 复位。这样可以避免 MAC 在 PHY 未 ready 时已经开始发探活帧或业务帧。

`cfg_node_id_valid/cfg_node_id` 会被顶层暂存，并在 MAC 复位释放后自动给 `node_top` 重新打一拍 `node_id_valid`。

---

## 3. 需要加入 Vivado 的 network_8 RTL 文件

请从本地 `network_8` 仓库加入以下文件：

```text
sources_1/new/node_top.v
sources_1/new/node_core.v
sources_1/new/node_id_latch.v
sources_1/new/port_cdc.v
sources_1/new/async_fifo.v
sources_1/new/sync_fifo.v
sources_1/new/frame_rx.v
sources_1/new/crc32_calc.v
sources_1/new/rx_dispatcher.v
sources_1/new/dedup_table.v
sources_1/new/rx_report_fifo.v
sources_1/new/liveness_timer.v
sources_1/new/liveness_table.v
sources_1/new/local_packet_generator.v
sources_1/new/forward_engine.v
sources_1/new/tx_enqueue_engine.v
sources_1/new/tx_frame_fifo.v
sources_1/new/frame_meta_fifo.v
sources_1/new/port_tx_queue_sender.v
```

可参考文件：

```text
gtwizard_0_ex.srcs/sources_1/imports/example_design/network8_mac_sources.f
```

不需要加入 `node_top_3port.v`、`node_top_4port.v`、`node.v`，除非你后续要测试 3/4 端口版本。

---

## 4. 需要保持或创建的 IP

### 4.1 当前 lightcommun 已有 IP

当前 PHY 相关 IP 不需要修改：

```text
gtwizard_0
ila_0 / 其他 ILA debug IP（如果工程中已有）
```

### 4.2 network_8 MAC 需要的 FIFO IP

#### IP 1：fifo_generator_32_512

用途：`async_fifo.v`，每端口 RX/TX 跨时钟 FIFO。

模块名必须为：

```text
fifo_generator_32_512
```

建议配置：

```text
FIFO Generator
Independent Clocks / Asynchronous FIFO
First Word Fall Through: Enable
Write Width: 32
Read Width: 32
Write Depth: 8192
Read Depth: 8192
Reset: rst，高有效
输出 full、empty
输出 wr_data_count，宽度 13 bit
输出 wr_rst_busy、rd_rst_busy，可不使用但端口需要存在
```

期望端口：

```verilog
.rst(rst)
.wr_clk(wr_clk)
.rd_clk(rd_clk)
.din(din[31:0])
.wr_en(wr_en)
.rd_en(rd_en)
.dout(dout[31:0])
.full(full)
.wr_data_count(wr_data_count[12:0])
.empty(empty)
.wr_rst_busy(wr_rst_busy)
.rd_rst_busy(rd_rst_busy)
```

#### IP 2：fifo_generator_sync

用途：`rx_report_fifo.v`，本地上报 FIFO。

模块名必须为：

```text
fifo_generator_sync
```

建议配置：

```text
FIFO Generator
Common Clock / Synchronous FIFO
First Word Fall Through: Enable
Write Width: 32
Read Width: 32
Depth: 2048
Reset: srst，同步高有效
输出 full、empty
输出 data_count，宽度 12 bit
```

期望端口：

```verilog
.clk(clk)
.srst(srst)
.din(din[31:0])
.wr_en(wr_en)
.rd_en(rd_en)
.dout(dout[31:0])
.full(full)
.empty(empty)
.data_count(data_count[11:0])
```

#### IP 3：fifo_generator_txframe

用途：`tx_frame_fifo.v`，每端口待发送帧 word FIFO。

推荐创建模块名：

```text
fifo_generator_txframe
```

注意：`network_8` 原始 RTL 中历史模块名写成了 `fifo_generato_txframe`，少了一个 `r`。本工程新增了兼容 wrapper：

```text
gtwizard_0_ex.srcs/sources_1/imports/example_design/network8_fifo_ip_aliases.v
```

该 wrapper 内部实例化真正的：

```text
fifo_generator_txframe
```

因此推荐你在 Vivado 中创建 IP 名 `fifo_generator_txframe`，并加入 `network8_fifo_ip_aliases.v`。

建议配置：

```text
FIFO Generator
Common Clock / Synchronous FIFO
First Word Fall Through: Enable
Write Width: 34
Read Width: 34
Depth: 8192
Reset: srst，同步高有效
输出 full、empty
输出 data_count，宽度 14 bit
```

期望端口：

```verilog
.clk(clk)
.srst(srst)
.din(din[33:0])
.wr_en(wr_en)
.rd_en(rd_en)
.dout(dout[33:0])
.full(full)
.empty(empty)
.data_count(data_count[13:0])
```

如果你不想使用 alias，也可以直接把 IP 命名为原始拼写：

```text
fifo_generato_txframe
```

此时不要加入 `network8_fifo_ip_aliases.v`，否则会出现重复模块名。

#### IP 4：fifo_generator_meta

用途：`frame_meta_fifo.v`，每帧 metadata FIFO。

模块名必须为：

```text
fifo_generator_meta
```

建议配置：

```text
FIFO Generator
Common Clock / Synchronous FIFO
First Word Fall Through: Enable
Write Width: 48
Read Width: 48
Depth: 512
Reset: srst，同步高有效
输出 full、empty
输出 data_count，宽度 10 bit
```

期望端口：

```verilog
.clk(clk)
.srst(srst)
.din(din[47:0])
.wr_en(wr_en)
.rd_en(rd_en)
.dout(dout[47:0])
.full(full)
.empty(empty)
.data_count(data_count[9:0])
```

---

## 5. Vivado 中建议操作顺序

1. 先保留原来的 `gtwizard_0_user_demo`，确认原 PHY demo 仍可综合。
2. Add Sources 加入：
   - `phy_8b10b_tx_adapter.v`
   - `phy_8b10b_rx_adapter.v`
   - `gtwizard_0_phy_stream_wrapper.v`
   - `lightcomm_gt_mac_top.v`
   - `network8_fifo_ip_aliases.v`（若使用推荐的 `fifo_generator_txframe` 名字）
   - 上文列出的 `network_8/sources_1/new/*.v`
3. 创建或导入 4 个 FIFO IP。
4. Generate Output Products。
5. 将顶层设为：

```text
lightcomm_gt_mac_top
```

6. 做行为级仿真或 elaboration，先解决缺模块/端口名不匹配问题。
7. 行为级仿真无误后再综合。

---

## 6. 初次硬件测试建议

先不要直接做 8 节点环网，建议两块板或单板双口先做：

```text
Node 0: cfg_node_id = 0
Node 1: cfg_node_id = 1
Node 0 周期性 app 发送 dst=1, len16=4 的短帧
Node 1 app_rx_frame_ready=1, app_rx_payload_ready=1
ILA 观察 app_rx_src_id/app_rx_dst_id/app_rx_len16/app_rx_payload_data
```

确认单向业务帧能收到后，再测试双向业务帧、广播帧、liveness 状态。
