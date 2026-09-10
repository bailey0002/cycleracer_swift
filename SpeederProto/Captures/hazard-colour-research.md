# Hazard colour research (7 Sep 2026)

Question: what colour should road obstacles be in a dark neon scene whose lane lights are cyan,
cityscape strips warm, tunnel rings red, engine glow cyan/magenta and explosions orange?

## Recommendation

A saturated lime around sRGB (0.75, 1.00, 0.18) is the best-supported hazard colour for this
palette. It sits at the eye's photopic peak, has roughly 4x the luminance of the red rings and 3x
the magenta, keeps its identity under deuteranopia/protanopia (red, orange and magenta collapse to
olive or blue), and it is the only hue slot not already used by a role. Its two risks, merging with
yellow signage and whitening under bloom, are handled by keeping hazard emissives dimmer than the
decorative neon, giving obstacles a dark body with a glowing lime rim, and backing the colour with a
non-colour cue (stripes, an X, a slow pulse at or below 3 flashes per second). Reserve lime for
"will hurt you" and nothing else.

## Conventions

- ISO 3864 assigns signal yellow to warning and yellow/black 45 degree stripes to hazard locations; ISO 3864-2 grades yellow, orange, red. https://en.wikipedia.org/wiki/ISO_3864
- ANSI Z535.1: yellow = caution, orange = warning, red = danger; safety yellow is close to #EED202. https://incompliancemag.com/ansi-z535-1-safety-colors-in-focus/ and https://en.wikipedia.org/wiki/ANSI_Z535
- Hi-vis garments use fluorescent yellow-green because photopic sensitivity peaks near 555 nm. https://www.ergodyne.com/blog/understanding-hi-vis-standards-ansi-isea-107
- Thumper: red/orange damages you, blue/green is safe or collectible. https://steamcommunity.com/sharedfiles/filedetails/?id=1255221235 and https://www.gamedeveloper.com/design/how-i-thumper-i-uses-striking-visuals-to-complement-gameplay-at-every-turn
- Beat Saber: notes red/blue, bombs black, walls a third class. https://en.wikipedia.org/wiki/Beat_Saber
- WipEout HD: speed pads are blue chevrons, weapon pads red crosses; shape and colour per role. https://www.techradar.com/how-to/wipeout-omega-collection-tips-and-tricks
- Sickly green is the established convention for toxic. https://tvtropes.org/pmwiki/pmwiki.php/Main/TechnicolorToxin

## Perception

- Yellow has the highest luminance of any hue, blue the lowest; blue vs yellow is an opponent channel, so lime on a blue-purple ground is maximally opposed in luminance and chroma. https://www.workwithcolor.com/color-luminance-2233.htm and https://engineering.purdue.edu/~bouman/ece637/notes/pdf/Opponent.pdf
- Rec.709 luminance: chartreuse 0.85, cyan 0.79, magenta 0.29, red 0.22. Contrast against the road is about 17:1 for lime versus 5:1 for red.
- Helmholtz-Kohlrausch: saturated red/blue look brighter than equiluminant yellow; desaturated yellow loses conspicuity, so keep lime saturated and do not let bloom wash it. https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0005091
- Bloom thresholds use luma weights, so lime blooms at about 3x lower intensity than magenta, and filmic tone mapping drives bright emissives to white. https://learnopengl.com/Advanced-Lighting/Bloom and https://www.donmccurdy.com/2024/04/27/emission-and-bloom/
- Chartreuse reads as radioactive; fine for a hazard, bad anywhere else. https://www.nixsensor.com/color-column-yellow-green-chartreuse/

## Colour-blind safety

- Deuteranopes confuse reds, oranges, yellows and light greens; protanopes see reds as dim. Do not communicate with colour alone; manage colours as role presets. https://media.gdcvault.com/gdc2019/presentations/Solving%20An%20Invisible%20Problem-Colour-Blindness.pdf
- Fluorescent yellow was the most visible colour for both protanopes and deuteranopes in a 2022 study; fluorescent orange dropped sharply for protanopes. https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0274824
- Under dichromat simulation lime, yellow, orange and red converge on the same hue and differ only by luminance; lime stays distinct from cyan and magenta. Pattern or animation must separate hazard classes. https://gameaccessibilityguidelines.com/ensure-no-essential-information-is-conveyed-by-a-colour-alone/ ; keep strobes at or below 3 flashes per second. https://www.w3.org/WAI/WCAG21/Understanding/three-flashes-or-below-threshold.html

## Colour by role

- Mirror's Edge reserves red for the runner path and keeps it out of the rest of the palette. https://www.worldofleveldesign.com/categories/game_environments_design/mirrors-edge-color.php
- Doom Eternal: colour-coded pickups are read in a millisecond and consistency is what makes it work. https://www.shacknews.com/article/117067/doom-eternal-was-built-to-be-more-brutal-super-mario-less-last-of-us

## Concrete values

1. Primary hazard lime (0.75, 1.00, 0.18) #BFFF2E. Emissive 2x to 3x with the bloom threshold near 1, decorative neon well above it; dark body with a lime rim so the core never whitens.
2. Greener variant if yellow signage crowds it: (0.62, 1.00, 0.15) #9EFF26.
3. Second obstacle class: same lime with black diagonal stripes and a 1 to 2 Hz pulse; if a distinct hue is mandatory, safety orange (1.00, 0.42, 0.00), accepting overlap with explosions.

Applied in the prototype: hazard lime set to (0.75, 1.00, 0.18); hazard emissive intensities lowered below the decorative neon; red X marks on blocks, gates and hatches (white on the red-bodied skin); strobe kept at 2.5 flashes per second.
