# Responsive Design Standards

```
POLICY: Responsive Design Standards
Version: 1.0

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. MOBILE-FIRST ALWAYS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Base styles = mobile. Breakpoints override for larger screens.

BAD (desktop-first):
  .grid { display: grid; grid-template-columns: repeat(3, 1fr); }
  @media (max-width: 768px) { .grid { grid-template-columns: 1fr; } }

GOOD (mobile-first with Tailwind):
  <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">

Standard breakpoint usage:
  default   (0px+):    Single column, stacked layout
  sm        (640px+):  2-column grids, side-by-side elements
  md        (768px+):  Sidebar appears, more density allowed
  lg        (1024px+): Full desktop layout
  xl        (1280px+): Wider content max-width, larger typography

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

2. NO HORIZONTAL SCROLL
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Any element that causes horizontal overflow on viewport < 380px is a bug.

Rules:
  - Never use fixed pixel widths wider than the viewport on any layout element
  - Long code blocks: overflow-x: auto, never overflow-x: visible
  - Tables: wrap in overflow-x: auto container on mobile
  - Flex rows that would overflow: use flex-wrap
  - Images: max-width: 100% on all inline images

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

3. TOUCH TARGET SIZING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Minimum interactive touch target: 44x44px (WCAG 2.5.5).

BAD: A 16x16 close icon with no padding — 1% of users will be able to tap it accurately.
GOOD:
  <button className="p-2.5 rounded-lg" aria-label="Close">
    <X className="size-4" />
  </button>
  // p-2.5 adds 10px padding on each side → touch area is 36px+

For dense UIs (tables, toolbars): minimum 32px with at least 8px spacing between targets.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

4. TYPOGRAPHY SCALING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Never use font sizes below 13px for body text on any screen.
Scale headings down proportionally on mobile:

  /* In :root */
  --text-hero: clamp(28px, 5vw, 48px);     /* Hero heading */
  --text-page: clamp(20px, 3vw, 30px);     /* Page heading */
  --text-section: clamp(16px, 2vw, 22px);  /* Section heading */

Line length: keep body text between 60-80 characters per line.
Use max-width on prose containers: max-w-prose (65ch) or max-w-2xl.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

5. CONTENT HIERARCHY ON SMALL SCREENS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
The most important content must be visible without scrolling on mobile.
Navigation, filters, and secondary actions move to:
  - Bottom sheet / drawer (mobile)
  - Off-canvas sidebar (mobile)
  - Collapsible sections (mobile)

Never show the full desktop sidebar collapsed on mobile — hide it and
provide a hamburger or bottom nav pattern instead.
```
