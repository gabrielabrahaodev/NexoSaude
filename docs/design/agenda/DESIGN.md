---
name: Clinical Precision Dark
colors:
  surface: '#10141a'
  surface-dim: '#10141a'
  surface-bright: '#353940'
  surface-container-lowest: '#0a0e14'
  surface-container-low: '#181c22'
  surface-container: '#1c2026'
  surface-container-high: '#262a31'
  surface-container-highest: '#31353c'
  on-surface: '#dfe2eb'
  on-surface-variant: '#c2c6d6'
  inverse-surface: '#dfe2eb'
  inverse-on-surface: '#2d3137'
  outline: '#8c909f'
  outline-variant: '#424754'
  surface-tint: '#adc6ff'
  primary: '#adc6ff'
  on-primary: '#002e6a'
  primary-container: '#4d8eff'
  on-primary-container: '#00285d'
  inverse-primary: '#005ac2'
  secondary: '#43e1ba'
  on-secondary: '#00382c'
  secondary-container: '#02c49f'
  on-secondary-container: '#004b3b'
  tertiary: '#4edea3'
  on-tertiary: '#003824'
  tertiary-container: '#00a572'
  on-tertiary-container: '#00311f'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#d8e2ff'
  primary-fixed-dim: '#adc6ff'
  on-primary-fixed: '#001a42'
  on-primary-fixed-variant: '#004395'
  secondary-fixed: '#63fbd3'
  secondary-fixed-dim: '#3fdeb7'
  on-secondary-fixed: '#002018'
  on-secondary-fixed-variant: '#005140'
  tertiary-fixed: '#6ffbbe'
  tertiary-fixed-dim: '#4edea3'
  on-tertiary-fixed: '#002113'
  on-tertiary-fixed-variant: '#005236'
  background: '#10141a'
  on-background: '#dfe2eb'
  surface-variant: '#31353c'
typography:
  headline-xl:
    fontFamily: Plus Jakarta Sans
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 22px
    fontWeight: '700'
    lineHeight: 28px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 22px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 11px
    fontWeight: '700'
    lineHeight: 14px
    letterSpacing: 0.04em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style
The design system establishes a high-performance clinical environment optimized for handheld, one-handed mobile interactions. Departing from sterile medical whites, the experience translates existing dark-mode web dashboards into a focused native Android/Flutter layout. 

The aesthetic is Modern Clinical Minimalist with Tonal Depth: deep navy bases, sharp architectural structures, and bio-luminescent accents. Medical interactions often evoke anxiety; the deep slate backdrop reduces visual fatigue, while precise cyan-green and cobalt accents deliver immediate cognitive orientation for critical health data (appointment statuses, vitals, time slots, and clinical records). Every interactive touchpoint features deliberate haptic ergonomics with minimum tap boundaries of 48×48dp.

## Colors
The system relies on high-contrast luminescent tokens over a multi-tiered navy/slate stack to maintain strict WCAG AAA legibility in mobile operating conditions:

- **Canvas & Backgrounds:**
  - `surface-canvas`: `#0d1117` (Global app background, system navigation bar, and status bar blend)
  - `surface-card`: `#161b22` (Primary card containers, bottom navigation shell, sheet dialogs)
  - `surface-elevated`: `#1f2937` (Active states, elevated sheets, input fields, pressed layers)
  - `surface-border`: `#30363d` (Low-contrast dividers and card structural strokes)

- **Accents & Roles:**
  - `primary`: `#3b82f6` (System anchors, selected navigation items, primary booking CTA buttons)
  - `primary-active`: `#2563eb` (Button pressed state, highlighted calendar track)
  - `secondary` / `management`: `#00c49f` (Clinical management actions, confirmed status, telemetry metrics)
  - `success` / `verified`: `#10b981` (Completed appointments, active doctor presence indicators)
  - `warning`: `#f59e0b` (Pending approval, payment required)
  - `danger`: `#ef4444` (Cancellations, urgent medical triage alerts)

- **Typography & Icons:**
  - `text-primary`: `#f0f6fc` (Titles, patient names, dates, key inputs)
  - `text-secondary`: `#8b949e` (Clinical specialties, metadata, helper text, inactive tabs)
  - `text-tertiary`: `#6e7681` (Disabled labels, timestamps, border accents)

## Typography
Plus Jakarta Sans provides high clarity at compact mobile screen densities. Its geometric humanist curves keep numerical medical displays, scheduled hours, and clinical descriptions sharp while remaining friendly and approachable to patients.

- **Headlines (`headline-xl`, `headline-lg`):** Reserved for screen headers, greeting panels ("Olá, Dr. Silva"), and modal titles.
- **Card Titles & Section Markers (`headline-md`, `headline-sm`):** Doctor profiles, clinic names, and date group separators.
- **Body (`body-lg`, `body-md`, `body-sm`):** Medical instructions, diagnosis notes, and patient details.
- **Labels (`label-lg`, `label-md`, `label-sm`):** Appointment status badges, buttons, bottom tab indicators, and horizontal calendar day markers.

## Layout & Spacing
Designed around a strict 4dp/8dp base unit specifically structured for mobile viewport boundaries (360dp to 428dp standard phone widths).

- **Screen Margins:** Fixed `1rem` (16dp) lateral gutters protect touch targets from bezel edges and curved Android displays.
- **Safe Area Insets:** System Status Bar padding is explicitly handled via Flutter/Android `SafeArea` (`top` buffer: 44dp default, `bottom` buffer: 34dp for gesture pills).
- **One-Thumb Zone Navigation:** Primary interactive flows (scheduling actions, tab switching, date picking) remain anchored within the bottom 60% of the display.
- **Vertical Rhythm:** Content cards stack with `space-md` (16dp) gaps. Compact sub-elements within cards (e.g., doctor specialty icon + badge) use `space-xs` (4dp) to `space-sm` (8dp).

## Elevation & Depth
Depth is created through chromatic surface stacking and low-contrast borders rather than high-contrast drop shadows, maintaining fidelity on mobile OLED panels without muddiness.

- **Level 0 (Background):** Pure `#0d1117`. Flat canvas for scrollable content.
- **Level 1 (Surface Cards & Lists):** Layered at `#161b22` bounded by a 1dp crisp stroke of `#30363d` (40% opacity). Soft ambient glow: `box-shadow: 0 4px 12px rgba(0, 0, 0, 0.45)`.
- **Level 2 (Interactive Floating Modules & Weekly Calendar):** `#1f2937` with accent-tinted borders when active (e.g., selected date uses 1dp border `#00c49f`).
- **Level 3 (Bottom Navigation & Modals / Bottom Sheets):** `#161b22` with top boundary border `#30363d`, backdrop blur (`filter: blur(16px)` with 85% opacity fallback), and `box-shadow: 0 -8px 24px rgba(0, 0, 0, 0.6)`.

## Shapes
The mobile interface leverages consistent squircle-inspired corner geometry (Rounded, 8dp-16dp) to preserve modern mobile ergonomics:

- **Cards & Consultation Blocks:** 16dp (`rounded-lg`) corner radius for tactile distinction.
- **Calendar Day Tiles:** 12dp corner radius for structured horizontal date scrollers.
- **Buttons & Search Inputs:** 12dp corner radius for ergonomic thumb interaction.
- **Badges, Status Chips & Pills:** 9999dp (Fully rounded pill shape) to contrast sharply with square content grids.
- **Bottom Sheet Modals:** 24dp top-left and top-right radii; 0dp bottom.

## Components

### Bottom Navigation Bar (App Shell)
- Height: 64dp + safe area bottom inset.
- Background: Surface `#161b22` with a 1dp top border `#30363d`.
- Active Item: Filled icon with `#3b82f6` color, accompanied by a small glowing dot or label using `label-sm`.
- Inactive Item: Outline icon with `#8b949e`.
- Center Floating Action (Novo Agendamento / Gestão): Integrated elevated circular pill with gradient fill (`#2563eb` to `#00c49f`) and 4dp elevation.

### Horizontal Weekly Calendar Strip
- Horizontal swipeable list of 7-day windows.
- Inactive Day Tile: 52dp width, 72dp height, surface `#161b22`, border `#30363d`. Contains abbreviated day label (`label-sm`, `#8b949e`) and day number (`headline-sm`, `#f0f6fc`).
- Active Day Tile: Filled with `#3b82f6` or outlined with `#00c49f` (1.5dp), white text, and a glowing indicator dot at the bottom base indicating scheduled appointments.

### Consultation & Appointment Cards
- Background `#161b22` with a left-accent indicator stripe:
  - 4dp vertical left border in `#00c49f` for "Confirmado", `#3b82f6` for "Em Andamento", and `#f59e0b` for "Aguardando".
- Layout: Top row includes patient/doctor avatar (40dp rounded-lg), full name (`headline-sm`), and time badge (`label-md`). 
- Bottom row: Specialty tag chip, dental/medical icon, and direct call-to-action ("Prontuário", "Check-in", or "Reagendar").

### Gestão Action Button
- Distinct dual-purpose component for clinic admins/doctors.
- Styled using the characteristic `#00c49f` (teal/emerald) background with dark typography (`#0d1117`), or outline style with `#00c49f` text and a subtle emerald backlight glow (`rgba(0, 196, 159, 0.15)`).

### Input Fields & Search Bars
- Background `#1f2937` with border `#30363d`.
- Height: 48dp minimum for thumb targets.
- Text: `#f0f6fc` with `#8b949e` placeholder.
- Focus State: Border transitions to `#3b82f6` with a 2dp cyan shadow pulse.

### Status Chips & Badges
- Height: 24dp to 28dp, pill-shaped.
- "Confirmado": `#00c49f` background at 15% opacity with solid `#00c49f` text.
- "Pendente": `#f59e0b` background at 15% opacity with solid `#f59e0b` text.
- "Cancelado": `#ef4444` background at 15% opacity with solid `#ef4444` text.