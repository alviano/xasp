from typing import Optional, Any

import clingo
import clingo.ast

from xasp.entities import Explain
from xasp.primitives import Model, PositiveIntegerOrUnbounded


def compute_stable_model(asp_program: str, context: Optional[Any] = None) -> Optional[Model]:
    control = clingo.Control()
    control.add("base", [], asp_program)
    control.ground([("base", [])], context=context)
    return Model.of(control)


def compute_serialization(asp_program: str, answer_set: Model, base: Model,
                          atoms_to_explain: Model = Model.empty()) -> Model:
    return Explain.the_program(
        asp_program,
        the_answer_set=answer_set,
        the_atoms_to_explain=atoms_to_explain,
        the_additional_atoms_in_the_base=base,
    ).serialization.drop("original_rule")


def process_aggregates(to_be_explained_serialization: Model) -> Model:
    explain = Explain.the_serialization(
        to_be_explained_serialization
    )
    explain.process_aggregates()
    return explain.serialization.drop("original_rule")


def compute_atoms_explained_by_initial_well_founded(serialization: Model) -> Model:
    return Explain.the_serialization(
        serialization
    ).atoms_explained_by_initial_well_founded


def compute_minimal_assumption_set(to_be_explained_serialization: Model) -> Model:
    return compute_minimal_assumption_sets(to_be_explained_serialization, up_to=1)[-1]


def compute_minimal_assumption_sets(to_be_explained_serialization: Model, up_to: Optional[int] = None) -> tuple[Model]:
    explain = Explain.the_serialization(
        to_be_explained_serialization
    )
    explain.compute_minimal_assumption_set(
        repeat=up_to if up_to is not None else PositiveIntegerOrUnbounded.of_unbounded()
    )
    return explain.minimal_assumption_sets


def compute_explanation(to_be_explained_serialization: Model) -> Model:
    return compute_explanations(to_be_explained_serialization, up_to=1)[-1]


def compute_explanations(to_be_explained_serialization: Model, up_to: Optional[int] = None) -> tuple[Model]:
    explain = Explain.the_serialization(
        to_be_explained_serialization
    )
    explain.compute_explanation_sequence(repeat=up_to if up_to is not None else PositiveIntegerOrUnbounded.of_unbounded())
    return explain.explanation_sequences


def compute_explanation_dag(to_be_explained_serialization: Model) -> Model:
    return compute_explanation_dags(to_be_explained_serialization, up_to=1)[-1]


def compute_explanation_dags(to_be_explained_serialization: Model, up_to: Optional[int] = None) -> tuple[Model]:
    explain = Explain.the_serialization(
        to_be_explained_serialization
    )
    explain.compute_explanation_dag(repeat=up_to if up_to is not None else PositiveIntegerOrUnbounded.of_unbounded())
    return explain.explanation_dags
