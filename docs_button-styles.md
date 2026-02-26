# Standardized Button Styles

This document outlines the standardized button styles used across the Tax Form Hub application to ensure consistency and support for Dark Mode.

## Core Principles
- **Font Weight**: All buttons use `regular` (400) weight for a cleaner, modern look.
- **Border Radius**: A uniform `6px` radius is applied to all buttons.
- **Theme Awareness**: Secondary and Back buttons use CSS variables to automatically adjust their colors in Dark Mode.
- **Contrast**: Primary and Success buttons always use white text for maximum contrast against colored backgrounds.

## Button Variants

### 1. Primary Button (`.btn-primary`)
Used for main actions like "Create Invoice", "Save Changes", and "Log in".
- **Background**: `#00aeff` (Light Blue)
- **Text Color**: `#ffffff` (White)
- **Hover**: `#20b9ff`

### 2. Success/Send Button (`.btn-success`)
Used for sending documents or finalizing processes.
- **Background**: `#0077ff` (Standard Blue)
- **Text Color**: `#ffffff` (White)
- **Hover**: `#0087e6`

### 3. Back / Light Button (`.btn-back`, `.btn-light`)
Used for navigation back and secondary "cancel" type actions.
- **Background**: `var(--bg-secondary)` (White in Light Mode, Dark Grey in Dark Mode)
- **Border**: `1px solid var(--border-color)`
- **Text Color**: `var(--text-main)` (Black in Light Mode, White in Dark Mode)

### 4. Secondary Button (`.btn-secondary`)
Used for generic secondary actions.
- **Background**: `#6c757d` (Grey)
- **Text Color**: `#ffffff` (White)

### 5. Outline Variants (`.btn-outline-primary`, `.btn-outline-secondary`)
Used for less prominent actions or secondary filters.
- **Border**: Matches the variant color.
- **Text**: Matches the variant color.
- **Hover**: Background fills with variant color, text turns white (or main text color for secondary).

## Implementation Checklist
- [x] Font color of Login/Signup/Reset buttons changed from black to white.
- [x] Font weight changed to regular (400) for all buttons.
- [x] All "Back" buttons standardized to `.btn-back` style.
- [x] All buttons use theme-aware variables where applicable.
