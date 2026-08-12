NyxD Mobile Asset Pack

All assets are derived from one master mark for consistent geometry.

FILES
- app-icon-master-1024.png — square source asset; no rounded corners/border.
- android-adaptive-foreground-1024.png — transparent foreground layer with safe margin.
- android-adaptive-background-1024.png — solid near-black background layer.
- brand-mark-metallic-1024.png — transparent metallic mark.
- brand-mark-monochrome-1024.png — transparent flat mark.
- android-notification-icon-512.png — white transparent notification mark.
- splash-mark-1024.png — compact transparent mark for launch screen.
- splash-reference-1440x3200.png — visual reference for a minimal launch screen.
- app-icon-{48,72,96,144,192,512}.png — raster exports.

NOTES
Android should apply launcher masking/rounding itself. Do not bake a squircle,
stroke, drop shadow, or outer border into the adaptive layers.
