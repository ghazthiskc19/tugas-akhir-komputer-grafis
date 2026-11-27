# Island 1 UI/audio polish audit

## Render captures (1280×720, windowed, seed 42)

`evidence/polish/before_fresh_*.png` records a fresh menu, intro, exploration HUD, low-HP combat state, toast, pause, settings, map, boss presentation and completion. `before_continue_*.png` records the same sequence after loading a scratch Continue save containing two artifacts. The files were inspected at native resolution.

### Findings from captures

- Fresh menu has clear hierarchy and adequate contrast; Continue is correctly disabled without a save. Its title could better distinguish the series name from the game name.
- Intro and completion fit the frame at 1280×720 with readable text and consistent button frames.
- HUD values are legible; objective target/distance is now a distinct gold headline with the longer hint secondary. Low-HP feedback is obvious and slow, but the captured 10 HP state still shows a broad red tint more strongly than a subtle edge warning; tune it further after human review. Stamina tint/trail and potion-pop timing should likewise be judged in motion.
- Artifact pickup toast is readable but small and has no source-name subline; consecutive milestone toasts can replace one another.
- Pause/settings use a consistent ornate frame, but save-button icon can offset text alignment. The menu has more vertical content than the other overlays.
- Map terrain and objective list are legible. Close objective markers can overlap labels (e.g. Puncak/player arrow and spawn/checkpoint labels); north-edge markers approach the map frame.
- Boss HUD fits, though it shares vertical space with the wake-up toast. Completion stats and buttons fit within the panel.
- The capture's health was changed by the fixture/teleportation sequence; it demonstrates the visual state, not a natural combat playthrough.

## Changes in this pass

The before/after screenshots show the larger split menu title and the objective hierarchy change: the target/distance is a distinct gold headline and the longer hint secondary. Shared buttons now shrink briefly on press and ease back to their hover state. HUD feedback additions include a 0.9 Hz low-HP edge pulse below 30% HP (stronger below 15%, no rapid strobe), a stamina low-state tint below 25%, refused dodge/block feedback, and queued artifact messages with a large icon and source subline. HP, damage, stamina, costs, and gameplay timings are unchanged. No audio assets were added.

Evidence folders include fresh and Continue captures (Continue fixture has two artifacts); captures were read at native 1280×720. The menu and objective hierarchy are clearer. Remaining issues are visible: Puncak/player and spawn/checkpoint labels collide on the map; compass labels are still small/tight at the edges; the 10 HP test frame reads as a broad red tint more than a subtle edge alert; and the boss bar, wake toast and death overlay overlap vertically in the artificial boss screenshot. The fixture changes player state and is not a natural combat sequence. Full settings spacing and human feedback on button motion remain open.

Final-code verification: `island_shutdown_regression` menu 36 checks/0 failed, pause 38/0, window 38/0. Full `--qa-playthrough --seed=42` PASS (194.9 simulated seconds, 3 artifacts, one boss attempt, zero deaths). No script errors appeared; Godot did report 2 resources still in use at exit. The final fresh-save windowed captures were re-read and archived as `final_fresh_*.png`; earlier Continue captures remain in the same evidence folder.

## Audio measurements and limits

Clip RMS/peak was measured by decoding shipped files locally (mono-folded RMS; relative dBFS): explore music RMS −17.9 dBFS; boss themes −14.8 dBFS; sea ambience −17.0 dBFS; forest ambience −52.8 dBFS. At code startup gains (music −12 dB, forest +12 dB, sea −23 dB) and Master slider 0.8 (−1.94 dB), estimated outputs are music −31.8 dBFS, forest −42.7 dBFS, sea −41.9 dBFS; boss music at −11 dB estimates −27.8 dBFS. Pause duck targets music −7 dB and ambience −10 dB; boss start ducks ambience a further −8 dB, using eased fades. These are estimates from decoded file levels and mixer gains, not live RMS measurements.

SFX event gains range −20 dB (hover) to −2 dB (death/roar); measured example interaction SFX is unusually quiet (−46.8 dBFS RMS before event gain), while sword hit samples peak near −6 dBFS after event gain.

Music/SFX/ambience comfort, harshness, loop seams, transient punch, fatigue, and whether ducking feels natural require a human listening pass on speakers/headphones. Device, operating-system mixer, room, and user volume vary.
