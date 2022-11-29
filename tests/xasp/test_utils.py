from xasp.utils import pattern


def test_pattern():
    three_upper_case_letters = pattern(r"[A-Z]{3}")
    assert three_upper_case_letters("ABC")
    assert not three_upper_case_letters("AB")
    assert not three_upper_case_letters("ABc")
    assert not three_upper_case_letters("ABCd")
    assert not three_upper_case_letters("AB3")
