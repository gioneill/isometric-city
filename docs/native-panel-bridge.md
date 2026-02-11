# Native Panel Bridge

Documenting the new interop messages between the web game (React) and the iOS host so native SwiftUI panels can drive budget, stats, and advisor views.

## Message Flow

### Native → Web
- `panel.data.request`
  - Payload: `{ panel: "budget" | "statistics" | "advisors" }`
  - Web app responds with `panel.data` carrying the requested snapshot.
- `budget.setFunding`
  - Payload: `{ key: <budget key>, funding: number }`
  - Web updates the budget and (optionally) emits fresh `panel.data` back to native.

### Web → Native
- `panel.data`
  - Payload: `{ panel: string, data: object }` with panel-specific shapes:
    - Budget: `{ stats: { income, expenses, population, jobs, money }, categories: [{ key, name, funding, cost }] }`
    - Statistics: `{ stats: { population, jobs, money, income, expenses, happiness }, history: [{ year, month, population, money, happiness }] }`
    - Advisors: `{ stats: { happiness, health, education, safety, environment }, advisorMessages: [{ name, icon, messages, priority }] }`
- `host.state` keeps emitting the baseline stats as before, with `jobs` added so native HUD pills stay accurate.

## Client Responsibilities
- React `Game.tsx` listens for `panel.data.request` and uses `postToNative` to send the snapshot.
- Swift host requests snapshots on sheet open and re-requests after budget edits.
- Budget slider changes dispatch `budget.setFunding` through the bridge; the web app updates state, keeps `latestStateRef` in sync, and optionally re-sends fresh `panel.data` so the sheet’s view stays accurate.
