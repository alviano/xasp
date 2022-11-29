from xasp.queries import compute_stable_model, process_aggregates


def test_compute_stable_model():
    model = compute_stable_model("a.")
    assert len(model) == 1
    assert model[0].name == "a"


def test_compute_stable_may_return_none():
    model = compute_stable_model("a :- not a.")
    assert model is None


def test_process_true_aggregate():
    model = process_aggregates("""
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


def test_process_false_aggregate():
    model = process_aggregates("""
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
