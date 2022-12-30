from unittest.mock import Mock

from xasp.utils import pattern, call_with_difference_if_invalid_index


def test_pattern():
    three_upper_case_letters = pattern(r"[A-Z]{3}")
    assert three_upper_case_letters("ABC")
    assert not three_upper_case_letters("AB")
    assert not three_upper_case_letters("ABc")
    assert not three_upper_case_letters("ABCd")
    assert not three_upper_case_letters("AB3")


def test_call_with_difference_if_invalid_index_positive():
    mock = Mock()
    call_with_difference_if_invalid_index(1, 1, mock)
    mock.assert_called_once_with(1)


def test_call_with_difference_if_invalid_index_negative():
    mock = Mock()
    call_with_difference_if_invalid_index(-1, 0, mock)
    mock.assert_called_once_with(1)


def test_call_with_difference_if_invalid_index():
    mock = Mock()
    call_with_difference_if_invalid_index(1, 2, mock)
    mock.assert_not_called()
