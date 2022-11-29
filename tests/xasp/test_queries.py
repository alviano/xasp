import logging

import pytest

from xasp.queries import compute_stable_model, process_aggregates, compute_minimal_assumption_set, compute_explanation

logging.getLogger().setLevel(logging.DEBUG)


def test_compute_stable_model():
    model = compute_stable_model("a.")
    assert len(model) == 1
    assert model[0].name == "a"


def test_compute_stable_may_return_none():
    model = compute_stable_model("a :- not a.")
    assert model is None


@pytest.fixture
def example1():
    return compute_stable_model("""
%* program

(r1)    a.
(r2)    b :- #sum{1 : a; 1 : c} >= 1.

*%


rule(r1).
  head(r1,a).

rule(r2).
  head(r2,b).
  pos_body(r2,agg1).

aggregate(agg1, sum, ">=", 1).
  agg_set(agg1, a, 1).
  agg_set(agg1, c, 1).


% answer set: a b
false(c).
true(a).
true(b).
    """)


@pytest.fixture
def example2():
    return compute_stable_model("""
%* program

(r1)    a.
(r2)    b :- #sum{1 : a; 1 : c} < 1.

*%


rule(r1).
  head(r1,a).

rule(r2).
  head(r2,b).
  pos_body(r2,agg1).

aggregate(agg1, sum, "<", 1).
  agg_set(agg1, a, 1).
  agg_set(agg1, c, 1).


% answer set: a
false(c).
true(a).
false(b).
    """)


@pytest.fixture
def example3():
    return compute_stable_model("""
%* program

(r1)    body.
(r2)    1 <= {a; b; c} <= 2 :- body.
(r3)    d :- b.

*%


rule(r1).
  head(r1,body).

rule(r2).
  choice(r2,1,2).
  head(r2,a).
  head(r2,b).
  head(r2,c).
  pos_body(r2,body).

rule(r3).
    head(r3,d).
    pos_body(r3,b).
    

% answer set: body, a
true(body).
true(a).
false(b).
false(c).
false(d).
    """)


def test_process_true_aggregate(example1):
    model = process_aggregates(example1)
    assert model.as_facts() == '\n'.join(sorted([
        "rule(r1).",
        "head(r1,a).",
        "rule(r2).",
        "head(r2,b).",
        "pos_body(r2,agg1).",
        "aggregate(agg1).",
        "true(agg1).",
        "rule(agg1).",
        "head(agg1,agg1).",
        "pos_body(agg1,a).",
        "neg_body(agg1,c).",
        "false(c).",
        "true(a).",
        "true(b).",
    ]))


def test_process_false_aggregate(example2):
    model = process_aggregates(example2)
    assert model.as_facts() == '\n'.join(sorted([
        "rule(r1).",
        "head(r1,a).",
        "rule(r2).",
        "head(r2,b).",
        "pos_body(r2,agg1).",
        "aggregate(agg1).",
        "false(agg1).",
        "rule((agg1,a)).",
        "head((agg1,a),agg1).",
        "neg_body((agg1,a),a).",
        "rule((agg1,c)).",
        "head((agg1,c),agg1).",
        "pos_body((agg1,c),c).",
        "false(c).",
        "true(a).",
        "false(b).",
    ]))


def test_compute_minimal_assumption_set(example1, example2, example3):
    model = compute_minimal_assumption_set(example1)
    assert len(model) == 0
    model = compute_minimal_assumption_set(example2)
    assert len(model) == 0
    model = compute_minimal_assumption_set(example3)
    assert model == compute_stable_model("""
        assume_false(b).
        assume_false(c).
    """)


def test_compute_explanation(example1, example2, example3):
    model = compute_explanation(example1)
    assert model == compute_stable_model("""
        indexed_explained_by(1, c, initial_well_founded).
        indexed_explained_by(2, a, (support,r1)).
        indexed_explained_by(3, b, (support,r2)).
    """)
    model = compute_explanation(example2)
    assert model == compute_stable_model("""
        indexed_explained_by(1, c, initial_well_founded).
        indexed_explained_by(2, b, initial_well_founded).
        indexed_explained_by(3, a, (support,r1)).
    """)
    model = compute_explanation(example3)
    assert model == compute_stable_model("""
        indexed_explained_by(1,c,assumption).
        indexed_explained_by(2,b,assumption).
        indexed_explained_by(3,d,lack_of_support).
        indexed_explained_by(4,body,(support,r1)).
        indexed_explained_by(5,a,(support,r2)).
    """)
