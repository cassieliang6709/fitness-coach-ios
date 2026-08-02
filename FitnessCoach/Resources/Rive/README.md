# Rive mascot contract

`rive-skills-demo.riv` is the MIT-licensed Rive iOS sample used only by the
debug lab to verify state-machine rendering and input changes.

To replace the production PNG mascot with the rigged character, export a file
named `mascot.riv` into this directory. Its default state machine should expose
a number input named `Action`:

- `0...9` currently map to `MascotPose.allCases` in the order declared.
- The same contract can expand to `0...49` when the exercise animation list is
  finalized.
- If `mascot.riv` is absent, the app intentionally keeps using the PNG artwork.

The final file must be authored from separated character layers or redrawn
vectors. A single flattened PNG cannot provide independent bones by itself.
