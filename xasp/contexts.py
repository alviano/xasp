import dataclasses
from typing import Optional

from clingo import Number, String
from collections import defaultdict, namedtuple

from xasp.utils import log


class ProcessAggregatesContext:
    @staticmethod
    def check_operator(operator, bounds, value):
        if operator.string in ["=", "=="]:
            return Number(1) if value == bounds else Number(0)
        if operator.string in ["!=", "<>"]:
            return Number(1) if value != bounds else Number(0)
        if operator.string == "<":
            return Number(1) if value < bounds else Number(0)
        if operator.string == ">":
            return Number(1) if value > bounds else Number(0)
        if operator.string == "<=":
            return Number(1) if value <= bounds else Number(0)
        if operator.string == ">=":
            return Number(1) if value >= bounds else Number(0)
        if operator.string == "in":
            return Number(1) if bounds.arguments[0] <= value <= bounds.arguments[1] else Number(0)
        assert False


@dataclasses.dataclass
class ComputeMinimalAssumptionSetContext:
    Rule = namedtuple("Rule", "id head pos_body neg_body")
    WellFoundedModel = namedtuple("WellFoundedModel", "true potentially_true")

    rules: dict = dataclasses.field(default_factory=dict)
    atom2heads: dict = dataclasses.field(default_factory=lambda: defaultdict(list))
    atom2pos_bodies: dict = dataclasses.field(default_factory=lambda: defaultdict(list))
    atom2neg_bodies: dict = dataclasses.field(default_factory=lambda: defaultdict(list))

    well_founded_model: Optional = dataclasses.field(default=None)

    @staticmethod
    def output(atom, explanation):
        return String(f"{atom} explained by {explanation}")

    def collect_rule(self, rule):
        assert rule not in self.rules.keys()
        self.rules[rule] = self.Rule(rule, set(), set(), set())
        return Number(1)

    def collect_head(self, rule, atom):
        assert rule in self.rules.keys()
        rule = self.rules[rule]
        rule.head.add(atom)
        self.atom2heads[atom].append(rule)
        return Number(1)

    def collect_pos_body(self, rule, atom):
        assert rule in self.rules.keys()
        rule = self.rules[rule]
        rule.pos_body.add(atom)
        self.atom2pos_bodies[atom].append(rule)
        return Number(1)

    def collect_neg_body(self, rule, atom):
        assert rule in self.rules.keys()
        rule = self.rules[rule]
        rule.neg_body.add(atom)
        self.atom2neg_bodies[atom].append(rule)
        return Number(1)

    def false_in_well_founded_model(self, atom):
        def enqueue_if_source_pointer(rule, my_queue):
            if rule.head is None:
                return
            if all(source_pointer[head_atom] is not None for head_atom in rule.head):
                return
            log.debug(f"check {rule.id}")
            if any(batom not in self.well_founded_model.potentially_true for batom in rule.pos_body):
                return
            log.debug(f"  pos_body potentially true")
            if any(batom in self.well_founded_model.true for batom in rule.neg_body):
                return
            log.debug(f"  neg_body potentially true")
            if all(source_pointer[batom] is not None for batom in rule.pos_body):
                for head_atom in rule.head:
                    if source_pointer[head_atom] is None:
                        log.debug(f"source pointer: {head_atom} {rule.id}")
                        source_pointer[head_atom] = rule
                        my_queue.append(head_atom)

        if self.well_founded_model is None:
            self.well_founded_model = self.WellFoundedModel(
                set(),
                set().union(*(rule.head for rule in self.rules.values() if rule.head))
            )
            source_pointer = {ptatom: None for ptatom in self.well_founded_model.potentially_true}
            source_pointer_of_atom = {rule: None for rule in self.rules}

            while True:
                queue = list(set().union(*(rule.head for rule in self.rules.values() if
                                           len(rule.pos_body) + len(rule.neg_body) == 0 and rule.head)))
                while queue:
                    true_atom = queue[-1]
                    queue.pop()

                    if true_atom in self.well_founded_model.true:
                        continue
                    assert true_atom in self.well_founded_model.potentially_true

                    self.well_founded_model.true.add(true_atom)
                    log.debug(f"true: {true_atom}")
                    for rule in self.atom2pos_bodies[true_atom]:
                        if all(batom in self.well_founded_model.true for batom in rule.pos_body) and \
                                all(batom not in self.well_founded_model.potentially_true for batom in rule.neg_body):
                            for head_atom in rule.head:
                                queue.append(head_atom)

                queue = []
                for rule in self.rules.values():
                    enqueue_if_source_pointer(rule, queue)
                while queue:
                    atom_with_source_pointer = queue[-1]
                    queue.pop()

                    for rule in self.atom2pos_bodies[atom_with_source_pointer]:
                        enqueue_if_source_pointer(rule, queue)
                founded_atoms = set(spatom for spatom in source_pointer if source_pointer[spatom] is not None)
                unfounded_atoms = self.well_founded_model.potentially_true - founded_atoms
                if not unfounded_atoms:
                    break

                for unfounded_atom in unfounded_atoms:
                    log.debug(f"false: {unfounded_atom}")
                    assert unfounded_atom not in self.well_founded_model.true
                    self.well_founded_model.potentially_true.remove(unfounded_atom)

        return Number(1) if atom not in self.well_founded_model.potentially_true else Number(0)
