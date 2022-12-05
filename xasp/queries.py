from typing import Optional, Any, Final

import clingo

from xasp.contexts import ProcessAggregatesContext, ComputeMinimalAssumptionSetContext, ComputeExplanationContext
from xasp.primitives import Model
from xasp.transformers import ProgramSerializerTransformer
from xasp.utils import validate


def compute_stable_model(asp_program: str, context: Optional[Any] = None) -> Optional[Model]:
    control = clingo.Control()
    control.add("base", [], asp_program)
    control.ground([("base", [])], context=context)
    return Model.of(control)


def compute_serialization(asp_program: str, true_atoms: str, false_atoms: str,
                          false_atom_to_explain: Optional[str] = None) -> Model:
    transformer = ProgramSerializerTransformer()
    transformed_program = transformer.apply(asp_program)
    return compute_stable_model(
        SERIALIZATION_ENCODING + transformed_program +
        '\n'.join(f"true({atom})." for atom in true_atoms.split()) +
        '\n'.join(f"false({atom})." for atom in false_atoms.split()) +
        ('' if false_atom_to_explain is None else f"explain_false({false_atom_to_explain}).")
    )


def process_aggregates(to_be_explained_serialization: Model) -> Model:
    res = compute_stable_model(
        PROCESS_AGGREGATES_ENCODING + to_be_explained_serialization.as_facts(),
        context=ProcessAggregatesContext()
    )
    validate("res", res, help_msg="No stable model. The input is likely wrong.")
    return res


def compute_minimal_assumption_set(to_be_explained_serialization: Model) -> Model:
    encoding = MINIMAL_ASSUMPTION_SET_ENCODING + EXPLAIN_ENCODING + \
               process_aggregates(to_be_explained_serialization).as_facts()
    res = compute_stable_model(encoding, context=ComputeMinimalAssumptionSetContext())
    validate("res", res, help_msg="No stable model. The input is likely wrong.")
    return res


def compute_explanation(to_be_explained_serialization: Model) -> Model:
    assumption_set = compute_minimal_assumption_set(to_be_explained_serialization)
    encoding = EXPLANATION_ENCODING + EXPLAIN_ENCODING + assumption_set.as_facts() + \
               process_aggregates(to_be_explained_serialization).as_facts()
    res = compute_stable_model(encoding, context=ComputeExplanationContext())
    validate("res", res, help_msg="No stable model. The input is likely wrong.")
    return res


def compute_explanation_dag(to_be_explained_serialization: Model) -> Model:
    explanation = compute_explanation(to_be_explained_serialization)
    encoding = EXPLANATION_DAG_ENCODING + explanation.as_facts() + \
               process_aggregates(to_be_explained_serialization).as_facts()
    res = compute_stable_model(encoding, context=ComputeExplanationContext())
    validate("res", res, help_msg="No stable model. The input is likely wrong.")
    return res


PROCESS_AGGREGATES_ENCODING: Final = """
%******************************************************************************
Enrich the representation of a program with aggregates so that minimal assumption sets can be computed with respect to 
a program without aggregates.


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
true_aggregate(Agg) :- aggregate(Agg, Fun, Operator, Bounds), Fun == sum;
    Value = #sum{Weight, Atom : agg_set(Agg, Atom, Weight), true(Atom)};
    @check_operator(Operator, Bounds, Value) = 1.
true_aggregate(Agg) :- aggregate(Agg, Fun, Operator, Bounds), Fun == count;
    Value = #count{Weight, Atom : agg_set(Agg, Atom, Weight), true(Atom)};
    @check_operator(Operator, Bounds, Value) = 1.
true_aggregate(Agg) :- aggregate(Agg, Fun, Operator, Bounds), Fun == min;
    Value = #min{Weight, Atom : agg_set(Agg, Atom, Weight), true(Atom)};
    @check_operator(Operator, Bounds, Value) = 1.
true_aggregate(Agg) :- aggregate(Agg, Fun, Operator, Bounds), Fun == max;
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
head(0,0) :- #false.
pos_body(0,0) :- #false.
neg_body(0,0) :- #false.
aggregate(0,0,0,0) :- #false.
agg_set(0,0,0) :- #false.
true(0) :- #false.
false(0) :- #false.
explain_false(0) :- #false.
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

******************************************************************************%


has_explanation(Atom) :- explained_by(Atom,_).


% preliminaries : explain false atoms by well-founded model : begin

    collecting_rules :- rule(Rule), @collect_rule(Rule) != 1.
    collecting_heads :- not collecting_rules, head(Rule,Atom), @collect_head(Rule,Atom) != 1.
    collecting_pos_bodies :- not collecting_rules, pos_body(Rule,Atom), @collect_pos_body(Rule,Atom) != 1.
    collecting_neg_bodies :- not collecting_rules, neg_body(Rule,Atom), @collect_neg_body(Rule,Atom) != 1.
    collected_program :- not collecting_rules, not collecting_heads, not collecting_pos_bodies, not collecting_neg_bodies.

    explained_by(Atom, initial_well_founded) :- collected_program; false(Atom), @false_in_well_founded_model(Atom) == 1.

% preliminaries : explain false atoms by well-founded model : end



% all atoms need to be explained
:- true(X), not has_explanation(X).
:- false(X), not has_explanation(X).


% assumed false atoms are explained (by assumption)
explained_by(Atom, assumption) :- assume_false(Atom).


% true atoms can be explained by a supporting rule whose body literals already have an explanation
explained_by(Atom, (support, Rule)) :- 
  true(Atom), #count{Reason : explained_by(Atom, Reason), Reason != (support, Rule)} = 0;
  rule(Rule), head(Rule,Atom);
  true(BAtom) : pos_body(Rule,BAtom);
  has_explanation(BAtom) : pos_body(Rule,BAtom);
  false(BAtom) : neg_body(Rule,BAtom);
  has_explanation(BAtom) : neg_body(Rule,BAtom).


% explain false atoms : begin

    % false atoms can be explained if all the possibly supporting rules already have an explanation
    explained_by(Atom, lack_of_support) :-
      false(Atom), not assume_false(Atom), #count{Reason : explained_by(Atom, Reason), Reason != lack_of_support} = 0;
      has_explanation(Atom,Rule) : rule(Rule), head(Rule,Atom).

    % a non-supporting rule is explained if there is some false body literal that already has an explanation
    has_explanation(Atom,Rule) :-
      false(Atom), not assume_false(Atom);
      rule(Rule), head(Rule,Atom);
      pos_body(Rule,BAtom), false(BAtom), has_explanation(BAtom).
    has_explanation(Atom,Rule) :-
      false(Atom), not assume_false(Atom);
      rule(Rule), head(Rule,Atom);
      neg_body(Rule,BAtom), true(BAtom), has_explanation(BAtom).


    % a false atom can be explained by a rule with false head and whose body contains the false atom, and all other body literals are true
    explained_by(Atom, (required_to_falsify_body, Rule)) :-
      false(Atom), not assume_false(Atom), #count{Reason : explained_by(Atom, Reason), Reason != (required_to_falsify_body, Rule)} = 0;
      rule(Rule), not choice(Rule,_,_), pos_body(Rule,Atom);
      false(HAtom) : head(Rule,HAtom);
      has_explanation(HAtom) : head(Rule,HAtom);
      true(BAtom) : pos_body(Rule,BAtom), BAtom != Atom;
      has_explanation(BAtom) : pos_body(Rule,BAtom), BAtom != Atom;
      false(BAtom) : neg_body(Rule,BAtom);
      has_explanation(BAtom) : neg_body(Rule,BAtom).

    % a false atom can be explained by a choice rule with true body and whose true head atoms already reach the upper bound
    explained_by(Atom, (choice_rule, Rule)) :-
      false(Atom), not assume_false(Atom), #count{Reason : explained_by(Atom, Reason), Reason != (choice_rule, Rule)} = 0;
      choice(Rule, LowerBound, UpperBound), head(Rule,Atom);
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
aggregate(0,0,0,0) :- #false.
agg_set(0,0,0) :- #false.
true(0) :- #false.
false(0) :- #false.
"""

MINIMAL_ASSUMPTION_SET_ENCODING: Final = """
%******************************************************************************
Compute minimal assumption sets for a program wrt. an answer set.
If the atom to explain is false, the considered assumption sets will not assume its falsity.

__INPUT FORMAT__

Everything from EXPLAIN_ENCODING.

If the atom to explain is false, the input must contain one fact of the form
- explain_false(ATOM)

******************************************************************************%


% guess the assumption set and minimize its cardinality
{assume_false(Atom)} :- false(Atom).
:~ false(Atom), assume_false(Atom). [1@1, Atom]

% don't explain the target false atom simply by assumption (if possible, otherwise return UNSAT)
:- explain_false(Atom), assume_false(Atom).


#show.
#show assume_false/1.

% avoid warnings
explain_false(0) :- #false.
"""

EXPLANATION_ENCODING: Final = """
%******************************************************************************
Compute explanation for a program wrt. an answer set and a minimal assumption set.

__INPUT FORMAT__

Everything from EXPLAIN_ENCODING.

For each atom in the minimal assumption set, the input must contain an atom of the form
- assume_false(ATOM)

******************************************************************************%


% inject indexed_explained_by/3 in the loop of explained_by/2
indexed_explained_by(@index(), Atom, Explanation) :- explained_by(Atom, Explanation).  %, not aggregate(Atom).
explained_by(Atom, Explanation) :- indexed_explained_by(Index, Atom, Explanation).

#show.
#show indexed_explained_by/3.

% avoid warnings
assume_false(0) :- #false.
"""

EXPLANATION_DAG_ENCODING: Final = """
%******************************************************************************
Compute explanation for a program wrt. an answer set and a minimal assumption set.

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

For each atom in the answer set, the input must contain an atom of the form
- indexed_explained_by(INDEX, ATOM, REASON)
  where REASON is one of
  - assumption
  - initial_well_founded
  - (support, RULE)
  - lack_of_support
  - (required_to_falsify_body, Rule)
  - (choice_rule, Rule)
******************************************************************************%

link(Index, Atom, assumption, false) :- indexed_explained_by(Index, Atom, Reason);
    Reason = assumption.

link(Index, Atom, initial_well_founded, false) :- indexed_explained_by(Index, Atom, Reason);
    Reason = initial_well_founded.

link(Index, Atom, (support, Rule), true) :- indexed_explained_by(Index, Atom, Reason);
    Reason = (support, Rule);
    #count{BAtom : pos_body(Rule, BAtom); BAtom : neg_body(Rule, BAtom)} = 0.
link(Index, Atom, (support, Rule), (BAtom, true)) :- indexed_explained_by(Index, Atom, Reason);
    Reason = (support, Rule);
    pos_body(Rule, BAtom).
link(Index, Atom, (support, Rule), (BAtom, false)) :- indexed_explained_by(Index, Atom, Reason);
    Reason = (support, Rule);
    neg_body(Rule, BAtom).

link(Index, Atom, lack_of_support, false) :- indexed_explained_by(Index, Atom, Reason);
    Reason = lack_of_support;
    #count{Rule : head(Rule, Atom)} = 0.
link(Index, Atom, (lack_of_support, Rule), (BAtom, false)) :- indexed_explained_by(Index, Atom, Reason);
    Reason = lack_of_support;
    head(Rule, Atom);
    FirstIndex = #min{
        Index' : pos_body(Rule, BAtom'), false(BAtom'), indexed_explained_by(Index', BAtom', _);
        Index' : neg_body(Rule, BAtom'), true(BAtom'),  indexed_explained_by(Index', BAtom', _)
    };
    indexed_explained_by(FirstIndex, BAtom, _), pos_body(Rule, BAtom).
link(Index, Atom, (lack_of_support, Rule), (BAtom, true)) :- indexed_explained_by(Index, Atom, Reason);
    Reason = lack_of_support;
    head(Rule, Atom);
    FirstIndex = #min{
        Index' : pos_body(Rule, BAtom'), false(BAtom'), indexed_explained_by(Index', BAtom', _);
        Index' : neg_body(Rule, BAtom'), true(BAtom'),  indexed_explained_by(Index', BAtom', _)
    };
    indexed_explained_by(FirstIndex, BAtom, _), neg_body(Rule, BAtom).

link(Index, Atom, (required_to_falsify_body, Rule), false) :- indexed_explained_by(Index, Atom, Reason);
    Reason = (required_to_falsify_body, Rule);
    #count{HAtom : head(Rule, HAtom); BAtom: pos_body(Rule, BAtom); BAtom: neg_body(Rule, BAtom)} = 0.
link(Index, Atom, (required_to_falsify_body, Rule), (HAtom, true)) :- indexed_explained_by(Index, Atom, Reason);
    Reason = (required_to_falsify_body, Rule);
    head(Rule, HAtom).
link(Index, Atom, (required_to_falsify_body, Rule), (BAtom, true)) :- indexed_explained_by(Index, Atom, Reason);
    Reason = (required_to_falsify_body, Rule);
    pos_body(Rule, BAtom).
link(Index, Atom, (required_to_falsify_body, Rule), (BAtom, false)) :- indexed_explained_by(Index, Atom, Reason);
    Reason = (required_to_falsify_body, Rule);
    neg_body(Rule, BAtom).

link(Index, Atom, (choice_rule, Rule), false) :- indexed_explained_by(Index, Atom, Reason);
    Reason = (required_to_falsify_body, Rule);
    #count{HAtom : head(Rule, HAtom), true(HAtom); BAtom: pos_body(Rule, BAtom); BAtom: neg_body(Rule, BAtom)} = 0.
link(Index, Atom, (choice_rule, Rule), (HAtom, true)) :- indexed_explained_by(Index, Atom, Reason);
    Reason = (choice_rule, Rule);
    head(Rule, HAtom), true(HAtom).
link(Index, Atom, (choice_rule, Rule), (BAtom, true)) :- indexed_explained_by(Index, Atom, Reason);
    Reason = (choice_rule, Rule);
    pos_body(Rule, BAtom).
link(Index, Atom, (choice_rule, Rule), (BAtom, false)) :- indexed_explained_by(Index, Atom, Reason);
    Reason = (choice_rule, Rule);
    neg_body(Rule, BAtom).

#show.
#show link/4.

% avoid warnings
rule(0) :- #false.
choice(0,0,0) :- #false.
head(0,0) :- #false.
pos_body(0,0) :- #false.
neg_body(0,0) :- #false.
aggregate(0,0,0,0) :- #false.
agg_set(0,0,0) :- #false.
true(0) :- #false.
false(0) :- #false.
indexed_explained_by(0,0,0) :- #false.
"""

SERIALIZATION_ENCODING: Final = """
atom(Atom) :- true(Atom).
atom(Atom) :- false(Atom).

#show.
#show rule/1.
#show choice/3.
#show head/2.
#show pos_body/2.
#show neg_body/2.
#show aggregate/4.
#show agg_set/3.
#show true/1.
#show false/1.

% avoid warnings
rule(0) :- #false.
head(0,0) :- #false.
choice(0,0,0) :- #false.
pos_body(0,0) :- #false.
neg_body(0,0) :- #false.
aggregate(0,0,0,0) :- #false.
agg_set(0,0,0) :- #false.
true(0) :- #false.
false(0) :- #false.
"""