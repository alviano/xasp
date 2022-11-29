from clingo import Number


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
