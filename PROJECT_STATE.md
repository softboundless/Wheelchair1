
## Project

Roblox wheelchair racing mode.

Repository: `softboundless/Wheelchair1`

Stack:

* Roblox Studio
* VS Code
* Rojo
* GitHub
* Luau

Rojo sync structure:

* `src/client`
* `src/server`
* `src/shared`

Reference folder:

* `reference/bmx` is reference-only.
* Do not modify `reference/bmx` unless explicitly asked.

---

## Current status

The project has a basic wheelchair system created by Codex.

Main modules:

* `src/shared/WheelchairConfig.lua`
* `src/server/WheelchairService.lua`
* `src/client/WheelchairClient.lua`

Current known issue:

* Player spawns in the wheelchair.
* Wheelchair does not move.
* Camera is positioned from the side.
* Speed stays `0`.

---

## Current architecture

### `WheelchairConfig`

Purpose:

* Stores shared tuning values and constants for wheelchair movement, camera, physics, input, and debugging.

Expected role:

* No direct gameplay execution.
* Should be required by both server and client when shared settings are needed.

### `WheelchairService`

Purpose:

* Server-side wheelchair spawning, setup, seating, ownership, and movement authority.

Expected role:

* Spawn / attach / seat the player correctly.
* Make sure the wheelchair model is physically valid.
* Handle server-side movement state if movement is server-authoritative.
* Maintain correct network ownership where needed.

### `WheelchairClient`

Purpose:

* Client-side input, camera behavior, and local control flow.

Expected role:

* Read keyboard / mobile input.
* Send movement intent to server if using RemoteEvents.
* Control or assist camera positioning.
* Prevent default Roblox controls from conflicting with wheelchair movement when needed.

---

## Important rules

Do not rewrite the entire wheelchair system unless there is a clear reason.

Prefer this workflow:

1. Diagnose the exact cause.
2. Explain the likely bug.
3. Make the smallest safe fix.
4. Explain how to test it in Roblox Studio.

Do not make large architecture changes before checking:

* `WheelchairConfig.lua`
* `WheelchairService.lua`
* `WheelchairClient.lua`
* `default.project.json`
* Roblox Studio hierarchy expected by Rojo

Do not modify:

* `reference/bmx`
* unrelated UI systems
* unrelated economy / monetization systems
* generated or temporary files

---

## Debug priorities

Current highest-priority bug:

`Player spawns in wheelchair, but wheelchair does not move and Speed remains 0.`

Things to check first:

* Is client input being detected?
* Is `WheelchairClient` running from `StarterPlayerScripts`?
* Is a RemoteEvent used for movement input?
* Does the server receive movement input?
* Is `Speed` updated anywhere?
* Is `VehicleSeat.Throttle` / `VehicleSeat.Steer` being used or ignored?
* Is the player actually seated in the intended seat?
* Is the wheelchair root part anchored?
* Is the wheelchair root part welded correctly?
* Is network ownership assigned correctly?
* Is camera logic overriding the expected view?

---

## How to continue in a new ChatGPT / Codex chat

At the start of a new chat, use this context:

```text
Project: Roblox wheelchair racing mode.
Repo: softboundless/Wheelchair1.
Stack: VS Code + Rojo + Roblox Studio.
Main files: WheelchairConfig, WheelchairService, WheelchairClient.
reference/bmx is only an example and should not be modified.
Current issue: player spawns in wheelchair, but wheelchair does not move; camera is from the side; Speed = 0.
Goal: diagnose the smallest fix, not rewrite the whole system.
```

---

## ChatGPT handoff rule

At the end of every major debugging, architecture, or implementation chat, ChatGPT should provide an updated full version of `PROJECT_STATE.md`.

The updated version must include:

* current status
* what changed
* what files were edited or should be edited
* current known bugs
* what was tested
* what still needs testing
* next recommended task
* short handoff prompt for a new chat

The updated `PROJECT_STATE.md` must be provided as a copy-ready Markdown code block.

If no meaningful project state changed, ChatGPT should say:

```text
PROJECT_STATE.md does not need to be updated.
```

---

## Last known state

Date: not set.

What was done:

* Codex created the initial wheelchair modules.
* ChatGPT project organization was discussed.
* `AGENTS.md` and `PROJECT_STATE.md` were recommended for better continuity.

Current blocker:

* Wheelchair spawns but does not move.
* Camera is sideways.
* Speed remains `0`.

Next recommended task:

* Inspect `WheelchairClient` input flow and `WheelchairService` speed update logic.
* Confirm whether movement input reaches the server.
* Confirm whether speed is calculated but not applied, or never calculated at all.
