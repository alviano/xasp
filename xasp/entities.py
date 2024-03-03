import base64
import dataclasses
import json
import webbrowser
import zlib
from dataclasses import InitVar
from enum import auto, IntEnum
from pathlib import Path
from typing import Callable, Final, Optional, Dict, List, Any, Union

import clingo
import igraph
import typeguard
from clingo import Model
from dumbo_asp.primitives import Model, Predicate, GroundAtom
from dumbo_utils.url import compress_object_for_url
from valid8 import validate

from xasp.contexts import ComputeExplanationContext, ProcessAggregatesContext, ComputeWellFoundedContext
from dumbo_utils.primitives import PositiveIntegerOrUnbounded
from xasp.transformers import ProgramSerializerTransformer
from xasp.utils import call_with_difference_if_invalid_index


@typeguard.typechecked
@dataclasses.dataclass
class Explain:
    key: InitVar[Any]
    __key = object()

    __state: "Explain.State" = dataclasses.field(default_factory=lambda: Explain.State.INITIAL, init=False)
    __commands_implementation: Dict[str, Callable] = dataclasses.field(default_factory=dict)
    __asp_program: Optional[str] = dataclasses.field(default=None, init=False)
    __answer_set: Optional[Model] = dataclasses.field(default=None, init=False)
    __additional_atoms_in_the_base: Optional[Model] = dataclasses.field(default=None, init=False)
    __atoms_to_explain: Optional[Model] = dataclasses.field(default=None, init=False)
    __serialization: Model = dataclasses.field(default=Model.empty(), init=False)
    __atoms_explained_by_initial_well_founded: Model = dataclasses.field(default=Model.empty(), init=False)
    __minimal_assumption_sets: List[Model] = dataclasses.field(default_factory=list, init=False)
    __minimal_assumption_sets_block_constraints: List[str] = dataclasses.field(default_factory=list, init=False)
    __explanation_sequences: List[Model] = dataclasses.field(default_factory=list, init=False)
    __explanation_dags: List[Model] = dataclasses.field(default_factory=list, init=False)
    __igraph: List[Optional[igraph.Graph]] = dataclasses.field(default_factory=list, init=False)

    class State(IntEnum):
        INITIAL = auto()
        SERIALIZED = auto()
        AGGREGATE_PROCESSED = auto()
        WELL_FOUNDED_COMPUTED = auto()
        MINIMAL_ASSUMPTION_SET_COMPUTED = auto()
        EXPLANATION_SEQUENCE_COMPUTED = auto()
        EXPLANATION_DAG_COMPUTED = auto()
        IGRAPH_COMPUTED = auto()

    def __post_init__(self, key):
        validate("key", key, equals=self.__key, help_msg="Use a factory method")

    @staticmethod
    def the_program(
            value: str,
            the_answer_set: Model,
            the_atoms_to_explain: Model = Model.empty(),
            the_additional_atoms_in_the_base: Model = Model.empty()
    ) -> "Explain":
        res = Explain(key=Explain.__key)
        res.__asp_program = value
        res.__answer_set = the_answer_set
        res.__atoms_to_explain = the_atoms_to_explain
        res.__additional_atoms_in_the_base = the_additional_atoms_in_the_base
        res.__compute_serialization()
        return res

    @staticmethod
    def the_serialization(
            value: Model,
            the_answer_set: Optional[Model] = None,
            the_atoms_to_explain: Optional[Model] = None,
            the_additional_atoms_in_the_base: Model = Model.empty(),
    ) -> "Explain":
        res = Explain(key=Explain.__key)
        res.__serialization = value
        res.__answer_set = the_answer_set
        res.__atoms_to_explain = the_atoms_to_explain
        res.__additional_atoms_in_the_base = the_additional_atoms_in_the_base
        res.__state = Explain.State.SERIALIZED
        return res

    @staticmethod
    def the_dag(
            value: Model,
            the_answer_set: Optional[Model] = None,
            the_atoms_to_explain: Optional[Model] = None,
            the_additional_atoms_in_the_base: Model = Model.empty(),
    ) -> "Explain":
        res = Explain(key=Explain.__key)
        res.__explanation_dags.append(value)
        res.__state = Explain.State.SERIALIZED
        res.__answer_set = the_answer_set
        res.__atoms_to_explain = the_atoms_to_explain
        res.__additional_atoms_in_the_base = the_additional_atoms_in_the_base
        res.__state = Explain.State.EXPLANATION_DAG_COMPUTED
        return res

    def process_aggregates(self) -> None:
        if self.__state >= Explain.State.AGGREGATE_PROCESSED:
            return
        if self.__state < Explain.State.SERIALIZED:
            self.__compute_serialization()
        validate("state", self.__state, equals=Explain.State.SERIALIZED)
        self.__serialization = self.__process_aggregates()
        self.__state = Explain.State.AGGREGATE_PROCESSED

    def compute_atoms_explained_by_initial_well_founded(self) -> None:
        if self.__state >= Explain.State.WELL_FOUNDED_COMPUTED:
            return
        if self.__state < Explain.State.AGGREGATE_PROCESSED:
            self.process_aggregates()
        validate("state", self.__state, equals=Explain.State.AGGREGATE_PROCESSED)
        self.__atoms_explained_by_initial_well_founded = self.__compute_atoms_explained_by_initial_well_founded()
        self.__state = Explain.State.WELL_FOUNDED_COMPUTED

    def compute_minimal_assumption_set(self, repeat: Union[int, PositiveIntegerOrUnbounded] = 1) -> None:
        if type(repeat) is int:
            repeat = PositiveIntegerOrUnbounded.of(repeat)
        if self.__state < Explain.State.WELL_FOUNDED_COMPUTED:
            self.compute_atoms_explained_by_initial_well_founded()
        validate("state", self.__state, min_value=Explain.State.WELL_FOUNDED_COMPUTED)
        repeat += len(self.__minimal_assumption_sets)
        while repeat.greater_than(len(self.__minimal_assumption_sets)):
            assumption_set = self.__compute_minimal_assumption_set()
            if assumption_set is None:
                break
            self.__minimal_assumption_sets.append(assumption_set)
        self.__state = max(self.__state, Explain.State.MINIMAL_ASSUMPTION_SET_COMPUTED)

    def compute_explanation_sequence(self, repeat: Union[int, PositiveIntegerOrUnbounded] = 1) -> None:
        if type(repeat) is int:
            repeat = PositiveIntegerOrUnbounded.of(repeat)
        if self.__state < Explain.State.MINIMAL_ASSUMPTION_SET_COMPUTED:
            self.compute_minimal_assumption_set()
        validate("state", self.__state, min_value=Explain.State.MINIMAL_ASSUMPTION_SET_COMPUTED)
        repeat += len(self.__explanation_sequences)
        while repeat.greater_than(len(self.__explanation_sequences)):
            explanation = self.__compute_explanation_sequence()
            if explanation is not None:
                self.__explanation_sequences.append(explanation)
            else:
                assumption_sets = len(self.__minimal_assumption_sets)
                self.compute_minimal_assumption_set()
                if len(self.__minimal_assumption_sets) == assumption_sets:
                    break
        self.__state = max(self.__state, Explain.State.EXPLANATION_SEQUENCE_COMPUTED)

    def compute_explanation_dag(self, repeat: Union[int, PositiveIntegerOrUnbounded] = 1) -> None:
        if type(repeat) is int:
            repeat = PositiveIntegerOrUnbounded.of(repeat)
        if self.__state < Explain.State.EXPLANATION_SEQUENCE_COMPUTED:
            self.compute_explanation_sequence()
        validate("state", self.__state, min_value=Explain.State.EXPLANATION_SEQUENCE_COMPUTED)
        repeat += len(self.__explanation_dags)
        while repeat.greater_than(len(self.__explanation_dags)):
            dag = self.__compute_explanation_dag()
            if dag is not None:
                self.__explanation_dags.append(dag)
            else:
                sequences = len(self.__explanation_sequences)
                self.compute_explanation_sequence()
                if len(self.__explanation_sequences) == sequences:
                    break
        self.__state = Explain.State.EXPLANATION_DAG_COMPUTED

    def compute_igraph(self, index: int = -1) -> None:
        validate("answer_set", self.__answer_set, help_msg="Answer set was not provided")
        validate("atoms_to_explain", self.__atoms_to_explain, help_msg="Atoms to explain were not provided")
        validate("additional_atoms_in_the_base", self.__additional_atoms_in_the_base,
                 help_msg="Additional atoms were not provided")
        validate("must have a DAG", self.explanation_dag(index), help_msg="No DAG with the given index")
        while len(self.__igraph) < self.explanation_dags:
            self.__igraph.append(None)
        if self.__igraph[index] is None:
            self.__igraph[index] = self.__compute_igraph(dag=self.__explanation_dags[index])
        self.__state = max(self.__state, Explain.State.IGRAPH_COMPUTED)

    def save_igraph(self, filename: Path, index: int = -1, **kwargs) -> None:
        self.compute_igraph(index)
        igraph.plot(
            self.__igraph[index],
            layout=self.__igraph[index].layout_sugiyama(),
            margin=140,
            target=filename,
            vertex_label_dist=2,
            vertex_size=8,
            **kwargs,
        )

    def show_navigator_graph(self, index: int = -1) -> None:
        self.compute_igraph(index)
        url = "https://xasp-navigator.alviano.net/#"
        # url = "http://localhost:5173/#"
        url += compress_object_for_url(self.navigator_graph(index))
        webbrowser.open(url, new=0, autoraise=True)

    @property
    def asp_program(self) -> Optional[str]:
        return self.__asp_program

    @property
    def answer_set(self) -> Optional[Model]:
        return self.__answer_set

    @property
    def atoms_to_explain(self) -> Optional[Model]:
        return self.__atoms_to_explain

    @property
    def additional_atoms_in_the_base(self) -> Optional[Model]:
        return self.__additional_atoms_in_the_base

    @property
    def serialization(self) -> Model:
        validate("state", self.__state, min_value=Explain.State.SERIALIZED)
        return self.__serialization

    @property
    def atoms_explained_by_initial_well_founded(self) -> Model:
        if self.__state < Explain.State.WELL_FOUNDED_COMPUTED:
            self.compute_atoms_explained_by_initial_well_founded()
        validate("state", self.__state, min_value=Explain.State.WELL_FOUNDED_COMPUTED)
        return self.__atoms_explained_by_initial_well_founded

    @property
    def minimal_assumption_sets(self) -> int:
        return len(self.__minimal_assumption_sets)

    def minimal_assumption_set(self, index: int = -1) -> Model:
        call_with_difference_if_invalid_index(index, self.minimal_assumption_sets, self.compute_minimal_assumption_set)
        return self.__minimal_assumption_sets[index]

    @property
    def explanation_sequences(self) -> int:
        return len(self.__explanation_sequences)

    def explanation_sequence(self, index: int = -1) -> Model:
        call_with_difference_if_invalid_index(index, self.explanation_sequences, self.compute_explanation_sequence)
        return self.__explanation_sequences[index]

    @property
    def explanation_dags(self) -> int:
        return len(self.__explanation_dags)

    def explanation_dag(self, index: int = -1) -> Model:
        call_with_difference_if_invalid_index(index, self.explanation_dags, self.compute_explanation_dag)
        return self.__explanation_dags[index]

    def navigator_graph(self, index: int = -1) -> Dict:
        self.compute_igraph(index)
        graph = self.__igraph[index]
        layout = graph.layout_sugiyama()
        res = {
            "nodes": [
                {
                    "id": index,
                    "label": node.attributes()["label"],
                    "x": layout.coords[index][0],
                    "y": layout.coords[index][1],
                }
                for index, node in enumerate(graph.vs)
            ],
            "links": [
                {
                    "source": link.tuple[0],
                    "target": link.tuple[1],
                    "label": link.attributes()["label"],
                }
                for link in graph.es
            ],
        }
        return res

    @staticmethod
    def compute_stable_model(asp_program: str, context: Optional[Any] = None) -> Optional[Model]:
        control = clingo.Control()
        control.add("base", [], asp_program)
        control.ground([("base", [])], context=context)
        try:
            return Model.of_control(control)
        except Model.NoModelError:
            return None
    
    def __compute_serialization(self) -> None:
        validate("state", self.__state, equals=Explain.State.INITIAL)

        strongly_negated_atoms = {str(atom)[1:] for atom in self.answer_set if str(atom).startswith('-')}
        strongly_negated_atoms.update(str(atom)[1:] for atom in self.additional_atoms_in_the_base
                                      if str(atom).startswith('-'))
        strongly_negated_atoms.update(str(atom)[1:] for atom in self.atoms_to_explain if str(atom).startswith('-'))

        transformer = ProgramSerializerTransformer()
        transformed_program = transformer.apply(self.asp_program + '\n'.join(f":- {atom}, -{atom}."
                                                                             for atom in strongly_negated_atoms))
        model = self.compute_stable_model(
            SERIALIZATION_ENCODING + transformed_program +
            '\n'.join(f"true({atom})." for atom in self.answer_set) +
            '\n'.join(f"atom({atom})." for atom in self.additional_atoms_in_the_base) +
            '\n'.join(f"explain({atom})." for atom in self.atoms_to_explain)
        )
        self.__serialization = model
        self.__state = max(self.__state, Explain.State.SERIALIZED)

    def __process_aggregates(self) -> Model:
        res = self.compute_stable_model(
            PROCESS_AGGREGATES_ENCODING + self.serialization.as_facts,
            context=ProcessAggregatesContext()
        )
        validate("res", res, help_msg="No stable model. The input is likely wrong.")
        return res

    def __compute_atoms_explained_by_initial_well_founded(self) -> Model:
        encoding = WELL_FOUNDED_ENCODING + self.serialization.as_facts
        return self.compute_stable_model(encoding, context=ComputeWellFoundedContext())

    def __compute_minimal_assumption_set(self) -> Optional[Model]:
        while len(self.__minimal_assumption_sets_block_constraints) < len(self.__minimal_assumption_sets):
            validate("can enumerate", self.atoms_to_explain, max_len=1,
                     help_msg="At most one atom to explain must be passed to the factory method")
            mas = self.__minimal_assumption_sets[len(self.__minimal_assumption_sets_block_constraints)]
            self.__minimal_assumption_sets_block_constraints.append(mas.block_up)
            if len(self.atoms_to_explain) > 0 and len(self.__minimal_assumption_sets_block_constraints) == 1:
                atom = f"assume_false({self.atoms_to_explain[0]})"
                self.__minimal_assumption_sets_block_constraints[0] += \
                    f"\n:- {'not ' if atom in (str(x) for x in mas) else ''}{atom}."
        encoding = MINIMAL_ASSUMPTION_SET_ENCODING + EXPLAIN_ENCODING + \
                   self.serialization.as_facts + \
                   self.atoms_explained_by_initial_well_founded.as_facts + \
                   '\n'.join(constraint for constraint in self.__minimal_assumption_sets_block_constraints)
        res = self.compute_stable_model(encoding)
        if not self.__minimal_assumption_sets:
            validate("res", res, help_msg="No stable model. The input is likely wrong.")
        return res

    def __compute_explanation_sequence(self) -> Optional[Model]:
        instance: Final = self.minimal_assumption_set(-1).as_facts + \
                          self.serialization.as_facts + \
                          self.atoms_explained_by_initial_well_founded.as_facts
        encoding = EXPLANATION_ENCODING + EXPLAIN_ENCODING + instance + \
                   '\n'.join(model.project(Predicate.parse("explained_by/3"), 1).block_up
                             for model in self.__explanation_sequences)
        res = self.compute_stable_model(encoding, context=ComputeExplanationContext())

        if res is None:
            validate("must have an explanation", self.__explanation_sequences, min_len=1,
                     help_msg="No stable model. The input is likely wrong.")
            return None

        encoding = INDEXED_EXPLAIN_ENCODING + instance + res.as_facts
        res = self.compute_stable_model(encoding, context=ComputeExplanationContext())
        assert res is not None

        def fun(atom: GroundAtom) -> GroundAtom:
            fun.index += 1
            return GroundAtom(clingo.Function(atom.predicate_name,
                                              [clingo.Number(fun.index)] + list(atom.arguments[1:])))

        fun.index = 0

        return res.map(fun)

    def __compute_explanation_dag(self) -> Optional[Model]:
        encoding = EXPLANATION_DAG_ENCODING + self.serialization.as_facts + \
                   self.__explanation_sequences[-1].as_facts + \
                   '\n'.join(model.filter(lambda atom: atom.arguments[-1].type != clingo.SymbolType.String)
                             .substitute(Predicate.parse("link/2"), 1, clingo.Function("_")).block_up
                             for model in self.__explanation_dags)
        res = self.compute_stable_model(encoding, context=ComputeExplanationContext())
        if not self.__explanation_dags:
            validate("res", res, help_msg="No stable model. The input is likely wrong.")
        return res

    def __compute_igraph(self, dag: Model) -> igraph.Graph:
        graph = igraph.Graph(directed=True)

        rules = {}
        for rule in dag.drop(Predicate.parse("link/4")):
            validate("predicate", rule.predicate_name, equals="original_rule")
            rule_index = str(rule.arguments[0])
            b64 = rule.arguments[1].string
            variables = rule.arguments[2].string
            rules[rule_index] = (base64.b64decode(b64).decode(), variables)

        for link in dag.drop(Predicate.parse("original_rule/3")):
            validate("link name", link.predicate_name, equals="link")
            source = str(link.arguments[1])
            label = link.arguments[2]
            sink = str(link.arguments[3])
            reason = self.__link_reason(rules, label).split('\n', maxsplit=1)
            color = GRAPH_COLOR[reason[0]]
            if len(graph.vs) == 0 or len(graph.vs.select(name=source)) == 0:
                graph.add_vertex(source, color=color, label=f"{source}\n{reason[0]}")
            if sink not in ['"true"', '"false"']:
                if sink == '"#true"' and len(graph.vs.select(name=sink)) == 0:
                    graph.add_vertex(sink, color=color, label=f"#true")
                validate(f"{sink} is present", graph.vs.select(name=sink), length=1)
                graph.add_edge(source, sink, color=color, label=reason[1] if len(reason) > 1 else None)

        if len(self.__atoms_to_explain) == 0:
            return graph

        reachable_nodes = graph.neighborhood(
            vertices=[str(atom) for atom in self.__atoms_to_explain],
            order=len(graph.vs),
            mode="out"
        )
        nodes = []
        for reachable_nodes_element in reachable_nodes:
            nodes.extend(reachable_nodes_element)
        return graph.induced_subgraph(list(set(nodes)))

    @staticmethod
    def __link_reason(rules, label: clingo.Symbol) -> str:
        if label.name in ["assumption", "initial_well_founded"]:
            return label.name.replace('_', ' ')
        validate("name", label.name, equals="")
        validate("arguments", label.arguments, length=2)
        rule, variables = rules[
            label.arguments[1].name if label.arguments[1].name.startswith("r") else str(label.arguments[1])
        ]
        return f"{label.arguments[0].name.replace('_', ' ')}\n{rule}" + \
            (f"\n{variables} => {','.join(str(x) for x in label.arguments[1].arguments)}"
             if label.arguments[1].arguments else "")


GRAPH_COLOR: Final = {
    "support": "#90EE90",  # lightgreen
    "assumption": "#800080",  # purple
    "initial well founded": "#8B0000",  # darkred
    "lack of support": "#FF0000",  # red
    "choice rule": "#F08080",  # lightcoral
    "required to falsify body": "#FF8C00",  # dark orange
}

PROCESS_AGGREGATES_ENCODING: Final = """
%******************************************************************************
Enrich the representation of a program with aggregates so that minimal assumption sets can be computed with respect to 
a program without aggregates.


__RUN__

$ cat input.asp | clingo /dev/stdin process_aggregates.asp --outf=1 | sed -n '6 p'


__INPUT FORMAT__

Each rule of the program is encoded by facts of the form
- rule(RULE_ID)
- original_rule(RULE_INDEX, BASE64, VARIABLES)
- choice(RULE_ID, LOWER_BOUND, UPPER_BOUND)
- head(RULE_ID, ATOM)
- pos_body(RULE_ID, ATOM|AGGREGATE)
- neg_body(RULE_ID, ATOM)

Each aggregate of the program is encoded by facts of the form
- aggregate(AGG, FUN, OPERATOR, BOUNDS)
- agg_set(AGG, ATOM, WEIGHT, TERMS)

The answer set is encoded by facts of the form
- true(ATOM)
- false(ATOM)

Atoms to explain, which cannot be assumed false are encoded by
- explain(ATOM)

******************************************************************************%

% compute true aggregates
true_aggregate(Agg) :- aggregate(Agg, Fun, Operator, Bounds), Fun == sum;
    Value = #sum{Weight, Terms : agg_set(Agg, Atom, Weight, Terms), true(Atom)};
    @check_operator(Operator, Bounds, Value) = 1.
true_aggregate(Agg) :- aggregate(Agg, Fun, Operator, Bounds), Fun == count;
    Value = #count{Weight, Terms : agg_set(Agg, Atom, Weight, Terms), true(Atom)};
    @check_operator(Operator, Bounds, Value) = 1.
true_aggregate(Agg) :- aggregate(Agg, Fun, Operator, Bounds), Fun == min;
    Value = #min{Weight, Terms : agg_set(Agg, Atom, Weight, Terms), true(Atom)};
    @check_operator(Operator, Bounds, Value) = 1.
true_aggregate(Agg) :- aggregate(Agg, Fun, Operator, Bounds), Fun == max;
    Value = #max{Weight, Terms : agg_set(Agg, Atom, Weight, Terms), true(Atom)};
    @check_operator(Operator, Bounds, Value) = 1.

% every aggregate that is not true, is false
false_aggregate(Agg) :- aggregate(Agg, Fun, Operator, Bounds); not true_aggregate(Agg).

% true aggregates are considered as rules of the form  agg :- true_atoms_in_agg_set, ~false_atoms_in_agg_set.
rule(Agg) :- true_aggregate(Agg).
head(Agg,Agg) :- true_aggregate(Agg).
pos_body(Agg,Atom) :- true_aggregate(Agg), agg_set(Agg,Atom,Weight,Terms), true(Atom).
neg_body(Agg,Atom) :- true_aggregate(Agg), agg_set(Agg,Atom,Weight,Terms), false(Atom).

% false aggregates are considered as several rules of the form  agg :- ~true_atom_in_agg_set.   agg :- false_atom_in_agg_set.
rule((Agg,Atom)) :- false_aggregate(Agg), agg_set(Agg,Atom,Weight,Terms).
head((Agg,Atom),Agg) :- false_aggregate(Agg), agg_set(Agg,Atom,Weight,Terms).
pos_body((Agg,Atom),Atom) :- false_aggregate(Agg), agg_set(Agg,Atom,Weight,Terms), false(Atom).
neg_body((Agg,Atom),Atom) :- false_aggregate(Agg), agg_set(Agg,Atom,Weight,Terms), true(Atom).


#show.
#show rule/1.
#show original_rule/3.
#show choice/3.
#show head/2.
#show pos_body/2.
#show neg_body/2.
#show true/1.
#show false/1.
#show explain/1.
#show aggregate(Agg) : aggregate(Agg, Fun, Operator, Bounds).
#show true(Agg) : true_aggregate(Agg).
#show false(Agg) : false_aggregate(Agg).


% avoid warnings
rule(0) :- #false.
original_rule(0,0,0) :- #false.
choice(0,0,0) :- #false.
head(0,0) :- #false.
pos_body(0,0) :- #false.
neg_body(0,0) :- #false.
aggregate(0,0,0,0) :- #false.
agg_set(0,0,0,0) :- #false.
true(0) :- #false.
false(0) :- #false.
explain(0) :- #false.
"""

EXPLAIN_ENCODING: Final = """
%******************************************************************************
__INPUT FORMAT__

Each rule of the program is encoded by facts of the form
- rule(RULE_ID)
- head(RULE_ID, ATOM)
- pos_body(RULE_ID, ATOM|AGGREGATE)
- neg_body(RULE_ID, ATOM)
- choice(RULE_ID, LOWER_BOUND, UPPER_BOUND)

Aggregates are identified by facts of the form
- aggregate(AGGREGATE)

The answer set is encoded by facts of the form
- true(ATOM|AGGREGATE)
- false(ATOM|AGGREGATE)

Atoms explained by initial well founded are encoded by facts of the form
- explained_by(ATOM, initial_well_founded)

******************************************************************************%

% all atoms need to be explained by exactly one reason
atom(Atom) :- true(Atom).
atom(Atom) :- false(Atom).
:- atom(Atom), #count{Reason: explained_by(Atom,Reason)} != 1.
has_explanation(Atom) :- explained_by(Atom,_).


% assumed false atoms are explained (by assumption)
explained_by(Atom, assumption) :- assume_false(Atom).


% true atoms can be explained by a supporting rule whose body literals already have an explanation
{explained_by(Atom, (support, Rule))} :- 
  true(Atom);
  head(Rule,Atom);
  true(BAtom) : pos_body(Rule,BAtom);
  has_explanation(BAtom) : pos_body(Rule,BAtom);
  false(BAtom) : neg_body(Rule,BAtom);
  has_explanation(BAtom) : neg_body(Rule,BAtom).


% explain false atoms : begin

    % false atoms can be explained if all the possibly supporting rules already have an explanation
    {explained_by(Atom, lack_of_support)} :-
      false(Atom);
      false_body(Rule) : head(Rule,Atom).

    % a non-supporting rule is explained if there is some false body literal that already has an explanation
    false_body(Rule) :-
      rule(Rule);
      pos_body(Rule,BAtom), false(BAtom), has_explanation(BAtom).
    false_body(Rule) :-
      rule(Rule);
      neg_body(Rule,BAtom), true(BAtom), has_explanation(BAtom).


    % a false atom can be explained by a rule with false head and whose body contains the false atom, and all other body literals are true
    {explained_by(Atom, (required_to_falsify_body, Rule))} :-
      false(Atom), not aggregate(Atom);
      pos_body(Rule,Atom), false_head(Rule);
      true(BAtom) : pos_body(Rule,BAtom), BAtom != Atom;
      has_explanation(BAtom) : pos_body(Rule,BAtom), BAtom != Atom;
      false(BAtom) : neg_body(Rule,BAtom);
      has_explanation(BAtom) : neg_body(Rule,BAtom).
    explained_head(Rule) :-
      rule(Rule);
      has_explanation(HAtom) : head(Rule,HAtom).
    false_head(Rule) :- 
      explained_head(Rule), not choice(Rule,_,_);
      false(HAtom) : head(Rule,HAtom).
    false_head(Rule) :-
      explained_head(Rule), choice(Rule, LowerBound, UpperBound); 
      not LowerBound <= #count{HAtom : head(Rule,HAtom), true(HAtom)} <= UpperBound.

    % a false atom can be explained by a choice rule with true body and whose true head atoms already reach the upper bound
    {explained_by(Atom, (choice_rule, Rule))} :-
      false(Atom);
      head(Rule,Atom), choice(Rule, LowerBound, UpperBound), UpperBound != unbounded;
      true(BAtom) : pos_body(Rule,BAtom);
      has_explanation(BAtom) : pos_body(Rule,BAtom);
      false(BAtom) : neg_body(Rule,BAtom);
      has_explanation(BAtom) : neg_body(Rule,BAtom);
      #count{HAtom : head(Rule, HAtom), true(HAtom), has_explanation(HAtom)} = UpperBound.

% explain false atoms : end


% avoid warnings
rule(0) :- #false.
choice(0,0,0) :- #false.
head(0,0) :- #false.
pos_body(0,0) :- #false.
neg_body(0,0) :- #false.
aggregate(0) :- #false.
true(0) :- #false.
false(0) :- #false.
explained_by(0,initial_well_founded) :- #false.
"""

INDEXED_EXPLAIN_ENCODING: Final = """
%******************************************************************************
__INPUT FORMAT__

Each rule of the program is encoded by facts of the form
- rule(RULE_ID)
- head(RULE_ID, ATOM)
- pos_body(RULE_ID, ATOM|AGGREGATE)
- neg_body(RULE_ID, ATOM)
- choice(RULE_ID, LOWER_BOUND, UPPER_BOUND)

Aggregates are identified by facts of the form
- aggregate(AGGREGATE)

Atoms to explain are encoded by
- explain(ATOM)

The answer set is encoded by facts of the form
- true(ATOM|AGGREGATE)
- false(ATOM|AGGREGATE)

******************************************************************************%

has_explanation(Atom) :- indexed_explained_by(_,Atom,_).

indexed_explained_by(@index(), Atom, assumption) :- assume_false(Atom).
indexed_explained_by(@index(), Atom, initial_well_founded) :- false(Atom), explained_by(Atom, initial_well_founded).

% true atoms can be explained by a supporting rule whose body literals already have an explanation
indexed_explained_by(@index(), Atom, (support, Rule)) :-
  explained_by(Atom, (support, Rule));
  true(Atom);
  head(Rule,Atom);
  true(BAtom) : pos_body(Rule,BAtom);
  has_explanation(BAtom) : pos_body(Rule,BAtom);
  false(BAtom) : neg_body(Rule,BAtom);
  has_explanation(BAtom) : neg_body(Rule,BAtom).


% explain false atoms : begin

    % false atoms can be explained if all the possibly supporting rules already have an explanation
    indexed_explained_by(@index(), Atom, lack_of_support) :-
      explained_by(Atom, lack_of_support);
      false(Atom);
      false_body(Rule) : head(Rule,Atom).

    % a non-supporting rule is explained if there is some false body literal that already has an explanation
    false_body(Rule) :-
      rule(Rule);
      pos_body(Rule,BAtom), false(BAtom), has_explanation(BAtom).
    false_body(Rule) :-
      rule(Rule);
      neg_body(Rule,BAtom), true(BAtom), has_explanation(BAtom).


    % a false atom can be explained by a rule with false head and whose body contains the false atom, and all other body literals are true
    indexed_explained_by(@index(), Atom, (required_to_falsify_body, Rule)) :-
      explained_by(Atom, (required_to_falsify_body, Rule));
      false(Atom), not aggregate(Atom);
      pos_body(Rule,Atom), false_head(Rule);
      true(BAtom) : pos_body(Rule,BAtom), BAtom != Atom;
      has_explanation(BAtom) : pos_body(Rule,BAtom), BAtom != Atom;
      false(BAtom) : neg_body(Rule,BAtom);
      has_explanation(BAtom) : neg_body(Rule,BAtom).
    explained_head(Rule) :-
      rule(Rule);
      has_explanation(HAtom) : head(Rule,HAtom).
    false_head(Rule) :-
      explained_head(Rule), not choice(Rule,_,_);
      false(HAtom) : head(Rule,HAtom).
    false_head(Rule) :-
      explained_head(Rule), choice(Rule, LowerBound, UpperBound);
      not LowerBound <= #count{HAtom : head(Rule,HAtom), true(HAtom)} <= UpperBound.

    % a false atom can be explained by a choice rule with true body and whose true head atoms already reach the upper bound
    indexed_explained_by(@index(), Atom, (choice_rule, Rule)) :-
      explained_by(Atom, (choice_rule, Rule));
      false(Atom);
      head(Rule,Atom), choice(Rule, LowerBound, UpperBound), UpperBound != unbounded;
      true(BAtom) : pos_body(Rule,BAtom);
      has_explanation(BAtom) : pos_body(Rule,BAtom);
      false(BAtom) : neg_body(Rule,BAtom);
      has_explanation(BAtom) : neg_body(Rule,BAtom);
      #count{HAtom : head(Rule, HAtom), true(HAtom), has_explanation(HAtom)} = UpperBound.

% explain false atoms : end


% keep only atoms connected to the query : begin

    relevant(Atom) :- explain(Atom).
    relevant(Atom) :- not explain(_); indexed_explained_by(_, Atom, _).

    relevant(Atom') :-
        relevant(Atom), indexed_explained_by(Index, Atom, (support, Rule));
        pos_body(Rule, Atom').
    relevant(Atom') :-
        relevant(Atom), indexed_explained_by(Index, Atom, (support, Rule));
        neg_body(Rule, Atom').

    relevant(Atom') :-
        relevant(Atom), indexed_explained_by(Index, Atom, (lack_of_support));
        head(Rule, Atom);
        pos_body(Rule, Atom'), false(Atom'), indexed_explained_by(Index', Atom', _), Index' < Index.
    relevant(Atom') :-
        relevant(Atom), indexed_explained_by(Index, Atom, (lack_of_support));
        head(Rule, Atom);
        neg_body(Rule, Atom'), true(Atom'), indexed_explained_by(Index', Atom', _), Index' < Index.

    relevant(Atom') :-
        relevant(Atom), indexed_explained_by(Index, Atom, (required_to_falsify_body, Rule));
        head(Rule, Atom').
    relevant(Atom') :-
        relevant(Atom), indexed_explained_by(Index, Atom, (required_to_falsify_body, Rule));
        pos_body(Rule, Atom').
    relevant(Atom') :-
        relevant(Atom), indexed_explained_by(Index, Atom, (required_to_falsify_body, Rule));
        neg_body(Rule, Atom').

    relevant(Atom') :-
        relevant(Atom), indexed_explained_by(Index, Atom, (choice_rule, Rule));
        head(Rule, Atom'), true(Atom').
    relevant(Atom') :-
        relevant(Atom), indexed_explained_by(Index, Atom, (choice_rule, Rule));
        pos_body(Rule, Atom').
    relevant(Atom') :-
        relevant(Atom), indexed_explained_by(Index, Atom, (choice_rule, Rule));
        neg_body(Rule, Atom').

% keep only atoms connected to the query : end

#show.
#show explained_by(Index, Atom, Reason) : indexed_explained_by(Index, Atom, Reason), relevant(Atom).

% avoid warnings
rule(0) :- #false.
choice(0,0,0) :- #false.
head(0,0) :- #false.
pos_body(0,0) :- #false.
neg_body(0,0) :- #false.
aggregate(0) :- #false.
explain(0) :- #false.
true(0) :- #false.
false(0) :- #false.
explained_by(0,0) :- #false.
assume_false(0) :- #false.
"""

MINIMAL_ASSUMPTION_SET_ENCODING: Final = """
%******************************************************************************
Compute minimal assumption sets for a program wrt. an answer set.
If the atom to explain is false, the considered assumption sets will not assume its falsity.

__INPUT FORMAT__

Everything from EXPLAIN_ENCODING.

Atoms to explain, which cannot be assumed false are encoded by
- explain(ATOM)

******************************************************************************%


% guess the assumption set and minimize its cardinality
%   aggregates cannot be assumed false
%   atoms to explain should not be assumed false
{assume_false(Atom)} :- false(Atom), not aggregate(Atom).
:~ false(Atom), assume_false(Atom), not explain(Atom). [1@1, Atom]
:~ false(Atom), assume_false(Atom), explain(Atom). [1@2, Atom]


#show.
#show assume_false/1.

% avoid warnings
explain(0) :- #false.
"""

EXPLANATION_ENCODING: Final = """
%******************************************************************************
Compute explanation for a program wrt. an answer set and a minimal assumption set.

__INPUT FORMAT__

Everything from EXPLAIN_ENCODING.

For each atom in the minimal assumption set, the input must contain an atom of the form
- assume_false(ATOM)

******************************************************************************%


#show.
#show explained_by/2.

% avoid warnings
assume_false(0) :- #false.
"""

EXPLANATION_DAG_ENCODING: Final = """
%******************************************************************************
Compute explanation for a program wrt. an answer set and a minimal assumption set.

__INPUT FORMAT__

Each rule of the program is encoded by facts of the form
- rule(RULE_ID)
- original_rule(RULE_INDEX, BASE64, VARIABLES)
- head(RULE_ID, ATOM)
- pos_body(RULE_ID, ATOM|AGGREGATE)
- neg_body(RULE_ID, ATOM)
- choice(RULE_ID, LOWER_BOUND, UPPER_BOUND)

Aggregates are identified by facts of the form
- aggregate(AGGREGATE)

The answer set is encoded by facts of the form
- true(ATOM|AGGREGATE)
- false(ATOM|AGGREGATE)

For each atom in the answer set, the input must contain an atom of the form
- explained_by(INDEX, ATOM, REASON)
  where REASON is one of
  - assumption
  - initial_well_founded
  - (support, RULE)
  - lack_of_support
  - (required_to_falsify_body, Rule)
  - (choice_rule, Rule)
******************************************************************************%

link(Index, Atom, Reason, BAtom) :- explained_by(Index, Atom, Reason);
    Reason = (support, Rule);
    pos_body(Rule, BAtom).
link(Index, Atom, Reason, BAtom) :- explained_by(Index, Atom, Reason);
    Reason = (support, Rule);
    neg_body(Rule, BAtom).

{
    link(Index, Atom, (lack_of_support, Rule), BAtom) : 
        pos_body(Rule, BAtom), false(BAtom), explained_by(Index', BAtom, _), Index' < Index;
    link(Index, Atom, (lack_of_support, Rule), BAtom) : 
        neg_body(Rule, BAtom), true (BAtom), explained_by(Index', BAtom, _), Index' < Index
} = 1 :- 
    explained_by(Index, Atom, Reason);
    Reason = lack_of_support;
    head(Rule, Atom).

link(Index, Atom, Reason, HAtom) :- explained_by(Index, Atom, Reason);
    Reason = (required_to_falsify_body, Rule);
    head(Rule, HAtom).
link(Index, Atom, Reason, BAtom) :- explained_by(Index, Atom, Reason);
    Reason = (required_to_falsify_body, Rule);
    pos_body(Rule, BAtom), BAtom != Atom.
link(Index, Atom, Reason, BAtom) :- explained_by(Index, Atom, Reason);
    Reason = (required_to_falsify_body, Rule);
    neg_body(Rule, BAtom).

link(Index, Atom, Reason, HAtom) :- explained_by(Index, Atom, Reason);
    Reason = (choice_rule, Rule);
    head(Rule, HAtom), true(HAtom).
link(Index, Atom, Reason, BAtom) :- explained_by(Index, Atom, Reason);
    Reason = (choice_rule, Rule);
    pos_body(Rule, BAtom).
link(Index, Atom, Reason, BAtom) :- explained_by(Index, Atom, Reason);
    Reason = (choice_rule, Rule);
    neg_body(Rule, BAtom).

#show.
#show link(Index, Atom, Reason, Atom') : link(Index, Atom, Reason, Atom').
#show link(Index, Atom, Reason, "true") : explained_by(Index, Atom, Reason), true(Atom),
    #count{Atom' : link(Index, Atom, _, Atom')} = 0.
#show link(Index, Atom, Reason, "#true") : explained_by(Index, Atom, Reason), true(Atom),
    #count{Atom' : link(Index, Atom, _, Atom')} = 0, Reason = (support, Rule), choice(Rule, _, _).
#show link(Index, Atom, Reason, "false") : explained_by(Index, Atom, Reason), false(Atom),
    #count{Atom' : link(Index, Atom, _, Atom')} = 0.
#show original_rule/3.

% avoid warnings
rule(0) :- #false.
original_rule(0,0,0) :- #false.
choice(0,0,0) :- #false.
head(0,0) :- #false.
pos_body(0,0) :- #false.
neg_body(0,0) :- #false.
aggregate(0) :- #false.
true(0) :- #false.
false(0) :- #false.
explained_by(0,0,0) :- #false.
"""

SERIALIZATION_ENCODING: Final = """
atom(Atom) :- explain(Atom).
atom(Atom) :- true(Atom).
atom(Atom) :- head(Rule, Atom).
atom(Atom) :- pos_body(Rule, Atom), not aggregate(Atom,_,_,_).
atom(Atom) :- neg_body(Rule, Atom).
atom(Atom) :- agg_set(Aggregate, Atom, Weight, Terms).

false(Atom) :- atom(Atom), not true(Atom).

#show.
#show rule/1.
#show original_rule/3.
#show choice/3.
#show head/2.
#show pos_body/2.
#show neg_body/2.
#show aggregate/4.
#show agg_set/4.
#show true/1.
#show false/1.
#show explain/1.

% avoid warnings
rule(0) :- #false.
original_rule(0,0,0) :- #false.
head(0,0) :- #false.
choice(0,0,0) :- #false.
pos_body(0,0) :- #false.
neg_body(0,0) :- #false.
aggregate(0,0,0,0) :- #false.
agg_set(0,0,0,0) :- #false.
true(0) :- #false.
atom(0) :- #false.
explain(0) :- #false.
"""

WELL_FOUNDED_ENCODING: Final = """
%******************************************************************************
__INPUT FORMAT__

Each rule of the program is encoded by facts of the form
- rule(RULE_ID)
- head(RULE_ID, ATOM)
- pos_body(RULE_ID, ATOM|AGGREGATE)
- neg_body(RULE_ID, ATOM)

******************************************************************************%

collecting_rules :- rule(Rule), @collect_rule(Rule) != 1.
collecting_heads :- not collecting_rules, head(Rule,Atom), @collect_head(Rule,Atom) != 1.
collecting_pos_bodies :- not collecting_rules, pos_body(Rule,Atom), @collect_pos_body(Rule,Atom) != 1.
collecting_neg_bodies :- not collecting_rules, neg_body(Rule,Atom), @collect_neg_body(Rule,Atom) != 1.
collected_program :- not collecting_rules, not collecting_heads, not collecting_pos_bodies, not collecting_neg_bodies.

explained_by(Atom, initial_well_founded) :- collected_program; false(Atom), @false_in_well_founded_model(Atom) == 1.

#show.
#show explained_by/2.

% avoid warnings
rule(0) :- #false.
head(0,0) :- #false.
pos_body(0,0) :- #false.
neg_body(0,0) :- #false.
false(0) :- #false.
"""
