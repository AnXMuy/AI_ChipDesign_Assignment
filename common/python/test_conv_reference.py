import numpy as np

from common.python.conv_reference import conv2d_int8_nhwc


def test_identity_like_kernel_and_saturation():
    x = np.array([[[2], [-3]], [[4], [5]]], dtype=np.int8)
    w = np.zeros((3, 3, 1, 1), dtype=np.int8)
    w[1, 1, 0, 0] = 2
    y = conv2d_int8_nhwc(x, w, bias=np.array([1], dtype=np.int32))
    np.testing.assert_array_equal(y, np.array([[[5], [-5]], [[9], [11]]], dtype=np.int8))


def test_output_is_saturated_to_int8():
    x = np.full((1, 1, 1), 127, dtype=np.int8)
    w = np.full((1, 1, 1, 1), 127, dtype=np.int8)
    y = conv2d_int8_nhwc(x, w, padding=0)
    assert y.item() == 127

