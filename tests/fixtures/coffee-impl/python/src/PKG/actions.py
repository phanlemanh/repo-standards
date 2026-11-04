"""Fixture implementations of the coffee-shop actions."""

from __future__ import annotations

import dataclasses
import datetime

from .ontology_types import (
    ActionContext,
    ActionHandlers,
    AwardPointsInput,
    Customer,
    GetCustomerInput,
    Order,
    PlaceOrderInput,
)

LAN = Customer(
    id="c1",
    name="Lan",
    phone="0901234567",
    points=120,
    joined_at=datetime.datetime(2026, 1, 1, tzinfo=datetime.UTC),
)


class Handlers:
    def place_order(self, data: PlaceOrderInput, ctx: ActionContext) -> Order:
        return Order(id="o1", customer_id=data.customer_id, total=data.total)

    def get_customer(self, data: GetCustomerInput, ctx: ActionContext) -> Customer:
        return LAN

    def award_points(self, data: AwardPointsInput, ctx: ActionContext) -> Customer:
        return dataclasses.replace(LAN, points=LAN.points + data.points)


HANDLERS: ActionHandlers = Handlers()
