# Personal Coach Web V0

A deliberately low-friction executive-function companion. This version is built for one primary user first and targets the loop:

1. Brain dump without organizing.
2. Let the system choose a starting point.
3. Reduce work to one small visible action.
4. Start a short focus session.
5. Recover quickly from anxiety, frustration, distraction, or overwhelm.

## Product principles

- Starting matters more than finishing.
- Never punish a missed plan.
- No streaks, red overdue counters, productivity scores, or backlog on the home screen.
- Reduce choices when the user is overwhelmed.
- The default view should answer: **What should I do right now?**
- AI may propose plans/actions later, but deterministic application logic validates state changes.

## Run

```bash
cd web
npm install
npm run dev
```

Open http://localhost:3000.

## V0 scope

The current prototype is intentionally local-only and does not require an API key or database. The next milestones are persistence, task extraction, deterministic scheduling, optional LLM coaching, PWA installation, and cloud deployment.
