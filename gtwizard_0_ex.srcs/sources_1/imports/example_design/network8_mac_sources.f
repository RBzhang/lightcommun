# Required network_8 MAC RTL files for lightcomm_gt_mac_top.v
# Replace <NETWORK_8_ROOT> with the local path to your RBzhang/network_8 checkout,
# or copy these files into this project and update the paths accordingly.

<NETWORK_8_ROOT>/sources_1/new/node_top.v
<NETWORK_8_ROOT>/sources_1/new/node_core.v
<NETWORK_8_ROOT>/sources_1/new/node_id_latch.v
<NETWORK_8_ROOT>/sources_1/new/port_cdc.v
<NETWORK_8_ROOT>/sources_1/new/async_fifo.v
<NETWORK_8_ROOT>/sources_1/new/sync_fifo.v
<NETWORK_8_ROOT>/sources_1/new/frame_rx.v
<NETWORK_8_ROOT>/sources_1/new/crc32_calc.v
<NETWORK_8_ROOT>/sources_1/new/rx_dispatcher.v
<NETWORK_8_ROOT>/sources_1/new/dedup_table.v
<NETWORK_8_ROOT>/sources_1/new/rx_report_fifo.v
<NETWORK_8_ROOT>/sources_1/new/liveness_timer.v
<NETWORK_8_ROOT>/sources_1/new/liveness_table.v
<NETWORK_8_ROOT>/sources_1/new/local_packet_generator.v
<NETWORK_8_ROOT>/sources_1/new/forward_engine.v
<NETWORK_8_ROOT>/sources_1/new/tx_enqueue_engine.v
<NETWORK_8_ROOT>/sources_1/new/tx_frame_fifo.v
<NETWORK_8_ROOT>/sources_1/new/frame_meta_fifo.v
<NETWORK_8_ROOT>/sources_1/new/port_tx_queue_sender.v

# Optional compatibility wrapper when you create the TX frame FIFO IP with the
# corrected name fifo_generator_txframe instead of the historical network_8
# module name fifo_generato_txframe.
gtwizard_0_ex.srcs/sources_1/imports/example_design/network8_fifo_ip_aliases.v

# Existing lightcommun PHY stream files required by the integration top:
gtwizard_0_ex.srcs/sources_1/imports/example_design/phy_8b10b_tx_adapter.v
gtwizard_0_ex.srcs/sources_1/imports/example_design/phy_8b10b_rx_adapter.v
gtwizard_0_ex.srcs/sources_1/imports/example_design/gtwizard_0_phy_stream_wrapper.v
gtwizard_0_ex.srcs/sources_1/imports/example_design/lightcomm_gt_mac_top.v
