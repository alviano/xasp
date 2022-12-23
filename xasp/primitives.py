import dataclasses
from typing import Any, Callable, Optional

import clingo
import typeguard

from xasp.utils import validate


@typeguard.typechecked
@dataclasses.dataclass(order=True, frozen=True)
class Model:
    key: dataclasses.InitVar[Any]
    value: tuple[clingo.Symbol, ...]

    __key = object()

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

    def map(self, fun: Callable[[clingo.Symbol], clingo.Symbol]) -> 'Model':
        return Model(key=self.__key, value=tuple(sorted(fun(atom) for atom in self)))

    @property
    def block_up(self) -> str:
        return ":- " + ", ".join([f"{atom}" for atom in self]) + '.'
