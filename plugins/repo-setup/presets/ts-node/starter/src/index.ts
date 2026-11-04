import { greet } from "./greet.js";

console.log(greet(process.env["APP_NAME"] ?? ""));
