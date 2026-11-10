# Roblox technical research (November 2026)

Sources were checked in November 2026 through search snippets and DevForum/Creator Hub pages. Many items are community posts, not official docs. Those are marked as such.

## Recommended stack

| Area | Recommendation | Why | Source URL |
|---|---|---|---|
| Sync | Rojo 7.x (confirm latest on GitHub releases) | Rojo 7 changed explicit property syntax (Type/Value merged). Check the upgrade guide. | https://rojo.space/docs/v7/upgrade/ |
| Toolchain | Rokit | Successor to Aftman/Foreman. Reads `aftman.toml` and `foreman.toml`. Roblox's dev container now uses it. | https://github.com/rojo-rbx/rokit |
| Packages | Wally (pesde as an option) | Wally is the established choice. pesde has its own registry and can read Wally packages, but I found no 2026 comparison. | https://devforum.roblox.com/t/why-you-should-use-wally-a-package-manager-for-roblox/1977617 |
| Luau types | New type solver (now default) | Left Studio Beta in January 2026. Still getting fixes in 2026 release notes. | https://create.roblox.com/docs/release-notes/release-notes-677 |
| Unit tests | TestEZ or Jest-Lua (status unclear) | TestEZ is still in use. A DevForum post says Roblox moved to a Luau Jest port, but I could not confirm this. | https://github.com/Roblox/TestEZ |
| Pure-logic tests | Lune | Runs plain Luau tests and CI scripts outside Studio. Does not emulate the DataModel. | https://github.com/lune-org/lune |
| In-place CI tests | Open Cloud Luau Execution (beta) | Runs Luau headlessly in a place from CI. Needs the `universe.place.luau-execution-session:write` scope. | https://create.roblox.com/docs/cloud/reference/features/luau-execution.md |
| Format | StyLua | Latest listed is 2.5.2. 2.4.0 (2026-03-07) added Luau attribute support. | https://github.com/JohnnyMorganz/StyLua |
| Lint | Selene (not confirmed) | Searches returned nothing on Selene for 2026. | (none) |
| Saved data | ProfileStore | Successor to ProfileService, same session-locking model, faster conflict resolution through MessagingService. | https://devforum.roblox.com/t/profilestore-save-your-player-data-easy-datastore-module/3190543 |
| Melee hits | Server-authoritative shapecast; ShapecastHitbox optional | Community module (V0.2.5) that replaces RaycastHitbox. Server validates every client hit. | https://devforum.roblox.com/t/shapecasthitbox-for-all-your-melee-needs/3624241 |
| Networking | Typed remotes with Blink or Zap | Blink and Zap are the most cited options. Both validate data. Benchmarks are self-reported. | https://github.com/red-blox/zap |
| UI | react-lua (most mature) or Fusion (most popular) | Sources disagree on the leader. Vide is praised for syntax but has thin coverage. | https://devforum.roblox.com/t/fusion-vs-react-lua-which-one-to-use-for-long-term-development/2781328 |
| Cross-server | MemoryStoreService, MessagingService | Good for short-lived shared state. Limits are not confirmed from official docs. | https://create.roblox.com/docs/cloud-services/memory-stores.md |

## 1. Project tooling
- Rojo 7 is the current major line. Later 7.x releases include 7.4.x (new maintainers) and 7.7.0 (syncback, websocket transport). I could not confirm the 7.7.0 date or whether it has breaking changes.
- Rokit is the community choice. Aftman's maintainer is reported as inactive, but that claim comes from the Rokit README.
- The Luau new type solver left beta on January 7, 2026 per the DevForum announcement.
- Lune is not a Roblox engine emulator. Tests that depend on live instances still need Studio or Open Cloud execution.

## 2. Saved data
- ProfileStore is the successor to ProfileService. Its profiles are compatible with ProfileService. Use it for new projects.
- Session locking prevents two servers from writing one profile. The DevForum says this is the main defense against trade duplication. A race exists if a player rejoins before the save finishes.
- Data limits (Creator Hub, error codes and limits page): 4,194,304 characters per key. Per-key throughput is 25 MB/min read and 4 MB/min write. A request budget of `300 + concurrentUsers × 40` per minute is listed, but older posts use different numbers.
- Use `BindToClose` for server shutdown and `PlayerRemoving` for normal leaves. A DevForum reply describes this lifecycle, but I did not verify it against the Creator Hub.

## 3. Combat
- Community consensus: the client predicts the hit, and the server validates it. The server checks distance, timing, and line of sight before applying damage.
- ShapecastHitbox fires `OnHit` for every part hit and can trigger repeated calls. Filter already-hit targets.
- Reports of server-side hitbox problems (RunContext issues, latency) are user reports, not confirmed bugs.
- Combat tagging is best done on the server. Tag on damage and clear the tag after inactivity.

## 4. Networking
- Creator Hub says every client value must be validated server-side. Rate limiting should use a token bucket on the server. Client-side limits are never enough.
- UnreliableRemoteEvent is for frequent, replaceable data (for example, buffers of movement state). Use RemoteEvent for anything the server must receive.
- A DevForum post reports a "60 per second spam" threshold and a 500/s documented limit. Neither is verified.

## 5. Combat logging and server hops
- Mark players in combat on damage. Detect disconnects in a `PlayerRemoving` handler and a `BindToClose` handler, so restarts are not punished.
- Roblox's server-side detection docs say never ban on client-side detection alone. Treat detection as a signal.
- I found no official guidance on penalties.

## 6. UI
- react-lua: most mature and best documented.
- Fusion: most popular in the sources I found.
- Vide: simpler syntax, little independent coverage.

## 7. Cross-server
- MemoryStoreService: community-reported total limit of 64 KB + 1 KB per user, and a 45-day maximum expiry. Verify on the official limits page.
- MessagingService: message size caps have changed. A 2026 increase is reported as 4x. Verify.

## Risks and pitfalls
- Item duplication via rejoin race: use session locking and reject trades if the profile was loaded elsewhere. (https://devforum.roblox.com/t/preventing-item-duplication-via-trading/277460)
- Open Cloud execution scope: a key without the write scope may return success and change nothing. Re-read the resource to verify. (https://create.roblox.com/docs/cloud/reference/features/luau-execution.md)
- Client-hit trust: hits from clients must be re-validated on the server. (https://create.roblox.com/docs/scripting/security/client-server-boundary)
- Rate limits are not built in. Implement token buckets per player per action. (https://create.roblox.com/docs/scripting/security/client-server-boundary)
- Unreliable remotes can drop state the server needs. (https://devforum.roblox.com/t/introducing-unreliableremoteevents/2724155)
- DataStore throttling: queued requests can fail with codes 301–306. Batch and back off. (https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits.md)
- Shutdown saves: BindToClose has limited time. Keep saves short. (https://devforum.roblox.com/t/how-to-track-dupes/2832360)
- Undocumented limits: Roblox says some limits are not documented. (https://create.roblox.com/docs/cloud-services/memory-stores.md)

## Not confirmed
- Rojo 7.7.0 release date and whether it breaks existing projects.
- Whether TestEZ is deprecated in favor of a Jest-Lua port.
- Selene 2026 status.
- Exact current Open Cloud scope requirements.
- Exact DataStore request budget in 2026.
- MemoryStore and MessagingService current limits.
- Blink, Zap, and BlinkBlox performance numbers (self-reported).
- Whether Roblox has a built-in remote rate limiter.
- Vide's current maintenance and feature set.
- Official Roblox guidance on combat-log penalties.
