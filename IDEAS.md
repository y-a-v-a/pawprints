# 5 app ideas for apfel / Apple Foundation Models

Environment: macOS 26.5, Apple Silicon, Xcode 26.4 (Swift 6.3), apfel v1.16.0.
Model: ~3B on-device, **4096-token context** (input + output), ~1–3 s per short reply,
15 languages, guided generation (`@Generable`/`@Guide`, regex/anyOf/range guides),
tool calling, streaming snapshots, `contentTagging` use case, permissive guardrails.
No embeddings from apfel (but `NaturalLanguage.NLEmbedding` exists on-device), weak at
world knowledge/arithmetic/long reasoning, strong at short roleplay, rewriting,
extraction, classification and constrained structured output.

Probe results on this Mac:
- In-character roleplay with a hidden secret: good, ~2 s, kept the secret.
- "Murder mystery" wording: *not* blocked by guardrails.
- Free-form formatting instructions ("short kebab-case filename"): ignored → needs guided generation.
- Grammar explanations (French tutor): correction right, explanation hallucinated.

---

## 1. Whodunit: an on-device detective interrogation game
**Built with:** Foundation Models (Swift / SwiftUI macOS app)

A procedurally generated murder mystery where you **interrogate suspects in free text**.
The game engine (plain Swift, deterministic) decides the truth: victim, culprit, motive,
weapon, timeline, and which clue each suspect knows. The model only does what it's good
at: writing flavour and **playing each suspect in their own `LanguageModelSession`**, with a
persona, a secret, and rules about what they'll admit.
- Guided generation keeps it honest: each reply is a `@Generable` struct
  `{ dialogue, composure 0–10, revealedClue: anyOf([allowed clue ids] + "none") }`, so the model
  can only "leak" clues the engine allows, and the UI can show a nervousness meter.
- Pressing with evidence ("I found your glove in the greenhouse") changes what a suspect will admit.
- Detective notebook auto-fills with the clues you've uncovered; accuse at the end; the engine
  scores you. Infinite replayability, fully offline, no API key.
- Shows off: multiple concurrent sessions, guided generation with dynamic `anyOf`, streaming, prewarm.

## 2. Tidy: your screenshots and downloads, named by AI
**Built with:** Foundation Models + Vision (Swift CLI + launchd watcher, optional menu bar)

Watches `~/Desktop` / `~/Downloads`. When `Screenshot 2026-10-22 at 14.03.11.png` or
`document (3).pdf` lands, it OCRs it on-device (Vision / PDFKit), then asks the model for a
`@Generable` `{ slug (regex-guided kebab-case), category: anyOf([...]), finderTags[] }`, and
renames it to `2026-10-22 acme-invoice-4471.png`, applies Finder tags, optionally files it into
folders. Undo ledger, dry-run mode.
- Screenshots are full of private stuff (bank pages, chats), so on-device inference is the selling point.
- Shows off: regex/anyOf guides, `contentTagging`, Vision OCR, real daily utility.

## 3. Polyglot Café: a voice conversation partner for learning languages
**Built with:** Foundation Models + Speech + AVFoundation (SwiftUI)

Pick a language (any of the model's 15) and a scene ("ordering at a Lyon boulangerie").
Talk out loud; on-device speech recognition → the character replies in the target language,
spoken back with a native TTS voice. Each turn also returns a structured "gentle correction" card
and new vocabulary.
- Risk (measured): corrections are fine but **grammar explanations get hallucinated**, so the
  teaching layer has to be heavily constrained.
- Shows off: multilingual model, speech in/out, streaming structured output.

## 4. Dear Diary: your Mac writes the diary of your day
**Built with:** apfel CLI (`--schema`, `-s`) + a tiny launchd sampler + generated HTML

A background sampler records (locally) what you were doing every few minutes: frontmost
app, window title, current git branch, Music track, calendar event titles. At the end of
the day apfel turns the log into a warm, slightly funny diary entry plus a visual timeline
("Spent the morning wrestling `AuthService.swift`, briefly fled to YouTube, came back stronger").
- This data is far too personal for a cloud LLM, so it's a natural on-device use case.
- Needs chunking (4096 ctx) → hourly summaries rolled up into a daily entry.
- Shows off: apfel as a UNIX tool, JSON schema output, hierarchical summarisation.

## 5. Margin: an on-device reading companion in the browser
**Built with:** `apfel --serve --cors` (OpenAI-compatible API) + a Chrome extension

A browser extension that writes notes in the margin of any article you read: a one-line
TL;DR per section, plain-English definitions of jargon you hover, and a "so what?" summary.
Everything goes to `localhost:11434`, so your browsing history never leaves the machine.
- Needs per-section chunking for the 4096 window; streaming makes the margin fill in live.
- Shows off: apfel server mode, OpenAI SDK compatibility, CORS/token security.

---

## The debate, and the verdict

I asked one subagent for an independent ranking, then argued it through over four rounds. It
probed the model with `apfel` before giving opinions, then play-tested the build twice.

**Ranking:** 1. Whodunit · 2. Tidy · 3. Polyglot Café · 4. Margin · 5. Dear Diary.

- **Whodunit wins on wow factor**, but only if *the engine directs and the model acts*. Probes
  showed the naive version (truth in the prompt, full transcript replayed) leaks the secret,
  repeats itself word for word, and ignores compound rules.
- **Tidy** fits the model best, but nobody shows a friend a file renamer.
- **Polyglot Café** looked great, but its grammar explanations were wrong about half the time.
- **Margin** re-implements Safari's built-in summaries, and **Dear Diary** needs TCC
  permissions plus a day of real data, so neither can be verified in one session.

**What the probes decided:**

| Question | Finding | Decision |
|---|---|---|
| Murder or theft? | Murder lines blocked by guardrails ~12%; theft ~2% | A cosy theft |
| Let the model "reveal" facts? | Fully right 2 times in 24 | Engine writes first-person scripts; the model only restyles |
| Replay the transcript? | The model copies earlier turns verbatim | Stateless turns |
| Plain text or guided generation? | Plain text runs on, writes both sides | `@Generable` everywhere, streamed and cut |
| Portraits? | Image Playground refuses people | An animal cast (it suits the tone anyway) |

**Result:** [Pawprints](README.md), a cosy animal detective game. Every case is generated from a
seed. Suspects are voiced by Foundation Models, and the art is painted on-device by Image Playground.
