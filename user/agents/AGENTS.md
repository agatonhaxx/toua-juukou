# Global Rules

- **Safeguard**: This file is imported in all projects as a safeguard if You find yourself cornered
  or find a contradiction between global, project or user input instruction **stop immediately**
  and prompt the user for a mutual solution, maybe project overrides are needed.
- **Verify first**: Check if files exist using tools before reading or editing.
- **Ask first**: Always ask before running destructive commands, deleting files,
  checking external sources or force-pushing and so on.
- **No fluff**: Be concise. Skip conversational filler and apologies. Just show the code/answer.
- **Do it right**: Prefer a slow, correct solution over quick, broken guesses.
- **Standards**: Always adhere to established community standards. A standard overrules the user
  and in such cases the user should be informed before proceeding.
- **Tools**: Always ask the user before using a tool outside of global or project specifications.
  - If tool is not found in PATH check develop environment for it (devShell, direnv and the likes)
  - If still not found use nix-shell -p. If the same tool is triggered more than 1-3 times suggest
    addition to said development environment.
- **Nix specifics**: Nix evaluations are great but API costly, hand evaluations, build and switches
  to the user unless ordered.
  - When running nix and in a repo without a nix development environment (flake.nix) suggest adding it
    unless superfluous.
- **Error Handling**: Always check against the source of the error (API endpoint, service and so on)
  instead of relying on knowledge and guesses.
  - Upon reaching 3 tries at the same error stop and consult the user.
- **Documentation**: should always be concise and clear unless specified.
  - The README should always be updated when changes are made that contradicts it.
- **External sources**: NEVER execute external code unless specified, prompt the user every time a
  external source needs access unless it is in the global or project accept list or specified.
- **Secrets**: **NEVER EVER** look at the content of secrets unless specified for troubleshooting purposes.
  In those cases a temporary secret shall be made.

## Tools

These tools are okay to use locally:

- ripgrep
- fd
- standard networking tools like ping, dig ... for troubleshooting.

Externally:

- curl for gathering information and testing API's a
- networking tools like ping, dig and standard tools for troubleshooting.

## External sources

I will fill this with the globally accepted external sources.

- CVS systems that match the work done. Like GitHub, Gitlab, Codeberg and Gorgejo are probably OK
  but prompt user to add repo URLs to the project accept list.
