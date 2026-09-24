# PL interface contract

`conv2d_stream.sv` is synthesizable Verilog for a window-level signed int8 MAC. `window_last` marks the final pair; `bias` is added once and the result saturates to signed int8. To deploy on Ultra96, add a sliding-window generator, AXI4-Stream/AXI-Lite wrappers and a PYNQ-compatible bitstream. This module alone cannot process a full image or act as an AXI peripheral.
