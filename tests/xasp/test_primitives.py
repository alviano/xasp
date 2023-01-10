import clingo
import pytest

from dumbo_asp.primitives import Model
from xasp.primitives import PositiveIntegerOrUnbounded


def test_positive_integer_or_unbounded():
    assert PositiveIntegerOrUnbounded.of(1).int_value == 1
    assert PositiveIntegerOrUnbounded.of_unbounded().is_unbounded
    with pytest.raises(ValueError):
        _ = PositiveIntegerOrUnbounded.of_unbounded().int_value
    with pytest.raises(ValueError):
        PositiveIntegerOrUnbounded.of(0)


def test_positive_integer_or_unbounded_order():
    assert PositiveIntegerOrUnbounded.of(1) < PositiveIntegerOrUnbounded.of(2)
    assert PositiveIntegerOrUnbounded.of(1) < PositiveIntegerOrUnbounded.of_unbounded()


def test_positive_integer_or_unbounded_addition():
    assert PositiveIntegerOrUnbounded.of(1) + PositiveIntegerOrUnbounded.of(1) == PositiveIntegerOrUnbounded.of(2)
    assert PositiveIntegerOrUnbounded.of(1) + PositiveIntegerOrUnbounded.of_unbounded() == \
           PositiveIntegerOrUnbounded.of_unbounded()
    assert PositiveIntegerOrUnbounded.of(1) + 0 == PositiveIntegerOrUnbounded.of(1)
    with pytest.raises(ValueError):
        PositiveIntegerOrUnbounded.of(1) + (-1)
