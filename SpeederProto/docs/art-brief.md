# Art brief for generated environment images (27 Sep 2026)

Images to generate with an AI image tool, to replace the procedural facades, signs and backdrops
with real detail. Every prompt below is self-contained: paste it as written, with no other context.
The colours come from the code (`Utilities/Platform.swift` `Neon`, `Scene/Theme.swift`,
`Scene/WorldScroller.applyPalette`, `Rendering/ProceduralTextures.swift`) and from the reference
frames (`Captures/polish/p10/cruise/frame-9.png` for Neon City, `p7/canyon/` for the canyon,
`p7/grid-side/` for The Grid).

## Rules for every image

- PNG, sRGB, no watermark, no signature, no lens distortion, no vignette, no film grain (the post
  pass adds its own bloom, blur, rain and dirt).
- No text unless the item says so. When text is allowed it must be invented words, never a real brand.
- Flat, even lighting inside the image. The scene lights it; a baked sun or a baked glow on one side
  breaks when the piece repeats.
- Backgrounds exactly black (`#000000`) where the item says black, or transparent (alpha) where it
  says transparent. Never a gradient sky in a facade or backdrop tile; the game draws the sky.
- Same seed and the same style line for every image of a world so the batch matches:
  `style: stylised realism, clean hard-surface, game texture, no painterly strokes`.
- Deliver into `SpeederProto/Resources/Art/<world>/` with the file names given.

## The three palettes

Values are what the materials are set to (also what the screen shows after the grade, within a
shade). Ranges are the room an image has before it stops matching.

### Neon City (night, rain)

| Role | Hex | Range / note |
|---|---|---|
| Road edge, HUD accent | `#19F2FF` cyan | `#00E5FF` to `#59F5FF`; nothing else in the world may be this cyan |
| Road secondary lines | `#CCF2FF` pale cyan-white | |
| City signs, warm set (only these on facades) | `#FF8C1F` orange, `#FF1FB3` magenta, `#FFD933` yellow, `#FF1A2E` red | pick one or two per sign, never the road cyan |
| Lit windows | `#FFCC8C` warm (55 %), `#99D1FF` cool (27 %), `#D9E0FF` white (11 %), rare magenta or cyan | about a quarter of windows lit at night |
| Unlit facade | `#0A0812` to `#1A1626` | very dark blue-violet, never grey, never brown |
| Sky and fog | `#130B26` fog, zenith near `#05030C`, a thin magenta horizon band `#4A1447` under the skyline | the frames show a violet haze, not black |
| Hazards / obstacles | `#BFFF2E` lime | reserved: do not use lime anywhere in the art |
| Beacon rings | `#FF1F2E` red | reserved |
| Rain, wet road highlights | `#CFE8FF` | the road is dark `#0B1522` with cyan and magenta reflections |

### Sunset Canyon (daylight, low sun)

| Role | Hex | Range / note |
|---|---|---|
| Rock, lit | `#C9683A` to `#8C4A28` | rust and terracotta banding; the undercity is `#6E3A24` |
| Rock, shadow | `#3A2418` to `#2A1B14` | |
| Sand / ground | `#8C6642` to `#B08050` | |
| Sky zenith | `#29215C` violet | |
| Sky horizon | `#FF8C4D` orange to `#FFB070` | sun straight ahead, halo `#FFE0B0` |
| Painted road | edges `#FFFAE6` white, centre `#FFD94D` yellow | no neon; neon is at 28 % here |
| Signs and lights | `#FFA33B` amber, `#FFE6B3` | amber only, no cyan or magenta |
| Fog | `#C7805A` at 25 % | warm haze between ridges |
| Hazards | `#FFFFF2` white | reserved |

### The Grid (arena, Tron)

| Role | Hex | Range / note |
|---|---|---|
| Floor | `#0B1A33` to `#102647` | deep blue, glossy, with a cyan grid line `#5AC8FF` every 6 m |
| Rails, pylons, edge light | `#59D9FF` cyan, `#33BFFF`, `#73E6FF` | the only bright colour in the architecture |
| Background walls | `#0F2140` to `#183358` | flat, tall panels, darker toward the top |
| Sky / fog | `#03070F` fog, `#0A1C38` glow at the horizon | near-black blue, never pure black |
| Player trail | `#C7F7FF` white-cyan | reserved |
| Rival trails, hazards | `#FF7A1A` orange (KADE), `#FF3B8C` (ORIN), `#FFCC26` (SABLE), lime `#BFFF2E` decks | reserved |
| Crowd glow sticks | `#59D9FF` cyan and `#FFFFFF`, a few `#FF7A1A` | |

## Neon City

### 1. Facade tiles (12 images, `neon-facade-01.png` to `-12.png`)

512 x 512. Straight on, no perspective, tiles vertically (top edge continues the bottom edge).

> A flat, straight-on section of a night-time cyberpunk skyscraper facade, filling the whole frame edge
> to edge, no ground, no sky, no perspective, orthographic view. Dark blue-violet wall panels
> (#0F0C1A) with visible seams, pipes, vents, balconies and cable trays. Regular rows of windows,
> about one in four lit: warm amber (#FFCC8C), some cool blue (#99D1FF), a few white. Small signs
> and light strips in orange (#FF8C1F) or magenta (#FF1FB3), no cyan, no green, no text. Even
> lighting, no rain, no glow halos. Seamless texture that repeats vertically. Style: stylised
> realism, clean hard-surface, game texture, no painterly strokes.

Vary between images: panel material (concrete, steel, glass curtain wall, corrugated), window
pitch (tall narrow, square, ribbon), and how much greeblework. Two or three of the twelve should be
almost all glass with reflections of nothing (dark), for the towers behind the towers.

### 2. Billboard art (10 images: 6 x `neon-sign-L-01..06.png` 1024 x 512, 4 x `neon-sign-P-01..04.png` 512 x 1024)

> A cyberpunk advertising billboard image, filling the whole frame, night, dark background
> (#0A0812). Subject: [a stylised woman's face in profile lit by magenta and cyan neon / a chrome
> hover vehicle / a pair of eyes behind a visor / a bottle of glowing drink / a stylised city skyline
> logo / abstract neon geometry]. Palette limited to magenta (#FF1FB3), orange (#FF8C1F), yellow
> (#FFD933), with white highlights; no cyan, no green. One invented brand word in a bold
> sans-serif, such as "NEXUS", "AXIOM", "PULSE", "KAZE", "VELA", "ORBIT". Flat graphic poster look,
> even brightness, no lens flare, no frame or bezel. Style: stylised realism, clean hard-surface,
> game texture.

Swap the subject in the brackets per image. The faces are the ones the reference shows; three of
the ten should be faces.

### 3. Skyline backdrop strips (3 images, `neon-skyline-far.png`, `-mid.png`, `-near.png`, 4096 x 1024)

Left and right edges must meet exactly (the strip wraps 360 degrees). Sky transparent.

> A wide panoramic night city skyline of cyberpunk skyscrapers, seen from street level far away,
> silhouettes with scattered lit windows in warm amber (#FFCC8C) and cool blue (#99D1FF), a few
> tall antenna towers with red aircraft lights (#FF1A2E), a few large distant billboards glowing
> magenta (#FF1FB3) and orange (#FF8C1F). The buildings occupy the bottom [30 / 45 / 60] percent of
> the frame; everything above them is fully transparent (alpha), not a drawn sky. Buildings are
> [very hazy, low contrast, tinted violet #2A1B45 / medium contrast / full contrast with visible
> facade detail]. No ground, no road, no foreground objects, no text. The left edge of the image
> must continue seamlessly into the right edge. Even lighting, no lens flare. Style: stylised
> realism, clean hard-surface, game texture.

Use the first bracket value for far, the second for mid, the third for near.

### 4. Ground-level storefronts (6 images, `neon-shop-01..06.png`, 1024 x 512)

> A straight-on view of a cyberpunk street-level shopfront at night, filling the frame, no
> perspective, no street, no sky: roller shutter or glass front, a lit sign above in orange
> (#FF8C1F) or magenta (#FF1FB3), a vending machine, air-conditioning units, cables, steam vents,
> a noodle bar counter or a repair shop interior glowing warm amber (#FFCC8C) behind the glass.
> One invented shop word on the sign, such as "RAMEN", "GRID PARTS", "VOLT". No people. No cyan,
> no green. Even lighting. Style: stylised realism, clean hard-surface, game texture.

## Sunset Canyon

### 5. Rock wall tiles (8 images, `canyon-rock-01..08.png`, 512 x 512, tiles both ways)

> A flat, straight-on section of a sandstone canyon wall, filling the whole frame, orthographic,
> no sky, no ground. Horizontal banding in rust (#C9683A), terracotta (#8C4A28) and dark brown
> shadow (#3A2418), weathered cracks and ledges, lit evenly from the front with no strong shadow
> direction. Seamless texture that repeats both horizontally and vertically. Style: stylised
> realism, clean hard-surface, game texture.

### 6. Ridge strips (3 images, `canyon-ridge-far.png`, `-mid.png`, `-near.png`, 4096 x 1024)

> A wide panoramic silhouette of desert mesas and canyon ridges at sunset, seen from the canyon
> floor, occupying the bottom [30 / 45 / 60] percent of the frame, everything above fully
> transparent (alpha), not a drawn sky. Rock in [hazy pale orange #E8A070 with low contrast /
> warm rust #C9683A with soft shadow / full-contrast rust and terracotta with visible strata and
> a few dark shadow faces #3A2418]. No sun in the image, no clouds, no ground, no road, no
> vegetation, no text. The left edge must continue seamlessly into the right edge. Style: stylised
> realism, clean hard-surface, game texture.

### 7. Canyon signs (4 images, `canyon-sign-01..04.png`, 1024 x 512)

> A weathered roadside sign panel for a desert highway, filling the frame, painted metal with rust
> streaks, amber lamps (#FFA33B) along the top edge, one invented word in a bold stencil face such
> as "RELAY 7", "OUTLANDS", "MESA GATE". Palette limited to amber, cream (#FFE6B3), sand (#B08050)
> and rust; no cyan, no magenta, no green. Even daylight, no glow. Style: stylised realism, clean
> hard-surface, game texture.

## The Grid

### 8. Arena bowl backdrop (1 image, `grid-bowl.png`, 4096 x 1024, edges wrap)

> A wide panoramic view of the inside of a vast dark stadium bowl at night, seen from the floor:
> tiers of seating rising in the bottom 65 percent of the frame, the top 35 percent fully
> transparent (alpha), not a drawn sky. Everything is deep blue-black (#0F2140 to #183358) with
> thin cyan edge lights (#59D9FF) outlining each tier, a few cyan pylons, no other colour. No
> crowd, no text, no ground, no lens flare. Flat, even lighting; the tiers get darker toward the
> top. The left edge must continue seamlessly into the right edge. Style: Tron-like, clean
> hard-surface, game texture.

### 9. Crowd strip (2 images, `grid-crowd-01.png`, `-02.png`, 2048 x 256, tiles horizontally, transparent background)

> A long horizontal row of a stadium crowd seen straight on from a distance, dark silhouettes of
> standing spectators against a fully transparent background (alpha), many holding glowing sticks
> in cyan (#59D9FF) and white, a few in orange (#FF7A1A). Figures only in the bottom 90 percent,
> no seats, no floor, no faces in detail, no text. The left edge continues seamlessly into the
> right edge. Even lighting, no glow halos. Style: Tron-like, clean, game texture.

### 10. Jumbotron content (4 images, `grid-screen-01..04.png`, 1024 x 512)

> A stadium video-screen graphic, filling the frame, dark blue background (#0B1A33) with a cyan
> (#59D9FF) wireframe grid and one bold invented word or number such as "ROUND 2", "DEREZ", "GRID",
> "3 - 1", in a squared-off display face, white with a cyan glow. No photographs, no cyan
> gradients bleeding to the edges, no other colour. Style: Tron-like, clean, game texture.


### 11. Arena wall module (`grid-wall-01.png`, 1024 x 1024 PNG; refreshed 3 Oct 2026)

Delivery rules for all three Grid tiles: PNG at the stated size, **the image only** (no caption, no title text,
no border or padding; the game crops nothing), flat even lighting, no bloom or glow halos painted in (the post
pass adds them), no perspective. The first panels worked at 600 px; these are the full-size versions.

Reference: Mark's delivered module (`Captures/polish/p17/`), which composes well: a buttress at each side edge
so the tile repeats horizontally into a colonnade, one module per 16 m of wall.

> A straight-on, flat elevation of one modular futuristic arena wall segment, filling the whole square
> frame edge to edge: a heavy dark structural shell in blue-black composite (#0B1A2E to #16304A) with a
> brushed surface and faint seams, a projecting buttress column at the LEFT edge and at the RIGHT edge
> (each exactly half a column, so two tiles side by side form one full column), a recessed central panel
> with a bevelled border and three sub-panels, a thick upper cap with a recessed horizontal light channel
> glowing deep teal-green (#29DBC7) along the top, a projecting lower plinth with a thinner teal channel
> along the bottom, one thin vertical teal channel inside each buttress, one thin horizontal teal trim line
> at about 40 percent of the height. The left edge continues seamlessly into the right edge. No floor, no
> sky, no text, even lighting, no glow halos. Style: Tron-like, clean hard-surface, game texture.

Optional second file `grid-wall-01-mask.png`: the same image with every lit channel pure white and everything
else pure black. Without it the game derives the mask from the teal.

### 12. Arena floor plate (`grid-floor-01.png`, 1024 x 1024 PNG, tiles on all four edges)

> A straight-down, flat view of a dark polished architectural composite floor filling the whole square frame,
> seamlessly tileable on all four edges: very dark blue-black (#0A1626 to #10243A), divided into four equal
> square plates by thin dark bevelled seams that meet in a small cross at the centre and run to the middle
> of each edge, each plate with subtle flaked or crazed surface texture, faint lighter worn patches and a few
> hairline scratches, a brushed grain. NO grid lines, NO teal or cyan, NO painted reflections or highlights,
> no text, flat even lighting. Style: clean hard-surface, game texture.

Also `grid-floor-01-rough.png`: a greyscale roughness map of the same tile, white where matte (seams, scratches,
worn patches), near-black where polished, mid-grey on the flaked areas.

### 13. Arena skyline strip with the spire (`grid-skyline.png`, 4096 x 1024 PNG, edges wrap)

> A wide panoramic skyline of a dark futuristic city at night from ground level, filling the frame width:
> tower silhouettes in deep blue-black (#0A1C38) with thin vertical teal-green (#29DBC7) light strips and a
> few teal beams rising into the sky; one dominant central spire about twice the height of the rest with a
> thin glowing halo ring around it at two thirds of its height. The sky above the towers is PURE BLACK
> (#000000). The bottom edge of the image is the towers' base line: NO water, NO ground, NO reflections below
> the city. No clouds, no text, no lens flare, even lighting. The left edge continues seamlessly into the
> right edge. Style: Tron-like, clean hard-surface, game texture.

Palette note (3 Oct 2026): the Grid's default accent moved from sky cyan (#47D1FF) to a deeper teal-green
(#29DBC7, `Theme.gridAccent`). The game recolours the emissive channels to the current palette, so the exact
teal in the images matters less than keeping the lit parts saturated and the structure neutral blue-black.

## What the code does with each

| Asset | Where it lands |
|---|---|
| Facade tiles | `ProceduralTextures.facade` replaced by an atlas; emissive mask derived from luminance above 0.55 |
| Billboards, storefronts, canyon signs | the mega-signs and storefront quads in `WorldScroller` (dressings) |
| Skyline and ridge strips | three parallax cylinders behind the two skyline rings, scrolled at 0.22 / 0.12 / 0.05 of travel |
| Rock tiles | the canyon wall and undercity materials |
| Bowl, crowd, screens | `ArenaWorld`: a backdrop cylinder, crowd cards on the tiers with a UV wobble, the screens on the pylons |

Budget: about 64 MB of textures per world at these sizes, which keeps 60 fps on the iPhone 12.
