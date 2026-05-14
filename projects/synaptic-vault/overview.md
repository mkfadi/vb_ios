# Synaptic Vault Overview

## Implementiert

## Today Tab

- Neuer Default-Tab `Heute` vor dem Brain-Graph mit Tagesdatum, Fokus, Prioritäten, Daily Note und Inbox-Übersicht.
- `STATUS.md` wird per wiederverwendbarem H2-Section-Parser ausgewertet; Frontmatter wird vor dem Rendern ausgeblendet.
- Daily Notes unter `daily/YYYY-MM-DD.md` können direkt aus der Heute-Ansicht angelegt und geöffnet werden.
- Pull-to-Refresh lädt `STATUS.md` und die heutige Daily Note frisch von GitHub.
