import dataclasses
from typing import Any, Optional

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
            on_model.count += 1
            on_model.res = Model(key=Model.__key, value=tuple(sorted((x for x in model.symbols(shown=True)),
                                                                     key=lambda atom: str(atom))))
        on_model.count = 0
        on_model.res = None

        control.solve(on_model=on_model)
        validate("called once", on_model.count, max_value=1,
                 help_msg="ModelCollect cannot collect more than one model.")
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

    def as_facts(self) -> str:
        return '\n'.join(f"{atom}." for atom in self)
