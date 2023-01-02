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


@typeguard.typechecked
@dataclasses.dataclass(frozen=True, order=True)
class Model:
    key: dataclasses.InitVar[Any]
    value: tuple[clingo.Symbol, ...]

    __key = object()

    @staticmethod
    def empty():
        return Model(key=Model.__key, value=())

    @staticmethod
    def of(control: clingo.Control) -> Optional["Model"]:
        def on_model(model):
            if on_model.cost is not None and on_model.cost <= model.cost:
                on_model.exception = True
            on_model.cost = model.cost
            on_model.res = Model(
                key=Model.__key,
                value=tuple(sorted((x for x in model.symbols(shown=True)),
                                   key=lambda atom: (str(atom.name), atom.arguments)))
            )
        on_model.cost = None
        on_model.res = None
        on_model.exception = False

        control.solve(on_model=on_model)
        if on_model.exception:
            raise ValueError("more than one stable model")
        return on_model.res

    @staticmethod
    def of_program(program: str) -> Optional["Model"]:
        control = clingo.Control()
        control.add("base", [], program)
        control.ground([("base", [])])
        return Model.of(control)

    @staticmethod
    def of_atoms(*args: Union[str, Iterable[str]]) -> Optional["Model"]:
        flattened = []
        for element in args:
            if type(element) is str:
                flattened.append(clingo.parse_term(element))
            else:
                flattened.extend(clingo.parse_term(atom) for atom in element)
        return Model(key=Model.__key, value=tuple(flattened))

    def __post_init__(self, key: Any):
        validate("create key", key, equals=self.__key,
                 help_msg="Instances of Model must be created with a factory method.")

    def __str__(self):
        return ' '.join(str(x) for x in self.value)

    def __len__(self):
        return len(self.value)

    def __getitem__(self, item):
        return self.value[item]

    def __iter__(self):
        return self.value.__iter__()

    @property
    def as_facts(self) -> str:
        return '\n'.join(f"{atom}." for atom in self)

    def drop(self, predicate: str) -> "Model":
        return Model(key=self.__key, value=tuple(atom for atom in self if atom.name != predicate))

    def filter(self, when: Callable[[clingo.Symbol], bool]) -> "Model":
        return Model(key=self.__key, value=tuple(atom for atom in self if when(atom)))

    def map(self, fun: Callable[[clingo.Symbol], clingo.Symbol]) -> 'Model':
        return Model(key=self.__key, value=tuple(sorted(fun(atom) for atom in self)))

    def rename(self, predicate: str, new_name: str) -> "Model":
        return self.map(lambda atom: atom if atom.name != predicate else clingo.Function(new_name, atom.arguments))

    def substitute(self, predicate: str, argument: int, term: clingo.Symbol) -> "Model":
        validate("argument", argument, min_value=1, help_msg="Argument are indexed from 1")

        def mapping(atom):
            if atom.name != predicate:
                return atom
            return clingo.Function(
                atom.name,
                [arg if index != argument else term for index, arg in enumerate(atom.arguments, start=1)]
            )
        return self.map(mapping)

    def project(self, predicate: str, argument: int) -> "Model":
        validate("argument", argument, min_value=1, help_msg="Argument are indexed from 1")

        def mapping(atom):
            if atom.name != predicate:
                return atom
            return clingo.Function(
                atom.name,
                [arg for index, arg in enumerate(atom.arguments, start=1) if index != argument]
            )
        return self.map(mapping)

    @property
    def block_up(self) -> str:
        return ":- " + ", ".join([f"{atom}" for atom in self]) + '.'
