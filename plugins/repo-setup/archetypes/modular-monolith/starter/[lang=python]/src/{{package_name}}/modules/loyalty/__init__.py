"""Public API of the loyalty module. It depends on sales (architecture/modules.yaml)."""

from ..sales import OrderLine, order_total


def points_for(lines: list[OrderLine]) -> int:
    """1 point per 10,000 of order value."""
    return order_total(lines) // 10_000


__all__ = ["points_for"]
