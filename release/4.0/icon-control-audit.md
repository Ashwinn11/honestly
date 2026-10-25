# Icon control consistency

Standardized navigation and modal actions on IconTileButton: 38-point rounded-square visual, 11-point radius, 2-point ink outline and cream fill. Back/forward icons use a 15-point bold symbol; close uses 13 points for optical balance. The shared label supplies at least a 44-point hit area. The larger onboarding back control retains its CTA-height size within the same component family.

Removed the circular back/close component. Updated the affirmation reader and library, legal documents, paywall, calendar arrows, reader paging arrows, mood sheet, sticker sheet and theme sheet. Removed fixed-size wrappers around journal header controls so their scaling follows the shared component.

Consolidated compact text-format, list, alignment, media and drawing tool visuals into CompactIconFace / compactControl. These share a 36-point visual, 10-point radius, 14-point bold glyph, soft inactive outline, amber active state and standard press feedback, with at least a 44-point target. UIKit attachment controls reuse the same metrics and palette.

Color swatches, mood choices, language pills, inline tag removal, disclosure chevrons, menu ellipses and text/row actions keep their purpose-specific treatments. Navigation arrows use semantic forward/backward symbols for right-to-left layouts.

Validation: source audit found no remaining SoftCircleButton references or 34/44-point navigation-tile variants; signed physical-device build passed. No simulator was used. Full interactive visual review remains on the connected phone.
