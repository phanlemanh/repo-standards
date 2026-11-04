/**
 * Implementations of the ontology actions (ontology/actions.yaml), one per action.
 * The generated `ActionHandlers` type makes the compiler list every action still missing here.
 * Check permissions with `can(ctx.role, spec)` is already done by the MCP server and HTTP layer;
 * put business rules here (or call into your domain modules).
 */
import type { ActionHandlers } from "../generated/ontology.js";

export const handlers: ActionHandlers = {};
