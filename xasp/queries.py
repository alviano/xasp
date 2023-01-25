from typing import Optional, Any

import clingo
import clingo.ast
import typeguard

from dumbo_asp.primitives import Model, Predicate
from xasp.entities import Explain
from dumbo_utils.primitives import PositiveIntegerOrUnbounded


@typeguard.typechecked
def compute_stable_model(asp_program: str, context: Optional[Any] = None) -> Optional[Model]:
    control = clingo.Control()
    control.add("base", [], asp_program)
    control.ground([("base", [])], context=context)
    try:
        return Model.of_control(control)
    except Model.NoModelError:
        return None


@typeguard.typechecked
def compute_serialization(asp_program: str, answer_set: Model, additional_atoms_in_base: Model = Model.empty(),
                          atoms_to_explain: Model = Model.empty()) -> Model:
    return Explain.the_program(
        asp_program,
        the_answer_set=answer_set,
        the_atoms_to_explain=atoms_to_explain,
        the_additional_atoms_in_the_base=additional_atoms_in_base,
    ).serialization.drop(Predicate.parse("original_rule"))


@typeguard.typechecked
def process_aggregates(to_be_explained_serialization: Model) -> Model:
    explain = Explain.the_serialization(
        to_be_explained_serialization
    )
    explain.process_aggregates()
    return explain.serialization.drop(Predicate.parse("original_rule"))


@typeguard.typechecked
def compute_atoms_explained_by_initial_well_founded(serialization: Model) -> Model:
    return Explain.the_serialization(
        serialization
    ).atoms_explained_by_initial_well_founded


@typeguard.typechecked
def compute_minimal_assumption_set(to_be_explained_serialization: Model) -> Model:
    return Explain.the_serialization(to_be_explained_serialization).minimal_assumption_set()


@typeguard.typechecked
def compute_minimal_assumption_sets(
        to_be_explained_serialization: Model,
        atoms_to_explain: Model,
        up_to: Optional[int] = None
) -> tuple[Model, ...]:
    explain = Explain.the_serialization(
        to_be_explained_serialization,
        the_atoms_to_explain=atoms_to_explain,
    )
    explain.compute_minimal_assumption_set(
        repeat=up_to if up_to is not None else PositiveIntegerOrUnbounded.of_unbounded()
    )
    return tuple(explain.minimal_assumption_set(index) for index in range(explain.minimal_assumption_sets))


@typeguard.typechecked
def compute_explanation(to_be_explained_serialization: Model) -> Model:
    return Explain.the_serialization(to_be_explained_serialization).explanation_sequence()


@typeguard.typechecked
def compute_explanations(
        to_be_explained_serialization: Model,
        atoms_to_explain: Model,
        up_to: Optional[int] = None
) -> tuple[Model, ...]:
    explain = Explain.the_serialization(
        to_be_explained_serialization,
        the_atoms_to_explain=atoms_to_explain,
    )
    explain.compute_explanation_sequence(
        repeat=up_to if up_to is not None else PositiveIntegerOrUnbounded.of_unbounded()
    )
    return tuple(explain.explanation_sequence(index) for index in range(explain.explanation_sequences))


@typeguard.typechecked
def compute_explanation_dag(to_be_explained_serialization: Model) -> Model:
    return Explain.the_serialization(to_be_explained_serialization).explanation_dag()


@typeguard.typechecked
def compute_explanation_dags(
        to_be_explained_serialization: Model,
        atoms_to_explain: Model,
        up_to: Optional[int] = None
) -> tuple[Model, ...]:
    explain = Explain.the_serialization(
        to_be_explained_serialization,
        the_atoms_to_explain=atoms_to_explain,
    )
    explain.compute_explanation_dag(
        repeat=up_to if up_to is not None else PositiveIntegerOrUnbounded.of_unbounded()
    )
    return tuple(explain.explanation_dag(index) for index in range(explain.explanation_dags))
