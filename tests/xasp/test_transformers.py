import logging

import pytest

from xasp.transformers import ProgramSerializerTransformer

logging.getLogger().setLevel(logging.DEBUG)


@pytest.fixture
def program_serializer_transformer():
    return ProgramSerializerTransformer()


def equals(a, b):
    return sorted(a.split('\n')) == sorted([line.strip() for line in b.strip().split('\n')])


def test_transform_fact_propositional(program_serializer_transformer):
    assert equals(program_serializer_transformer.apply("a."), """
        rule(r1) :- .
            head(r1,a) :- rule(r1).
    """)


def test_transform_fact(program_serializer_transformer):
    assert equals(program_serializer_transformer.apply("a(1,b)."), """
        rule(r1) :- .
            head(r1,a(1,b)) :- rule(r1).
    """)


def test_transform_choice_propositional(program_serializer_transformer):
    assert equals(program_serializer_transformer.apply("{a}."), """
        rule(r1) :- .
            choice(r1,0,unbounded) :- rule(r1).
            head(r1,a) :- rule(r1).
    """)


def test_transform_head_must_be_atomic(program_serializer_transformer):
    with pytest.raises(ValueError):
        program_serializer_transformer.apply("a | b.")


def test_transform_datalog_rule_propositional(program_serializer_transformer):
    assert equals(program_serializer_transformer.apply("a :- b."), """
        rule(r1) :- atom(b).
            head(r1,a) :- rule(r1).
            pos_body(r1,b) :- rule(r1).
    """)


def test_transform_normal_rule_propositional(program_serializer_transformer):
    assert equals(program_serializer_transformer.apply("a :- not b."), """
        rule(r1) :- .
            head(r1,a) :- rule(r1).
            neg_body(r1,b) :- rule(r1).
    """)


def test_transform_choice_rule_with_body_propositional(program_serializer_transformer):
    assert equals(program_serializer_transformer.apply("{a} :- b."), """
        rule(r1) :- atom(b).
            choice(r1,0,unbounded) :- rule(r1).
            head(r1,a) :- rule(r1).
            pos_body(r1,b) :- rule(r1).
    """)


def test_transform_datalog_rule_ground(program_serializer_transformer):
    assert equals(program_serializer_transformer.apply("a(1) :- b(1)."), """
        rule(r1) :- atom(b(1)).
            head(r1,a(1)) :- rule(r1).
            pos_body(r1,b(1)) :- rule(r1).
    """)


def test_transform_normal_rule_ground(program_serializer_transformer):
    assert equals(program_serializer_transformer.apply("a(1) :- not b(1)."), """
        rule(r1) :- .
            head(r1,a(1)) :- rule(r1).
            neg_body(r1,b(1)) :- rule(r1).
    """)


def test_transform_choice_rule_ground(program_serializer_transformer):
    assert equals(program_serializer_transformer.apply("{a(1)} :- b(1)."), """
        rule(r1) :- atom(b(1)).
            choice(r1,0,unbounded) :- rule(r1).
            head(r1,a(1)) :- rule(r1).
            pos_body(r1,b(1)) :- rule(r1).
    """)


def test_transform_datalog_rule_symbolic(program_serializer_transformer):
    assert equals(program_serializer_transformer.apply("a(X) :- b(X)."), """
        rule(r1(X)) :- atom(b(X)).
            head(r1(X),a(X)) :- rule(r1(X)).
            pos_body(r1(X),b(X)) :- rule(r1(X)).
    """)


def test_transform_normal_rule_symbolic(program_serializer_transformer):
    assert equals(program_serializer_transformer.apply("a(X) :- b(X), not c(X)."), """
        rule(r1(X)) :- atom(b(X)).
            head(r1(X),a(X)) :- rule(r1(X)).
            pos_body(r1(X),b(X)) :- rule(r1(X)).
            neg_body(r1(X),c(X)) :- rule(r1(X)).
    """)


def test_transform_choice_rule_symbolic(program_serializer_transformer):
    assert equals(program_serializer_transformer.apply("{a(X)} :- b(X)."), """
        rule(r1(X)) :- atom(b(X)).
            choice(r1(X),0,unbounded) :- rule(r1(X)).
            head(r1(X),a(X)) :- rule(r1(X)).
            pos_body(r1(X),b(X)) :- rule(r1(X)).
    """)


def test_transform_datalog_rule_symbolic_multiple_variables(program_serializer_transformer):
    assert equals(program_serializer_transformer.apply("a(1,X) :- b(X,2,Y)."), """
        rule(r1(X,Y)) :- atom(b(X,2,Y)).
            head(r1(X,Y),a(1,X)) :- rule(r1(X,Y)).
            pos_body(r1(X,Y),b(X,2,Y)) :- rule(r1(X,Y)).
    """)


def test_transform_choice_rule_with_condition_must_have_one_element(program_serializer_transformer):
    with pytest.raises(ValueError):
        program_serializer_transformer.apply("{a(X) : c(X); b(X) : c(X)}.")


def test_transform_choice_rule_with_atomic_condition(program_serializer_transformer):
    assert equals(program_serializer_transformer.apply("{a(X) : b(X)} = 1."), """
        rule(r1) :- .
            choice(r1,1,1) :- rule(r1).
            head(r1,a(X)) :- rule(r1), true(b(X)).
    """)


def test_transform_choice_rule_multiple_atoms(program_serializer_transformer):
    assert equals(program_serializer_transformer.apply("{a; b; c}."), """
        rule(r1) :- .
            choice(r1,0,unbounded) :- rule(r1).
            head(r1,a) :- rule(r1).
            head(r1,b) :- rule(r1).
            head(r1,c) :- rule(r1).
    """)


def test_transform_choice_rule_with_bounds(program_serializer_transformer):
    assert equals(program_serializer_transformer.apply("1 <= {a; b; c} <= 1."), """
        rule(r1) :- .
            choice(r1,1,1) :- rule(r1).
            head(r1,a) :- rule(r1).
            head(r1,b) :- rule(r1).
            head(r1,c) :- rule(r1).
    """)


def test_transform_choice_rule_with_left_bound(program_serializer_transformer):
    assert equals(program_serializer_transformer.apply("1 <= {a; b; c}."), """
        rule(r1) :- .
            choice(r1,1,unbounded) :- rule(r1).
            head(r1,a) :- rule(r1).
            head(r1,b) :- rule(r1).
            head(r1,c) :- rule(r1).
    """)


def test_transform_choice_rule_with_right_bound(program_serializer_transformer):
    assert equals(program_serializer_transformer.apply("{a; b; c} <= 1."), """
        rule(r1) :- .
            choice(r1,0,1) :- rule(r1).
            head(r1,a) :- rule(r1).
            head(r1,b) :- rule(r1).
            head(r1,c) :- rule(r1).
    """)


def test_transform_choice_rule_with_equals(program_serializer_transformer):
    assert equals(program_serializer_transformer.apply("{a; b; c} = 1."), """
        rule(r1) :- .
            choice(r1,1,1) :- rule(r1).
            head(r1,a) :- rule(r1).
            head(r1,b) :- rule(r1).
            head(r1,c) :- rule(r1).
    """)


def test_transform_choice_rule_strange_bounds(program_serializer_transformer):
    with pytest.raises(ValueError):
        program_serializer_transformer.apply("2 >= {a; b; c} >= 1.")


def test_transform_choice_rule_not_equal_raises_error(program_serializer_transformer):
    with pytest.raises(ValueError):
        program_serializer_transformer.apply("{a; b; c} != 1.")


def test_transform_constraint(program_serializer_transformer):
    assert equals(program_serializer_transformer.apply(":- a."), """
        rule(r1) :- atom(a).
            pos_body(r1,a) :- rule(r1).
    """)


def test_transform_rule_with_negated_aggregate_raises_error(program_serializer_transformer):
    with pytest.raises(ValueError):
        program_serializer_transformer.apply("a :- not #sum{1 : a} = 0.")


def test_transform_propositional_rule_with_aggregate(program_serializer_transformer):
    assert equals(program_serializer_transformer.apply("a :- #sum{1 : b; 1 : c} >= 1."), """
        rule(r1) :- .
            head(r1,a) :- rule(r1).
            pos_body(r1,agg1) :- rule(r1).
        aggregate(agg1,sum,">=",1) :- rule(r1).
            agg_set(agg1,b,1,()) :- rule(r1), atom(b).
            agg_set(agg1,c,1,()) :- rule(r1), atom(c).
    """)


def test_transform_aggregate_with_negation_raises_error(program_serializer_transformer):
    with pytest.raises(ValueError):
        program_serializer_transformer.apply("a :- #sum{1 : not a} = 0.")


def test_transform_aggregate_with_two_bounds(program_serializer_transformer):
    assert equals(program_serializer_transformer.apply("a :- 1 <= #sum{1 : a} <= 1."), """
        rule(r1) :- .
            head(r1,a) :- rule(r1).
            pos_body(r1,agg1) :- rule(r1).
        aggregate(agg1,sum,"in",(1,1)) :- rule(r1).
            agg_set(agg1,a,1,()) :- rule(r1), atom(a).
    """)


def test_transform_aggregate_with_two_strict_bounds(program_serializer_transformer):
    assert equals(program_serializer_transformer.apply("a :- 0 < #sum{1 : a} < 2."), """
        rule(r1) :- .
            head(r1,a) :- rule(r1).
            pos_body(r1,agg1) :- rule(r1).
        aggregate(agg1,sum,"in",((0) + 1,(2) - 1)) :- rule(r1).
            agg_set(agg1,a,1,()) :- rule(r1), atom(a).
    """)


def test_transform_symbolic_rule_with_aggregate(program_serializer_transformer):
    assert equals(program_serializer_transformer.apply("a(X) :- b(X,Y), #sum{Z : c(X,Y,Z)} = Y."), """
        rule(r1(X,Y)) :- atom(b(X,Y)).
            head(r1(X,Y),a(X)) :- rule(r1(X,Y)).
            pos_body(r1(X,Y),b(X,Y)) :- rule(r1(X,Y)).
            pos_body(r1(X,Y),agg1(X,Y)) :- rule(r1(X,Y)).
        aggregate(agg1(X,Y),sum,"=",Y) :- rule(r1(X,Y)).
            agg_set(agg1(X,Y),c(X,Y,Z),Z,()) :- rule(r1(X,Y)), atom(c(X,Y,Z)).
    """)


def test_transform_arithmetic_ground(program_serializer_transformer):
    assert equals(program_serializer_transformer.apply(":- 1 > 2."), """
        rule(r1) :- 1 > 2.
    """)


def test_transform_arithmetic_symbolic(program_serializer_transformer):
    assert equals(program_serializer_transformer.apply(":- X = 1..2, X > 2."), """
        rule(r1(X)) :- X = (1..2), X > 2.
    """)


def test_transform_arithmetic_negation(program_serializer_transformer):
    # FIXME: bug in clingo AST API?
    with pytest.raises(AssertionError):
        assert equals(program_serializer_transformer.apply(":- X = 1..2, not X < 1."), """
            rule(r1(X)) :- X = (1..2), not X < 1.
        """)
