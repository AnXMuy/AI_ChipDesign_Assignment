"""PYNQ integration boundary; requires a matching synthesized AXI overlay."""


def run_overlay(overlay_path: str, input_path: str, weight_path: str, bias_path: str):
    raise NotImplementedError(
        "Build the Ultra96 overlay first, then implement its feature/weight/bias "
        "transfer protocol and output collection using pynq.Overlay and pynq.allocate."
    )
