import { afterAll, expect, it } from "vitest";

import { handlers } from "../src/actions/index.js";
import { buildApp } from "../src/app.js";

const app = buildApp(
  {},
  {
    handlers,
    apiKeys: new Map([
      ["k-agent", "agent"],
      ["k-staff", "staff"],
      ["k-manager", "manager"],
    ]),
  },
);
afterAll(async () => {
  await app.close();
});

const call = (name: string, key: string, payload: object) =>
  app.inject({
    method: "POST",
    url: `/v1/actions/${name}`,
    headers: { authorization: `Bearer ${key}` },
    payload,
  });

it("lets permitted roles run actions", async () => {
  const res = await call("placeOrder", "k-staff", { customerId: "c1", total: 5, channel: "app" });
  expect(res.statusCode).toBe(200);
  expect(res.json()).toMatchObject({ id: "o1", total: 5 });
});

it("forbids roles without permission", async () => {
  const res = await call("awardPoints", "k-staff", { customerId: "c1", points: 5 });
  expect(res.statusCode).toBe(403);
});

it("validates input", async () => {
  const res = await call("placeOrder", "k-staff", { customerId: "c1", total: "x", channel: "app" });
  expect(res.statusCode).toBe(422);
});

it("redacts personal data for agents only", async () => {
  expect((await call("getCustomer", "k-agent", { id: "c1" })).json()).toMatchObject({
    phone: "[redacted]",
  });
  expect((await call("getCustomer", "k-staff", { id: "c1" })).json()).toMatchObject({
    phone: "0901234567",
  });
});
