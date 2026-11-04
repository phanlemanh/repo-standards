import type { ActionHandlers, Customer, Order } from "../generated/ontology.js";

const lan: Customer = {
  id: "c1",
  name: "Lan",
  phone: "0901234567",
  points: 120,
  status: "active",
  joinedAt: "2026-01-01T00:00:00Z",
};

export const handlers: ActionHandlers = {
  placeOrder(input) {
    const order: Order = { id: "o1", customerId: input.customerId, total: input.total };
    return Promise.resolve(order);
  },
  getCustomer() {
    return Promise.resolve(lan);
  },
  awardPoints(input) {
    return Promise.resolve({ ...lan, points: lan.points + input.points });
  },
};
