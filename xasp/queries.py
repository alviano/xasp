from typing import Optional, Any

import clingo

from xasp.contexts import ProcessAggregatesContext
from xasp.primitives import Model
from xasp.utils import validate


def compute_stable_model(asp_program: str, context: Optional[Any] = None) -> Optional[Model]:
    control = clingo.Control()
    control.add("base", [], asp_program)
    control.ground([("base", [])], context=context)
    return Model.of(control)


def process_aggregates(to_be_explained_serialization: str) -> Model:
    res = compute_stable_model("""
%******************************************************************************
Enrich the representation of a program with aggregates so that minimal
assumption sets can be computed with respect to a program without aggregates.


__RUN__

$ cat input.asp | clingo /dev/stdin process_aggregates.asp --outf=1 | sed -n '6 p'


__INPUT FORMAT__

Each rule of the program is encoded by facts of the form
- rule(RULE_ID)
- choice(RULE_ID, LOWER_BOUND, UPPER_BOUND)
- head(RULE_ID, ATOM)
- pos_body(RULE_ID, ATOM|AGGREGATE)
- neg_body(RULE_ID, ATOM)

Each aggregate of the program is encoded by facts of the form
- aggregate(AGG, FUN, OPERATOR, BOUNDS)
- agg_set(AGG, ATOM, WEIGHT)

The answer set is encoded by facts of the form
- true(ATOM)
- false(ATOM)

If the atom to explain is false, the input must contain one fact of the form
- explain_false(ATOM)

******************************************************************************%

% compute true aggregates
true_aggregate(Agg) :- aggregate(Agg, sum, Operator, Bounds);
    Value = #sum{Weight, Atom : agg_set(Agg, Atom, Weight), true(Atom)};
    @check_operator(Operator, Bounds, Value) = 1.
true_aggregate(Agg) :- aggregate(Agg, count, Operator, Bounds);
    Value = #count{Weight, Atom : agg_set(Agg, Atom, Weight), true(Atom)};
    @check_operator(Operator, Bounds, Value) = 1.
true_aggregate(Agg) :- aggregate(Agg, min, Operator, Bounds);
    Value = #min{Weight, Atom : agg_set(Agg, Atom, Weight), true(Atom)};
    @check_operator(Operator, Bounds, Value) = 1.
true_aggregate(Agg) :- aggregate(Agg, max, Operator, Bounds);
    Value = #max{Weight, Atom : agg_set(Agg, Atom, Weight), true(Atom)};
    @check_operator(Operator, Bounds, Value) = 1.

% every aggregate that is not true, is false
false_aggregate(Agg) :- aggregate(Agg, Fun, Operator, Bounds); not true_aggregate(Agg).

% true aggregates are considered as rules of the form  agg :- true_atoms_in_agg_set, ~false_atoms_in_agg_set.
rule(Agg) :- true_aggregate(Agg).
head(Agg,Agg) :- true_aggregate(Agg).
pos_body(Agg,Atom) :- true_aggregate(Agg), agg_set(Agg,Atom,Weight), true(Atom).
neg_body(Agg,Atom) :- true_aggregate(Agg), agg_set(Agg,Atom,Weight), false(Atom).

% false aggregates are considered as several rules of the form  agg :- ~true_atom_in_agg_set.   agg :- false_atom_in_agg_set.
rule((Agg,Atom)) :- false_aggregate(Agg), agg_set(Agg,Atom,Weight).
head((Agg,Atom),Agg) :- false_aggregate(Agg), agg_set(Agg,Atom,Weight).
pos_body((Agg,Atom),Atom) :- false_aggregate(Agg), agg_set(Agg,Atom,Weight), false(Atom).
neg_body((Agg,Atom),Atom) :- false_aggregate(Agg), agg_set(Aggr,Atom,Weight), true(Atom).


#show.
#show rule/1.
#show choice/3.
#show head/2.
#show pos_body/2.
#show neg_body/2.
#show true/1.
#show false/1.
#show explain_false/1.
#show aggregate(Agg) : aggregate(Agg, Fun, Operator, Bounds).
#show true(Agg) : true_aggregate(Agg).
#show false(Agg) : false_aggregate(Agg).


% avoid warnings
rule(0) :- #false.
choice(0,0,0) :- #false.
pos_body(0,0) :- #false.
neg_body(0,0) :- #false.
aggregate(0,0,0,0) :- #false.
agg_set(0,0,0) :- #false.
true(0) :- #false.
false(0) :- #false.
explain_false(0) :- #false.
    """ + to_be_explained_serialization, context=ProcessAggregatesContext())
    validate("res", res, help_msg="No stable model. The input is likely wrong.")
    return res
