# Best Practices

These are the standards expected from any code produced in this environment.
Follow them consistently, regardless of project size or language.

---

## Architecture

Write code that is professional, modular, well-structured, easy to test, and secure. Each piece should be independently understandable and verifiable in isolation.

For every project, evaluate which architectural style best fits its complexity, domain, and constraints. Consider options such as **hexagonal (ports & adapters)**, **layered / N-tier**, **clean architecture**, **MVC**, **event-driven**, **microservices**, **modular monolith**, or minimal structure for small scripts and libraries — and any other style that fits better. Pick the lightest structure that still satisfies the principles above.

---

## Modularity

Complex problems must be broken into small, focused, independently understandable pieces.

- Every function, class, or module does **one thing** and does it well.
- If something is getting large or hard to read — split it.
- A good rule of thumb: if you can't describe what a piece of code does in one sentence, it needs to be broken down further.
- Organize code **by feature/domain**, not by technical type (avoid dumping everything into generic `utils/` or `helpers/` folders).

---

## Code Quality

- **Names must communicate intent.** Variables, functions, and classes should be self-explanatory. Avoid abbreviations and vague names (`data`, `info`, `temp`, `x`).
- **No unnecessary comments.** The code should read like clear prose. Comment the *why*, never the *what*.
- **Prefer early returns** to reduce nesting and keep the happy path clean.
- **Avoid magic numbers and hardcoded values.** Use named constants or environment variables.
- Configuration and secrets always come from **environment variables** — never hardcoded.

---

## Testing

A modular structure makes every meaningful piece of logic testable in isolation — take advantage of that.

- **Core business logic** must have unit tests. It has no external dependencies, so there's no excuse.
- **Integrations with external systems** (databases, APIs, queues, etc.) should have integration tests validating they work correctly with what they connect to.
- Tests should validate **behavior**, not implementation details. Don't test *how* something works internally — test *what* it produces.
- Tests are part of the deliverable. Working code without tests is unfinished code.

---

## External APIs & Environment Variables

Never hardcode API keys, tokens, or any credentials directly in the code.

- All keys and secrets must live in a `.env` file at the root of the project.
- The `.env` file must always be listed in `.gitignore` — it should never be committed.
- Provide a `.env.example` file with the variable names but no real values, so anyone setting up the project knows what's needed.
- When integrating with an external API, check `ESSENTIALS.md` first — it contains the preferred keys and models to use for each provider.

---

## Performance & Optimization

Write code that is correct and clean first — but always with performance in mind.

- Don't over-engineer optimizations upfront, but don't be careless either.
- Prefer solutions that scale reasonably well by default (avoid unnecessary loops inside loops, redundant queries, loading more than needed, etc.).
- When there's a trade-off between simplicity and performance, document the reasoning.
- Leave room in the design for optimizations to be added later without major refactoring.

---

*These practices exist to keep the codebase clean, testable, and maintainable over time. When in doubt, optimize for clarity and structure.*
