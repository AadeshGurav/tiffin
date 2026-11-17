# Diagrams

Animated, self-contained SVGs. They play inside GitHub, VS Code and any browser
when embedded with `<img>` or `![](…)`, need no JavaScript, and stay readable as
a still frame (printing, PDF export, reduced-motion viewers).

| File | Shows | Used in |
| --- | --- | --- |
| [`architecture.svg`](architecture.svg) | Phones → local cache → shared Firestore, rules, auth | OVERVIEW, DEVELOPER_GUIDE |
| [`scan-flow.svg`](scan-flow.svg) | The five checks behind accept / reject | OVERVIEW, USER_GUIDE §3.1 |
| [`daily-loop.svg`](daily-loop.svg) | Top-up → scan → menu → purchase → margin | OVERVIEW |
| [`roles.svg`](roles.svg) | Admin / counter / scanner and who is scanned | OVERVIEW, USER_GUIDE §1 |
| [`roadmap.svg`](roadmap.svg) | Shipped milestones and planned next steps | OVERVIEW |

## Changing one

Edit `tool/diagrams/gen_diagrams.py` and run `python3 tool/diagrams/gen_diagrams.py`.
The SVGs are generated, so don't hand-edit them. The script holds the design
rules (diagram-design skill, default skin): orthogonal connectors, masked
labels, one or two accent elements per diagram, a 4px grid.

## Why generated SVG, not GIF or Mermaid

- **GIF:** a binary blob that can't be diffed, is blurry on retina screens and
  weighs 10–100× more. SVG is text, so a changed fact is a one-line diff.
- **Mermaid:** auto-layout and no animation; the result looks like every other
  Mermaid diagram.
- **Trade-off:** SMIL animation is ignored by a few viewers (they show the
  still frame, which is complete), and fonts fall back to system faces inside
  an `<img>`, because an image can't load web fonts.

## Keeping them true

A diagram that disagrees with the code is a bug (CLAUDE.md §15). When a change
touches a role, a scan check, the data path or the roadmap, update the script
and regenerate in the same commit. The roadmap's "Next" row comes from
PRD §9 and ADR 0006 "Consequences"; remove an item when it ships.
