from enum import Enum, auto

import clingo
import clingo.ast
import typeguard
from clingo.ast import ASTType, ComparisonOperator, AggregateFunction, Sign

from xasp.utils import validate


@typeguard.typechecked
class ProgramSerializerTransformer(clingo.ast.Transformer):
    class State(Enum):
        READING_HEAD = auto()
        READING_BODY = auto()
        READING_AGGREGATE = auto()

    def __init__(self) -> None:
        super().__init__()
        self.__rule_index = 0
        self.__agg_index = 0
        self.__exceptions = []
        self.__result = []
        self.__state = None
        self.__variables = set()

    def apply(self, string: str) -> str:
        validate("called once", self.__rule_index)
        clingo.ast.parse_string(string, lambda obj: self.__transform(obj))
        self.__rule_index = None
        if self.__exceptions:
            raise self.__exceptions[0]
        return '\n'.join(self.__result)

    def __transform(self, obj):
        try:
            self.visit(obj)
        except Exception as err:
            self.__exceptions.append(err)

    def visit_Rule(self, node):
        self.__rule_index += 1
        self.__state = self.State.READING_HEAD
        head = self.visit(node.head)
        self.__state = self.State.READING_BODY
        body = self.visit_sequence(node.body)
        variables = ','.join(sorted(self.__variables))
        rule_id = f"r{self.__rule_index}({variables})" if self.__variables else f"r{self.__rule_index}"
        rule_atom = f"rule({rule_id})"
        rule_body = ", ".join(f"atom({literal.atom})" for literal in body if literal.sign == Sign.NoSign and
                              literal.atom.ast_type == ASTType.SymbolicAtom)
        self.__result.append(f"{rule_atom} :- {rule_body}.")

        if str(head) != "#false":
            validate("head type", head.ast_type, is_in=(ASTType.Aggregate, ASTType.Literal))
            if head.ast_type == ASTType.Aggregate:
                lower_bound, upper_bound = self.__compute_choice_bounds(head)
                self.__result.append(f"choice({rule_id},{lower_bound},{upper_bound}) :- {rule_atom}.")
                for element in head.elements:
                    validate("condition is empty", element.condition, length=0)
                    self.__result.append(f"head({rule_id},{element.literal}) :- {rule_atom}.")
            else:
                validate("positive head", head.sign, equals=False)
                self.__result.append(f"head({rule_id},{head}) :- {rule_atom}.")

        for literal in body:
            if literal.sign:
                validate("negation in front of atoms", literal.atom.ast_type, equals=ASTType.SymbolicAtom)
                self.__result.append(f"neg_body({rule_id},{literal.atom}) :- {rule_atom}.")
            elif literal.atom.ast_type == ASTType.SymbolicAtom:
                self.__result.append(f"pos_body({rule_id},{literal.atom}) :- {rule_atom}.")
            elif literal.atom.ast_type == ASTType.BodyAggregate:
                self.__process_aggregate(literal, rule_id, rule_atom)
            else:
                raise ValueError(f"Cannot process {literal}")

        self.__state = None
        self.__variables.clear()
        return node

    @staticmethod
    def __compute_choice_bounds(choice):
        left, right = 0, len(choice.elements)
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

    def __process_aggregate(self, literal, rule_id, rule_atom):
        validate("no right guard", literal.atom.right_guard is None, equals=True)
        validate("left guard", literal.atom.left_guard.comparison != ComparisonOperator.NotEqual, equals=True)
        self.__agg_index += 1
        agg_id, fun = f"agg{self.__agg_index}", literal.atom.function
        if self.__variables:
            agg_id = f"{agg_id}({','.join(sorted(self.__variables))})"
        self.__result.append(f"pos_body({rule_id},{agg_id}) :- {rule_atom}.")
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
        operator, bound = str(literal.atom.left_guard).split()
        if operator[0] == '>':
            operator = operator.replace('>', '<')
        else:
            operator = operator.replace('<', '>')
        self.__result.append(f'aggregate({agg_id},{fun},"{operator}",{bound}) :- {rule_atom}.')
        for element in literal.atom.elements:
            validate("condition", element.condition, length=1)
            validate("condition", element.condition[0].sign, equals=Sign.NoSign)
            validate("terms", element.terms, min_len=1)
            self.__result.append(
                f"agg_set({agg_id},{element.condition[0]},{element.terms[0]},({','.join(element.terms[1:])})) :- "
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
        if self.__state in [self.State.READING_HEAD, self.__state.READING_BODY]:
            self.__variables.add(str(node))
        return node
