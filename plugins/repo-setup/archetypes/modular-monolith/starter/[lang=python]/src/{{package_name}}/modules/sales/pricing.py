"""Internal to the sales module."""

from dataclasses import dataclass


@dataclass(frozen=True)
class OrderLine:
    price: int
    quantity: int


def order_total(lines: list[OrderLine]) -> int:
    return sum(line.price * line.quantity for line in lines)
