import base64
from enum import Enum, auto

import clingo
import clingo.ast
import typeguard
from clingo.ast import ASTType, ComparisonOperator, AggregateFunction, Sign, Location

from valid8 import validate


@typeguard.typechecked
class Transformer(clingo.ast.Transformer):
    def __init__(self) -> None:
        super().__init__()
        self.__called = False
        self.__result = []
        self.__exceptions = []
        self.__input = None

    def apply(self, string: str) -> str:
        validate("called once", self.__called, equals=False)
        self.__input = string.split('\n')
        clingo.ast.parse_string(string, lambda obj: self.__transform(obj))
        if self.__exceptions:
            raise self.__exceptions[0]
        return '\n'.join(self.__result)

    def __transform(self, obj):
        try:
            self.visit(obj)
        except Exception as err:
            self.__exceptions.append(err)

    def add_to_result(self, string: str) -> None:
        self.__result.append(string)

    def input(self, location: Location) -> str:
        res = []
        if location.begin.line == location.end.line:
            res.append(self.__input[location.begin.line - 1][location.begin.column - 1:location.end.column - 1])
        else:
            res.append(self.__input[location.begin.line - 1][location.begin.column - 1:])
            res.extend(self.__input[location.begin.line:location.end.line - 1])
            res.append(self.__input[location.end.line - 1][:location.end.column - 1])
        return '\n'.join(line.rstrip() for line in res if line.strip())

    def encode_input(self, location: Location) -> str:
        return base64.b64encode(self.input(location).encode()).decode()


@typeguard.typechecked
class ProgramSerializerTransformer(Transformer):
    class State(Enum):
        READING_HEAD = auto()
        READING_BODY = auto()
        READING_AGGREGATE = auto()

    def __init__(self) -> None:
        super().__init__()
        self.__rule_index = 0
        self.__agg_index = 0
        self.__state = None
        self.__variables = set()
        self.__definitions = []

    def visit_Definition(self, node):
        self.add_to_result(str(node))

    def visit_Rule(self, node):
        self.__rule_index += 1
        self.__state = self.State.READING_HEAD
        head = self.visit(node.head)
        self.__state = self.State.READING_BODY
        body = self.visit_sequence(node.body)
        variables = ','.join(sorted(self.__variables))
        rule_id = f"r{self.__rule_index}({variables})" if self.__variables else f"r{self.__rule_index}"
        rule_atom = f"rule({rule_id})"
        rule_body = self.__compute_rule_body(body)
        self.add_to_result(f"{rule_atom} :- {rule_body}.")

        self.add_to_result(f'original_rule(r{self.__rule_index},"{self.encode_input(node.location)}","{variables}").')

        if str(head) != "#false":
            validate("head type", head.ast_type, is_in=(ASTType.Aggregate, ASTType.Literal))
            if head.ast_type == ASTType.Aggregate:
                self.__process_choice(head, rule_id, rule_atom)
            else:
                validate("positive head", head.sign, equals=False)
                self.add_to_result(f"head({rule_id},{head}) :- {rule_atom}.")

        for literal in body:
            if literal.atom.ast_type == ASTType.Comparison:
                continue
            if literal.sign:
                validate("negation in front of atoms", literal.atom.ast_type, equals=ASTType.SymbolicAtom)
                if literal.atom.ast_type == ASTType.SymbolicAtom:
                    self.add_to_result(f"neg_body({rule_id},{literal.atom}) :- {rule_atom}.")
            elif literal.atom.ast_type == ASTType.SymbolicAtom:
                self.add_to_result(f"pos_body({rule_id},{literal.atom}) :- {rule_atom}.")
            elif literal.atom.ast_type == ASTType.BodyAggregate:
                self.__process_aggregate(literal, rule_id, rule_atom, variables)
            else:
                raise ValueError(f"Cannot process {literal}")

        self.__state = None
        self.__variables.clear()
        return node

    @staticmethod
    def __compute_rule_body(body, atom_predicate: str = "atom"):
        res = []
        for literal in body:
            if literal.atom.ast_type == ASTType.Comparison:
                res.append(f"{literal}")
            elif literal.sign == Sign.NoSign and literal.atom.ast_type == ASTType.SymbolicAtom:
                res.append(f"{atom_predicate}({literal.atom})")
        return ", ".join(res)

    @staticmethod
    def __compute_choice_bounds(choice):
        left, right = 0, "unbounded"
        if choice.left_guard is not None:
            validate("left guard", choice.left_guard.comparison != ComparisonOperator.NotEqual, equals=True)
            if choice.left_guard.comparison == ComparisonOperator.LessThan:
                left = f"{choice.left_guard.term} + 1"
            elif choice.left_guard.comparison == ComparisonOperator.LessEqual:
                left = f"{choice.left_guard.term}"
            elif choice.left_guard.comparison == ComparisonOperator.GreaterThan:
                right = f"{choice.left_guard.term} - 1"
            elif choice.left_guard.comparison == ComparisonOperator.GreaterEqual:
                right = f"{choice.left_guard.term}"
            elif choice.left_guard.comparison == ComparisonOperator.Equal:
                left = f"{choice.left_guard.term}"
                right = f"{choice.left_guard.term}"
            else:
                raise ValueError("Choice with != are not supported.")
        if choice.right_guard is not None:
            validate("right guard", choice.right_guard.comparison, is_in=[ComparisonOperator.LessThan,
                                                                          ComparisonOperator.LessEqual])
            if choice.right_guard.comparison == ComparisonOperator.LessThan:
                right = f"{choice.right_guard.term} + 1"
            elif choice.right_guard.comparison == ComparisonOperator.LessEqual:
                right = f"{choice.right_guard.term}"
        return left, right

    def __process_choice(self, head, rule_id, rule_atom):
        lower_bound, upper_bound = self.__compute_choice_bounds(head)
        self.add_to_result(f"choice({rule_id},{lower_bound},{upper_bound}) :- {rule_atom}.")
        if len(head.elements) > 1:
            for element in head.elements:
                validate("condition is empty", element.condition, length=0,
                         help_msg="Multiple elements are only supported without conditions")
                self.add_to_result(f"head({rule_id},{element.literal}) :- {rule_atom}.")
        elif len(head.elements) == 1:
            element = head.elements[0]
            if len(element.condition) == 0:
                self.add_to_result(f"head({rule_id},{element.literal}) :- {rule_atom}.")
            else:
                condition = self.__compute_rule_body(element.condition, "true")
                self.add_to_result(f"head({rule_id},{element.literal}) :- {rule_atom}, {condition}.")

    def __process_aggregate(self, literal, rule_id, rule_atom, variables):
        if literal.atom.right_guard is None:
            operator, bound = str(literal.atom.left_guard).split()
            if operator in ['>', '>=']:
                operator = operator.replace('>', '<')
            elif operator in ['<', '<=']:
                operator = operator.replace('<', '>')
        else:
            left = str(literal.atom.left_guard).split()
            right = str(literal.atom.right_guard).split()
            validate("left guard is < or <=", left[0][0], equals="<")
            validate("right guard is < or <=", right[0][0], equals="<")
            if left[0] == "<":
                left[1] = f"({left[1]}) + 1"
            if right[0] == "<":
                right[1] = f"({right[1]}) - 1"
            operator = "in"
            bound = f"({left[1]},{right[1]})"

        self.__agg_index += 1
        agg_id, fun = f"agg{self.__agg_index}", literal.atom.function
        if self.__variables:
            agg_id = f"{agg_id}({','.join(sorted(self.__variables))})"
        self.add_to_result(f"pos_body({rule_id},{agg_id}) :- {rule_atom}.")
        if fun == AggregateFunction.Sum:
            fun = "sum"
        elif fun == AggregateFunction.Count:
            fun = "count"
        elif fun == AggregateFunction.Min:
            fun = "min"
        elif fun == AggregateFunction.Max:
            fun = "max"
        else:
            raise ValueError(f"Cannot process aggregate function with ID {fun}")

        self.add_to_result(f'aggregate({agg_id},{fun},"{operator}",{bound}) :- {rule_atom}.')
        self.add_to_result(f'original_rule({agg_id},"{self.encode_input(literal.location)}","{variables}") :- {rule_atom}.')
        for element in literal.atom.elements:
            validate("condition", element.condition, length=1)
            validate("condition", element.condition[0].sign, equals=Sign.NoSign)
            validate("terms", element.terms, min_len=1)
            terms = [str(term) for term in element.terms]
            self.add_to_result(
                f"agg_set({agg_id},{element.condition[0]},{terms[0]},({','.join(terms[1:])})) :- "
                f"{rule_atom}, atom({element.condition[0]})."
            )

    def visit_Function(self, node):
        self.visit_children(node)
        return node

    def visit_BodyAggregate(self, node):
        self.__state = self.State.READING_AGGREGATE
        self.visit_children(node)
        self.__state = self.State.READING_BODY
        return node

    def visit_Variable(self, node):
        if self.__state == self.__state.READING_BODY:
            self.__variables.add(str(node))
        return node
