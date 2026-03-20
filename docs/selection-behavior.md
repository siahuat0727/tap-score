# Score Selection & Navigation Behavior

## Modes

The editor has two modes:

- **Input mode** — no element is selected. A blinking blue cursor line shows where the next note will be inserted. Tapping a piano key inserts a note at the cursor position.
- **Selection mode** — an element (note, time signature, or key signature) is highlighted. Arrow keys adjust the selected element. Pressing a piano key inserts a note at the cursor (which sits just after the selected note).

## Inserting Notes

Tapping a piano key inserts a note at the current cursor position and stays in **input mode** — the cursor advances past the new note, ready for the next input. No note is selected after insertion.

## Selecting Elements

| Action | Result |
|---|---|
| Click a note | Selects it (blue highlight). Cursor moves to just after that note. |
| Click key signature | Selects it (blue highlight). |
| Click time signature | Selects it (blue highlight). |
| Tap already-selected key sig | Opens key signature picker. |
| Tap already-selected time sig | Opens time signature picker. |
| Click background | Deselects everything. Returns to input mode with cursor at end. |

Clicking a time signature or key signature selects it for keyboard adjustment (up/down arrows). Tapping the same element again opens the full picker dialog.

## Arrow Key Navigation

**Left/Right** moves through elements in visual left-to-right order:

```
Key Sig ↔ Time Sig ↔ Note 0 ↔ Note 1 ↔ ... ↔ Note N-1 ↔ Cursor (end)
```

- Pressing **←** at the leftmost element (key signature) does nothing.
- Pressing **→** at the rightmost position (cursor at end / input mode) does nothing.

**Up/Down** adjusts the value of the selected element:

| Selected element | Up | Down |
|---|---|---|
| Note | Raise pitch by one diatonic step | Lower pitch by one diatonic step |
| Time signature | Increase beats per measure | Decrease beats per measure |
| Key signature | Add one sharp (circle of fifths) | Add one flat (circle of fifths) |
| Nothing (input mode) | No effect | No effect |

## Cursor vs. Highlight

- The **blinking cursor line** only appears in input mode (nothing selected).
- The **blue highlight rectangle** only appears when an element is selected.
- They never appear simultaneously.

## Web Keyboard Support

Arrow keys and Delete/Backspace work even after clicking inside the score area on web. Key events from the iframe are forwarded to the Dart layer.

## Input Shortcuts

- `d f g h j k l` insert `C4 D4 E4 F4 G4 A4 B4`.
- `` ` `` enters rest mode when in input mode. The next duration choice inserts a rest and exits rest mode.
- In rest mode, the duration buttons display rest symbols instead of note symbols.
- If a note is selected, pressing `` ` `` converts that selected note into a rest while preserving its timing.
- `1 2 3 4 5` select whole, half, quarter, eighth, and sixteenth durations.
- `6` toggles dotted mode.
- `9` toggles triplet mode.
