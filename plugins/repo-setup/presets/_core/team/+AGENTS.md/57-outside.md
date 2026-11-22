## Work outside the repository

GitHub settings, variables, keys and the platform the product runs on are listed in
`ops/outside.toml`; the kinds of command the machine may run for them are in
`governance/outside.toml`, a file people own.

- Work outside the repository goes through `python3 tools/outside.py`: `status` first, then
  `apply`. Do not hand a person a step the tool can apply. <!-- kept: word -->
- When a person is needed, give them the tool's `Yours` list, once, with the one command
  `python3 tools/outside.py secrets` to run in a terminal of their own. <!-- kept: word -->
- Never take the value of a key in the conversation, on a command line or in a file.
  <!-- kept: word -->
