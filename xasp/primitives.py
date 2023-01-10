import dataclasses
import functools
from dataclasses import InitVar
from typing import Any, Callable, Optional, Iterable, Union

import clingo
import typeguard

from xasp.utils import validate


@typeguard.typechecked
@functools.total_ordering
@dataclasses.dataclass
class PositiveIntegerOrUnbounded:
    key: InitVar[Any]
    __value: Optional[int] = dataclasses.field(default=None)

    __key = object()

    def __post_init__(self, key):
        validate("key", key, equals=PositiveIntegerOrUnbounded.__key, help_msg="Use a factory method")

    @staticmethod
    def of(value: int) -> "PositiveIntegerOrUnbounded":
        validate("value", value, min_value=1)
        res = PositiveIntegerOrUnbounded(key=PositiveIntegerOrUnbounded.__key)
        res.__value = value
        return res

    @staticmethod
    def of_unbounded() -> "PositiveIntegerOrUnbounded":
        return PositiveIntegerOrUnbounded(key=PositiveIntegerOrUnbounded.__key)

    @property
    def int_value(self) -> int:
        validate("value", self.is_int, equals=True)
        return self.__value

    @property
    def is_int(self) -> bool:
        return self.__value is not None

    @property
    def is_unbounded(self) -> bool:
        return self.__value is None

    def __str__(self):
        return f"{self.__value}" if self.is_int else "unbounded"

    def __lt__(self, other: "PositiveIntegerOrUnbounded") -> bool:
        if self.is_unbounded:
            return False
        if other.is_unbounded:
            return True
        return self.__value < other.__value

    def greater_than(self, value: int) -> bool:
        return self.is_unbounded or self.__value > value

    def __add__(self, other: Union[int, "PositiveIntegerOrUnbounded"]) -> "PositiveIntegerOrUnbounded":
        if self.is_unbounded or (type(other) is PositiveIntegerOrUnbounded and other.is_unbounded):
            return PositiveIntegerOrUnbounded.of_unbounded()
        other_value = other.__value if type(other) is PositiveIntegerOrUnbounded else other
        return PositiveIntegerOrUnbounded.of(self.__value + other_value)
