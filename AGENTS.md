# Project Instructions

This is a Roblox wheelchair racing game using Rojo.

## Project structure

* `src/client` is synced to `StarterPlayer > StarterPlayerScripts > RojoClient`.
* `src/server` is synced to `ServerScriptService > RojoServer`.
* `src/shared` is synced to `ReplicatedStorage > RojoShared`.
* `default.project.json` controls the Rojo mapping.
* Do not change the Rojo folder structure unless specifically asked.

## File naming

Use Luau.

* Client scripts must use `.client.luau`.
* Server scripts must use `.server.luau`.
* Shared modules must use `.luau`.

Examples:

* `WheelchairClient.client.luau`
* `WheelchairService.server.luau`
* `WheelchairConfig.luau`

Avoid `init.client.luau` and `init.server.luau` unless the project explicitly requires them.

## Roblox architecture

* Client scripts handle input, camera, UI, and visual-only effects.
* Server scripts handle spawning, player state, validation, important gameplay state, and anti-exploit logic.
* Shared modules contain config, utility functions, types, and reusable logic.
* Do not put important gameplay authority only on the client.
* Use `RemoteEvent` and `RemoteFunction` carefully. Validate all important requests on the server.

## Wheelchair vehicle rules

The game is being converted from a BMX-style system into a wheelchair racing system.

* The wheelchair should use one main invisible physics root part.
* In the existing BMX code, `Frame` may act as the main root part.
* Do not rename `Bike`, `Frame`, or other existing public objects unless all references are updated.
* Visual parts should normally be `Massless = true` and `CanCollide = false`.
* Avoid collision on every mesh or decorative part.
* Keep the vehicle stable on ramps, slopes, and obstacles.
* Avoid strong BMX-style leaning unless requested.
* Wheel rotation can be visual-only.
* Movement should feel smooth but controllable.

## Reference BMX code

The folder `reference/bmx` contains legacy BMX game code.

Rules:

- Use `reference/bmx` only for analysis and comparison.
- Do not sync `reference/bmx` into Roblox Studio.
- Do not edit files inside `reference/bmx` unless explicitly asked.
- Do not directly copy large parts of the BMX system into the new wheelchair system without explaining why.
- Prefer to understand the design first, then implement a clean wheelchair-specific version in `src`.
- The new wheelchair system must live in:
  - `src/client`
  - `src/server`
  - `src/shared`

When adapting BMX behavior:

- Keep useful concepts such as input handling, camera follow, spring smoothing, and spawn flow.
- Avoid BMX-specific assumptions like front/back wheel steering, wheelies, heavy leaning, or bike frame geometry.
- The wheelchair should be wider, more stable, and should not rely on BMX-style leaning.

## Code style

* Prefer simple, readable Luau.
* Use clear variable names.
* Add comments only where they explain non-obvious Roblox behavior.
* Do not over-engineer small systems.
* Do not rewrite the whole project unless specifically asked.
* Make small, testable changes.
* After editing, explain what files were changed and how to test the result in Roblox Studio.

## Safety rules

* Do not delete existing Roblox systems unless asked.
* Do not remove unknown legacy BMX code without first explaining why.
* Preserve compatibility with the current Rojo structure.
* If a change requires editing Roblox Studio models manually, explain the exact Explorer path and properties to change.

## Language

* The user may write tasks in Russian.
* Understand Russian instructions correctly.
* Write explanations to the user in Russian.
* Use English for file names, variable names, function names, module names, and Roblox object names unless the user explicitly asks otherwise.
* Prefer English comments in code, but keep comments minimal.