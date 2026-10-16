# Dots sprite production

Generated with the built-in ImageGen tool using the user-supplied Usagi references. No API-key fallback was used.

## Initial atlas prompt

Use case: stylized-concept. Asset type: production 2D desktop pet sprite atlas.
Create one transparent square image, preferably 2048x2048, containing EXACTLY 8 columns and 8 rows, 64 equal cells, one complete Usagi character per cell. Invisible grid, no labels, no lines, no text, no shadows, no backgrounds. Every character centered in its own cell with generous empty padding. No touching cells or clipped ears.
Reference image 1 is the character identity/model/style reference: precisely preserve Usagi from Chiikawa, rounded cream-yellow body, long pink-lined ears, small glossy black eyes, tiny characteristic mouth, pink cheeks with three little marks, very short limbs, dark brown rounded outlines, clean flat 2D illustration. Reference image 2 is ONLY costume reference for rap/spin rows: dark sunglasses and gold chain. Keep all cells stylistically identical. No weapons or microphones.
Rows top to bottom, frames left to right:
ROW 1: eight distinct idle/care poses without accessories: neutral front; subtle breath; eyes closed blink; head tilt left; head tilt right; satisfied squint; arms raised peace gesture; surprised ears upright.
ROW 2: eight successive running-right cycle frames without accessories. Consistent side/three-quarter facing right, tiny limbs with alternating foot contact, lean forward, ears lagging, in-place cycle, identical character size.
ROW 3: eight rap poses WITH sunglasses and gold chain: anticipation crouch; upright confident; left step; right step; left hand forward; right hand forward; both hands beside face; triumphant peace gesture.
ROW 4: eight successive full-body turn poses WITH sunglasses and chain: front; front-right three-quarter; right profile; rear-right three-quarter; back with fluffy short tail; rear-left three-quarter; left profile; front-left three-quarter. Keep feet on same baseline.
ROW 5: eight KEYFRAMES of exuberant tumbling spin WITH sunglasses and chain, actual articulated changing viewpoints not rotated copies: lean left; side-facing with ears pointing diagonally left; tilted rear with tail visible and ears pointing left; inverted rear view; inverted front view; side view tilted right; front-right recovering upright; proud upright landing. Keep entire rotated body inside each cell and preserve scale.
ROW 6: eight care/drag poses WITHOUT accessories: smiling eyes closed; happy squint ears soft; head nuzzle left; head nuzzle right; lifted body compact feet raised; lifted feet paddling left; lifted feet paddling right; lifted startled face.
ROW 7: eight rest/wake poses WITHOUT accessories: low crouch; lying flat on belly eyes open; lying flat eyes half closed; lying flat eyes shut; sleeping ears soft; eyes open ears perk; rising halfway; standing alert.
ROW 8: eight stop/landing poses WITHOUT accessories: run slows facing right; leaning forward to stop; recovery step; neutral settled; landing compressed; rebound stretch; settle; front-facing proud smile.
Output only the actual transparent sprite atlas, not a preview/mockup. Every sprite has opaque solid cream body and genuine alpha transparency outside. All 64 complete bodies isolated. High consistency and simple clean silhouette readable at 144px display.

## Edge cleanup prompt

Edit this production sprite atlas. Preserve EXACTLY its 8 columns by 8 rows, all 64 character poses, character identity, costume per row, placement, scale, and clean flat colors. Change ONLY the edge/background cleanliness: remove every red, yellow, black, gray or colored speckle/noise/halo outside the characters. Remove all drawn motion scribbles around the characters. The exterior must be perfectly clean transparent alpha, not black or white background. Keep the cream body, pink ears/cheeks, dark brown outline, sunglasses and gold chain intact and opaque. Sharpen the solid smooth dark outline without fuzzy border artifacts. No text or grid. Deliver a clean production-ready transparent sprite sheet.

## Packaging

64 generated key poses are aligned to a common pivot and packed as 160 playback cells. Timing repeats are intentional; the left-running cycle mirrors the right-running cycle. The rap uses multiple distinct front, side and rear poses. The spin uses its own articulated front/rear/inverted poses. This is a reference-inspired adaptation, not a frame-exact extraction of the film.
