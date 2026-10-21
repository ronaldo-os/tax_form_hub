// ==========================================================================
// Avatar Cropper
// --------------------------------------------------------------------------
// Reusable crop / reposition / zoom modal shared by Edit Profile (user avatar)
// and Company Profile (company logo).
//
// Flow:
//   1. User picks a file in an <input type="file" data-avatar-cropper>.
//   2. The page's `change` handler calls `handleAvatarSelection(input, opts)`.
//   3. The input is immediately reverted to its last *applied* state, the file
//      is validated, decoded (EXIF orientation applied) and the modal opens.
//   4. Cancel  -> nothing changes (current avatar / previous crop is kept).
//      Apply   -> a square JPEG/PNG is rendered from the crop region and put
//                 back into the file input, so the existing form "Save Changes"
//                 submit uploads the cropped image. Nothing is persisted until
//                 the form is saved.
//
// Security notes:
//   * DOM is built exclusively with createElement/textContent (no innerHTML).
//   * Images are decoded locally from object URLs; nothing is fetched remotely.
//   * SVG is rejected (can carry active content). Server-side validation lives
//     in app/models/concerns/profile_image_validatable.rb.
// ==========================================================================

export const AVATAR_ALLOWED_TYPES = Object.freeze([
  'image/jpeg', 'image/jpg', 'image/pjpeg', 'image/png', 'image/gif',
  'image/webp', 'image/bmp', 'image/avif', 'image/heic', 'image/heif'
]);
const AVATAR_ALLOWED_EXTENSIONS = Object.freeze([
  'jpg', 'jpeg', 'jfif', 'pjpeg', 'png', 'gif', 'webp', 'bmp', 'avif', 'heic', 'heif'
]);
// Source photos straight from phones can be large; the cropped output is far smaller.
export const AVATAR_MAX_SOURCE_BYTES = 15 * 1024 * 1024;
const AVATAR_MAX_SOURCE_PIXELS = 100 * 1000 * 1000; // guard against decompression bombs
const OUTPUT_MAX_SIZE = 1024;      // final avatar is at most 1024 x 1024 px
const PREVIEW_MAX_DIMENSION = 2048; // working copy used for on-screen rendering
const MAX_INTERMEDIATE_SIZE = 4096; // stay below iOS canvas area limits
const JPEG_QUALITY = 0.92;
const TYPES_WITH_ALPHA = ['image/png', 'image/gif', 'image/webp', 'image/avif'];

const committedFiles = new WeakMap();
const committedPreviewUrls = new WeakMap();
let activeModal = null;

// --------------------------------------------------------------------------
// Public helpers
// --------------------------------------------------------------------------

/**
 * Validates a selected file before the cropper opens.
 * @returns {string|null} user-facing error message, or null when valid.
 */
export function validateAvatarFile(file) {
  if (!file) return 'No file was selected.';

  const type = (file.type || '').toLowerCase();
  const name = (file.name || '').toLowerCase();
  const ext = name.includes('.') ? name.split('.').pop() : '';

  if (type === 'image/svg+xml' || ext === 'svg' || ext === 'svgz') {
    return 'SVG images are not supported. Please choose a JPG, PNG, GIF, or WebP image.';
  }

  // Some mobile browsers report an empty MIME type, fall back to the extension.
  const typeAllowed = type ? AVATAR_ALLOWED_TYPES.includes(type) : AVATAR_ALLOWED_EXTENSIONS.includes(ext);
  if (!typeAllowed) {
    return 'Unsupported file type. Please choose a JPG, PNG, GIF, or WebP image.';
  }

  if (!file.size) {
    return 'The selected file is empty. Please choose another image.';
  }

  if (file.size > AVATAR_MAX_SOURCE_BYTES) {
    const sizeMb = (file.size / (1024 * 1024)).toFixed(1);
    const maxMb = Math.round(AVATAR_MAX_SOURCE_BYTES / (1024 * 1024));
    return `This image is too large (${sizeMb} MB). The maximum size is ${maxMb} MB.`;
  }

  return null;
}

/**
 * Handles a `change` event on an avatar file input: validates, opens the crop
 * modal and, on Apply, swaps the input's file for the cropped result.
 *
 * @param {HTMLInputElement} input
 * @param {Object} options
 * @param {string} [options.title]
 * @param {string} [options.subtitle]
 * @param {string} [options.applyLabel]
 * @param {(file: File, previewUrl: string) => void} [options.onApply]
 * @param {(message: string) => void} [options.onError]
 * @param {() => void} [options.onCancel]
 * @returns {Promise<File|null>}
 */
export async function handleAvatarSelection(input, options = {}) {
  const { onApply, onError, onCancel } = options;
  if (!input) return null;

  const file = input.files && input.files[0];
  const committed = committedFiles.get(input) || null;

  // Some browsers clear the selection (and fire change) when the picker is dismissed.
  if (!file) {
    restoreInput(input, committed);
    return null;
  }

  // Legacy browsers that cannot assign files programmatically: keep the
  // original upload behaviour (no crop) rather than breaking the form.
  if (!supportsFileAssignment()) {
    const legacyError = validateAvatarFile(file);
    if (legacyError) {
      input.value = '';
      if (onError) onError(legacyError);
      return null;
    }
    const legacyUrl = URL.createObjectURL(file);
    swapPreviewUrl(input, legacyUrl);
    if (onApply) onApply(file, legacyUrl);
    return file;
  }

  // Revert the input to the last applied state; it is only replaced on Apply.
  restoreInput(input, committed);

  const validationError = validateAvatarFile(file);
  if (validationError) {
    if (onError) onError(validationError);
    return null;
  }

  if (activeModal) return null;

  let source;
  try {
    source = await decodeImage(file);
  } catch (e) {
    if (onError) onError('We couldn\u2019t read this image. It may be corrupted or in an unsupported format \u2014 please try a JPG or PNG.');
    return null;
  }

  const { width, height } = getSourceSize(source);
  if (!width || !height) {
    releaseSource(source);
    if (onError) onError('We couldn\u2019t read this image. Please try another file.');
    return null;
  }
  if (width * height > AVATAR_MAX_SOURCE_PIXELS) {
    releaseSource(source);
    if (onError) onError('This image\u2019s dimensions are too large. Please choose a smaller image.');
    return null;
  }

  const modal = new AvatarCropModal({
    source,
    file,
    title: options.title || 'Adjust Photo',
    subtitle: options.subtitle || 'Drag to reposition. Scroll, pinch, or use the slider to zoom.',
    applyLabel: options.applyLabel || 'Apply'
  });

  const result = await modal.open();

  if (!result) {
    if (onCancel) onCancel();
    return null;
  }

  if (!setInputFile(input, result.file)) {
    restoreInput(input, committed);
    URL.revokeObjectURL(result.previewUrl);
    if (onError) onError('Your browser couldn\u2019t attach the cropped image. Please try again.');
    return null;
  }

  committedFiles.set(input, result.file);
  swapPreviewUrl(input, result.previewUrl);
  if (onApply) onApply(result.file, result.previewUrl);
  return result.file;
}

/**
 * Clears any applied crop for the input (used when discarding form changes).
 */
export function clearAvatarSelection(input) {
  if (!input) return;
  committedFiles.delete(input);
  const url = committedPreviewUrls.get(input);
  if (url) {
    // Defer so an <img> currently displaying it can switch source first.
    setTimeout(() => URL.revokeObjectURL(url), 0);
    committedPreviewUrls.delete(input);
  }
  try { input.value = ''; } catch (e) { /* ignore */ }
}

// --------------------------------------------------------------------------
// File input helpers
// --------------------------------------------------------------------------

function supportsFileAssignment() {
  try {
    if (typeof DataTransfer !== 'function' || typeof File !== 'function') return false;
    const dt = new DataTransfer();
    return !!(dt && dt.items && typeof dt.items.add === 'function');
  } catch (e) {
    return false;
  }
}

function setInputFile(input, file) {
  try {
    const dt = new DataTransfer();
    dt.items.add(file);
    input.files = dt.files;
    return !!(input.files && input.files.length === 1 && input.files[0] === file);
  } catch (e) {
    return false;
  }
}

function restoreInput(input, committedFile) {
  if (committedFile && setInputFile(input, committedFile)) return;
  try { input.value = ''; } catch (e) { /* ignore */ }
}

function swapPreviewUrl(input, url) {
  const previous = committedPreviewUrls.get(input);
  committedPreviewUrls.set(input, url);
  if (previous && previous !== url) {
    setTimeout(() => URL.revokeObjectURL(previous), 0);
  }
}

// If an avatar input was cleared externally (form reset, Turbo cache restore,
// discard changes...), forget the applied crop so Cancel never resurrects it.
if (typeof window !== 'undefined' && !window.__avatarCropperClickGuard) {
  window.__avatarCropperClickGuard = true;
  document.addEventListener('click', (event) => {
    const target = event.target;
    if (target instanceof HTMLInputElement && target.type === 'file' && target.hasAttribute('data-avatar-cropper')) {
      if (!target.files || target.files.length === 0) {
        committedFiles.delete(target);
      }
    }
  }, true);

  const closeActiveModal = () => { if (activeModal) activeModal.close(null); };
  document.addEventListener('turbo:before-cache', closeActiveModal);
  document.addEventListener('turbo:before-visit', closeActiveModal);
}

// --------------------------------------------------------------------------
// Image decoding (EXIF orientation aware)
// --------------------------------------------------------------------------

async function decodeImage(file) {
  if (typeof createImageBitmap === 'function') {
    // 'from-image' applies EXIF orientation so photos from phones appear upright.
    try { return await createImageBitmap(file, { imageOrientation: 'from-image' }); } catch (e) { /* fall through */ }
    try { return await createImageBitmap(file); } catch (e) { /* fall through */ }
  }
  // Modern browsers also apply EXIF orientation to <img> (image-orientation: from-image).
  return loadViaImageElement(file);
}

function loadViaImageElement(file) {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.decoding = 'async';
    img.onload = () => {
      URL.revokeObjectURL(url);
      resolve(img);
    };
    img.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error('Image decode failed'));
    };
    img.src = url;
  });
}

function getSourceSize(source) {
  if (!source) return { width: 0, height: 0 };
  const width = source.naturalWidth || source.width || 0;
  const height = source.naturalHeight || source.height || 0;
  return { width, height };
}

function releaseSource(source) {
  if (source && typeof source.close === 'function') {
    try { source.close(); } catch (e) { /* ignore */ }
  }
}

function createCanvas(width, height) {
  const canvas = document.createElement('canvas');
  canvas.width = Math.max(1, Math.round(width));
  canvas.height = Math.max(1, Math.round(height));
  return canvas;
}

function getSmoothContext(canvas) {
  const ctx = canvas.getContext('2d');
  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = 'high';
  return ctx;
}

function releaseCanvas(canvas) {
  if (canvas && canvas.tagName === 'CANVAS') {
    canvas.width = 0;
    canvas.height = 0;
  }
}

function canvasToBlob(canvas, type, quality) {
  return new Promise((resolve) => {
    if (typeof canvas.toBlob === 'function') {
      canvas.toBlob((blob) => resolve(blob), type, quality);
    } else {
      resolve(null);
    }
  });
}

function buildOutputFileName(originalName, mimeType) {
  const ext = mimeType === 'image/png' ? 'png' : 'jpg';
  const base = String(originalName || 'avatar')
    .replace(/\.[^.]*$/, '')
    .replace(/[^\w\-]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 60) || 'avatar';
  return `${base}-cropped.${ext}`;
}

// --------------------------------------------------------------------------
// DOM helpers
// --------------------------------------------------------------------------

function el(tag, attrs = {}, children = []) {
  const node = document.createElement(tag);
  Object.keys(attrs).forEach((key) => {
    const value = attrs[key];
    if (value === undefined || value === null || value === false) return;
    if (key === 'className') node.className = value;
    else if (key === 'text') node.textContent = value;
    else node.setAttribute(key, value === true ? '' : String(value));
  });
  children.forEach((child) => { if (child) node.appendChild(child); });
  return node;
}

function icon(classes) {
  return el('i', { className: classes, 'aria-hidden': 'true' });
}

let modalIdCounter = 0;

// --------------------------------------------------------------------------
// Crop modal
// --------------------------------------------------------------------------

class AvatarCropModal {
  constructor({ source, file, title, subtitle, applyLabel }) {
    this.source = source;
    this.file = file;
    this.title = title;
    this.subtitle = subtitle;
    this.applyLabel = applyLabel;

    const { width, height } = getSourceSize(source);
    this.W = width;
    this.H = height;

    this.outputType = TYPES_WITH_ALPHA.includes((file.type || '').toLowerCase()) ? 'image/png' : 'image/jpeg';

    // Allow zooming until roughly 48 source pixels fill the crop circle (max 8x).
    this.maxZoom = Math.max(1, Math.min(8, Math.min(width, height) / 48));
    this.zoom = 1;
    this.tx = 0; // image centre offset from crop centre, CSS px
    this.ty = 0;
    this.D = 0;  // crop circle diameter, CSS px
    this.stageW = 0;
    this.stageH = 0;
    this.dpr = Math.max(1, Math.min(3, window.devicePixelRatio || 1));

    this.pointers = new Map();
    this.gesture = null;
    this.renderQueued = false;
    this.busy = false;
    this.closed = false;
    this.listeners = [];

    this.uid = `avatar-cropper-${++modalIdCounter}`;
    this.previewSource = this.buildPreviewSource();
  }

  // Downscaled working copy so dragging huge photos stays smooth.
  buildPreviewSource() {
    const maxDim = Math.max(this.W, this.H);
    if (maxDim <= PREVIEW_MAX_DIMENSION) return this.source;
    const k = PREVIEW_MAX_DIMENSION / maxDim;
    const canvas = createCanvas(this.W * k, this.H * k);
    getSmoothContext(canvas).drawImage(this.source, 0, 0, canvas.width, canvas.height);
    return canvas;
  }

  get scale() {
    return (this.D / Math.min(this.W, this.H)) * this.zoom;
  }

  open() {
    return new Promise((resolve) => {
      this.resolve = resolve;
      activeModal = this;
      this.previouslyFocused = document.activeElement;
      this.build();
      document.body.appendChild(this.backdrop);
      document.documentElement.classList.add('avatar-cropper-open');

      requestAnimationFrame(() => {
        if (this.closed) return;
        this.layout();
        this.stage.focus({ preventScroll: true });
      });

      if (typeof ResizeObserver === 'function') {
        this.resizeObserver = new ResizeObserver(() => this.layout());
        this.resizeObserver.observe(this.stage);
      } else {
        this.on(window, 'resize', () => this.layout());
      }
    });
  }

  on(target, type, handler, opts) {
    target.addEventListener(type, handler, opts);
    this.listeners.push(() => target.removeEventListener(type, handler, opts));
  }

  build() {
    const titleId = `${this.uid}-title`;
    const descId = `${this.uid}-desc`;

    this.backdrop = el('div', { className: 'avatar-cropper-backdrop' });
    this.dialog = el('div', {
      className: 'avatar-cropper-dialog',
      role: 'dialog',
      'aria-modal': 'true',
      'aria-labelledby': titleId,
      'aria-describedby': descId,
      id: this.uid
    });

    // Header
    const closeBtn = el('button', {
      type: 'button',
      className: 'avatar-cropper-close',
      'aria-label': 'Cancel and close',
      id: `${this.uid}-close`
    }, [icon('fa-solid fa-xmark')]);
    const header = el('div', { className: 'avatar-cropper-header' }, [
      el('div', { className: 'avatar-cropper-heading' }, [
        el('h2', { className: 'avatar-cropper-title', id: titleId, text: this.title }),
        el('p', { className: 'avatar-cropper-subtitle', id: descId, text: this.subtitle })
      ]),
      closeBtn
    ]);

    // Stage
    this.canvas = el('canvas', { className: 'avatar-cropper-canvas', 'aria-hidden': 'true' });
    this.ctx = this.canvas.getContext('2d');
    this.mask = el('div', { className: 'avatar-cropper-mask', 'aria-hidden': 'true' }, [
      el('div', { className: 'avatar-cropper-grid' })
    ]);
    const hint = el('div', { className: 'avatar-cropper-hint', 'aria-hidden': 'true' }, [
      icon('fa-solid fa-up-down-left-right'),
      el('span', { text: 'Drag to reposition' })
    ]);
    this.stage = el('div', {
      className: 'avatar-cropper-stage',
      tabindex: '0',
      role: 'application',
      'aria-roledescription': 'image cropper',
      'aria-label': 'Crop area. Use arrow keys to move the image, plus and minus to zoom, 0 to reset.',
      id: `${this.uid}-stage`
    }, [this.canvas, this.mask, hint]);

    // Zoom controls
    this.zoomOutBtn = el('button', {
      type: 'button', className: 'avatar-cropper-icon-btn', 'aria-label': 'Zoom out', title: 'Zoom out',
      id: `${this.uid}-zoom-out`
    }, [icon('fa-solid fa-magnifying-glass-minus')]);
    this.zoomInBtn = el('button', {
      type: 'button', className: 'avatar-cropper-icon-btn', 'aria-label': 'Zoom in', title: 'Zoom in',
      id: `${this.uid}-zoom-in`
    }, [icon('fa-solid fa-magnifying-glass-plus')]);
    this.slider = el('input', {
      type: 'range', min: '0', max: '1000', step: '1', value: '0',
      className: 'avatar-cropper-slider', 'aria-label': 'Zoom', id: `${this.uid}-zoom-slider`
    });
    this.resetBtn = el('button', {
      type: 'button', className: 'avatar-cropper-reset-btn', title: 'Reset crop and position',
      id: `${this.uid}-reset`
    }, [icon('fa-solid fa-rotate-left'), el('span', { text: 'Reset' })]);

    const controls = el('div', { className: 'avatar-cropper-controls' }, [
      el('div', { className: 'avatar-cropper-zoom' }, [this.zoomOutBtn, this.slider, this.zoomInBtn]),
      this.resetBtn
    ]);

    if (this.maxZoom <= 1.0001) {
      [this.zoomOutBtn, this.zoomInBtn, this.slider].forEach((n) => { n.disabled = true; });
    }

    // Live preview
    this.thumbLarge = el('canvas', { className: 'avatar-cropper-thumb avatar-cropper-thumb-lg', 'aria-hidden': 'true' });
    this.thumbSmall = el('canvas', { className: 'avatar-cropper-thumb avatar-cropper-thumb-sm', 'aria-hidden': 'true' });
    this.outputMeta = el('span', { className: 'avatar-cropper-meta' });
    const preview = el('div', { className: 'avatar-cropper-preview' }, [
      el('span', { className: 'avatar-cropper-preview-label', text: 'Preview' }),
      this.thumbLarge,
      this.thumbSmall,
      this.outputMeta
    ]);

    this.errorBox = el('div', { className: 'avatar-cropper-error', role: 'alert' });

    const body = el('div', { className: 'avatar-cropper-body' }, [this.stage, controls, preview, this.errorBox]);

    // Footer
    this.cancelBtn = el('button', {
      type: 'button', className: 'btn btn-back rounded-pill px-4 fw-semibold avatar-cropper-cancel',
      id: `${this.uid}-cancel`, text: 'Cancel'
    });
    this.applyText = el('span', { text: this.applyLabel });
    this.applyIcon = icon('fa-solid fa-check');
    this.applyBtn = el('button', {
      type: 'button', className: 'btn btn-primary rounded-pill px-4 fw-semibold d-inline-flex align-items-center justify-content-center gap-2 shadow-sm avatar-cropper-apply',
      id: `${this.uid}-apply`
    }, [this.applyIcon, this.applyText]);
    const footer = el('div', { className: 'avatar-cropper-footer' }, [this.cancelBtn, this.applyBtn]);

    this.dialog.appendChild(header);
    this.dialog.appendChild(body);
    this.dialog.appendChild(footer);
    this.backdrop.appendChild(this.dialog);

    // Events
    this.on(closeBtn, 'click', () => this.close(null));
    this.on(this.cancelBtn, 'click', () => this.close(null));
    this.on(this.applyBtn, 'click', () => this.apply());
    this.on(this.zoomInBtn, 'click', () => this.zoomTo(this.zoom * 1.2));
    this.on(this.zoomOutBtn, 'click', () => this.zoomTo(this.zoom / 1.2));
    this.on(this.resetBtn, 'click', () => this.reset());
    this.on(this.slider, 'input', () => this.zoomTo(this.sliderToZoom(Number(this.slider.value)), undefined, undefined, true));

    this.on(this.backdrop, 'mousedown', (e) => {
      // Only treat clicks that start and end on the backdrop as dismiss.
      this.backdropPointerDown = e.target === this.backdrop;
    });
    this.on(this.backdrop, 'click', (e) => {
      if (e.target === this.backdrop && this.backdropPointerDown && !this.busy) this.close(null);
      this.backdropPointerDown = false;
    });

    this.on(this.dialog, 'keydown', (e) => this.onDialogKeydown(e));
    this.on(this.stage, 'keydown', (e) => this.onStageKeydown(e));

    this.on(this.stage, 'pointerdown', (e) => this.onPointerDown(e));
    this.on(this.stage, 'pointermove', (e) => this.onPointerMove(e));
    this.on(this.stage, 'pointerup', (e) => this.onPointerUp(e));
    this.on(this.stage, 'pointercancel', (e) => this.onPointerUp(e));
    this.on(this.stage, 'lostpointercapture', (e) => this.onPointerUp(e));
    this.on(this.stage, 'wheel', (e) => this.onWheel(e), { passive: false });
    this.on(this.stage, 'dblclick', (e) => {
      const p = this.stagePoint(e);
      this.zoomTo(this.zoom * 1.5, p.x, p.y);
    });
  }

  // ---------------- Layout & rendering ----------------

  layout() {
    if (this.closed || !this.stage) return;
    const rect = this.stage.getBoundingClientRect();
    if (!rect.width || !rect.height) return;

    this.stageW = rect.width;
    this.stageH = rect.height;
    const minSide = Math.min(this.stageW, this.stageH);
    const margin = Math.max(14, minSide * 0.07);
    const newD = Math.max(60, minSide - margin * 2);

    if (this.D) {
      const ratio = newD / this.D;
      this.tx *= ratio;
      this.ty *= ratio;
    }
    this.D = newD;

    this.canvas.width = Math.round(this.stageW * this.dpr);
    this.canvas.height = Math.round(this.stageH * this.dpr);

    const left = (this.stageW - this.D) / 2;
    const top = (this.stageH - this.D) / 2;
    this.mask.style.width = `${this.D}px`;
    this.mask.style.height = `${this.D}px`;
    this.mask.style.left = `${left}px`;
    this.mask.style.top = `${top}px`;

    this.clampOffset();
    this.syncControls();
    this.render();
  }

  clampOffset() {
    const s = this.scale;
    const maxX = Math.max(0, (this.W * s - this.D) / 2);
    const maxY = Math.max(0, (this.H * s - this.D) / 2);
    this.tx = Math.min(maxX, Math.max(-maxX, this.tx));
    this.ty = Math.min(maxY, Math.max(-maxY, this.ty));
  }

  scheduleRender() {
    if (this.renderQueued) return;
    this.renderQueued = true;
    requestAnimationFrame(() => {
      this.renderQueued = false;
      this.render();
    });
  }

  render() {
    if (this.closed || !this.D) return;
    const ctx = this.ctx;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = 'high';

    const s = this.scale;
    const dw = this.W * s;
    const dh = this.H * s;
    const dx = this.stageW / 2 + this.tx - dw / 2;
    const dy = this.stageH / 2 + this.ty - dh / 2;
    ctx.drawImage(this.previewSource, dx, dy, dw, dh);

    this.renderThumb(this.thumbLarge, 64);
    this.renderThumb(this.thumbSmall, 36);
  }

  renderThumb(canvas, cssSize) {
    const px = Math.round(cssSize * this.dpr);
    if (canvas.width !== px) {
      canvas.width = px;
      canvas.height = px;
    }
    const ctx = getSmoothContext(canvas);
    const { sx, sy, size } = this.getCropRect();
    const k = getSourceSize(this.previewSource).width / this.W;
    ctx.clearRect(0, 0, px, px);
    if (this.outputType === 'image/jpeg') {
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, px, px);
    }
    ctx.drawImage(this.previewSource, sx * k, sy * k, size * k, size * k, 0, 0, px, px);
  }

  getCropRect() {
    const s = this.scale;
    const size = Math.min(this.D / s, this.W, this.H);
    let sx = this.W / 2 - (this.tx + this.D / 2) / s;
    let sy = this.H / 2 - (this.ty + this.D / 2) / s;
    sx = Math.min(Math.max(0, sx), this.W - size);
    sy = Math.min(Math.max(0, sy), this.H - size);
    return { sx, sy, size };
  }

  getOutputSize() {
    return Math.max(1, Math.min(OUTPUT_MAX_SIZE, Math.round(this.getCropRect().size)));
  }

  // ---------------- Zoom / pan ----------------

  zoomToSlider(zoom) {
    if (this.maxZoom <= 1.0001) return 0;
    return Math.round((Math.log(zoom) / Math.log(this.maxZoom)) * 1000);
  }

  sliderToZoom(value) {
    if (this.maxZoom <= 1.0001) return 1;
    return Math.exp((value / 1000) * Math.log(this.maxZoom));
  }

  zoomTo(newZoom, focalX, focalY, fromSlider = false) {
    const target = Math.min(this.maxZoom, Math.max(1, newZoom));
    const fx = (focalX === undefined ? this.stageW / 2 : focalX) - this.stageW / 2;
    const fy = (focalY === undefined ? this.stageH / 2 : focalY) - this.stageH / 2;
    const ratio = target / this.zoom;
    // Keep the image point under the focal point fixed while zooming.
    this.tx = fx - (fx - this.tx) * ratio;
    this.ty = fy - (fy - this.ty) * ratio;
    this.zoom = target;
    this.clampOffset();
    this.markInteracted();
    this.syncControls(fromSlider);
    this.scheduleRender();
  }

  panBy(dx, dy) {
    this.tx += dx;
    this.ty += dy;
    this.clampOffset();
    this.markInteracted();
    this.scheduleRender();
  }

  reset() {
    this.zoom = 1;
    this.tx = 0;
    this.ty = 0;
    this.clampOffset();
    this.syncControls();
    this.scheduleRender();
    this.stage.classList.remove('has-interacted');
  }

  syncControls(fromSlider = false) {
    const sliderValue = this.zoomToSlider(this.zoom);
    if (!fromSlider) this.slider.value = String(sliderValue);
    this.slider.style.setProperty('--fill', `${(Number(this.slider.value) / 10).toFixed(1)}%`);
    this.slider.setAttribute('aria-valuetext', `${Math.round(this.zoom * 100)}%`);
    const zoomable = this.maxZoom > 1.0001;
    this.slider.disabled = !zoomable;
    this.zoomOutBtn.disabled = !zoomable || this.zoom <= 1.0001;
    this.zoomInBtn.disabled = !zoomable || this.zoom >= this.maxZoom - 0.0001;
    const out = this.getOutputSize();
    this.outputMeta.textContent = `${out} \u00d7 ${out} px`;
  }

  markInteracted() {
    if (this.stage) this.stage.classList.add('has-interacted');
  }

  // ---------------- Pointer / wheel / keyboard ----------------

  stagePoint(e) {
    const rect = this.stage.getBoundingClientRect();
    return { x: e.clientX - rect.left, y: e.clientY - rect.top };
  }

  onPointerDown(e) {
    if (this.busy) return;
    if (e.pointerType === 'mouse' && e.button !== 0) return;
    e.preventDefault();
    try { this.stage.setPointerCapture(e.pointerId); } catch (err) { /* ignore */ }
    this.pointers.set(e.pointerId, this.stagePoint(e));
    this.stage.classList.add('is-dragging');
    this.startGesture();
  }

  startGesture() {
    const pts = Array.from(this.pointers.values());
    if (pts.length === 1) {
      this.gesture = { type: 'pan', last: { ...pts[0] } };
    } else if (pts.length >= 2) {
      const [a, b] = pts;
      this.gesture = {
        type: 'pinch',
        startDist: Math.hypot(b.x - a.x, b.y - a.y) || 1,
        startZoom: this.zoom,
        lastMid: { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 }
      };
    } else {
      this.gesture = null;
    }
  }

  onPointerMove(e) {
    if (!this.pointers.has(e.pointerId) || !this.gesture) return;
    e.preventDefault();
    this.pointers.set(e.pointerId, this.stagePoint(e));
    const pts = Array.from(this.pointers.values());

    if (this.gesture.type === 'pan' && pts.length === 1) {
      const p = pts[0];
      this.panBy(p.x - this.gesture.last.x, p.y - this.gesture.last.y);
      this.gesture.last = { ...p };
    } else if (this.gesture.type === 'pinch' && pts.length >= 2) {
      const [a, b] = pts;
      const dist = Math.hypot(b.x - a.x, b.y - a.y) || 1;
      const mid = { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 };
      this.tx += mid.x - this.gesture.lastMid.x;
      this.ty += mid.y - this.gesture.lastMid.y;
      this.gesture.lastMid = mid;
      this.zoomTo(this.gesture.startZoom * (dist / this.gesture.startDist), mid.x, mid.y);
    }
  }

  onPointerUp(e) {
    if (!this.pointers.has(e.pointerId)) return;
    this.pointers.delete(e.pointerId);
    if (this.pointers.size === 0) {
      this.stage.classList.remove('is-dragging');
      this.gesture = null;
    } else {
      this.startGesture();
    }
  }

  onWheel(e) {
    if (this.busy) return;
    e.preventDefault();
    const unit = e.deltaMode === 1 ? 0.05 : (e.deltaMode === 2 ? 0.5 : 0.0015);
    const factor = Math.exp(-e.deltaY * unit);
    const p = this.stagePoint(e);
    this.zoomTo(this.zoom * factor, p.x, p.y);
  }

  onStageKeydown(e) {
    if (this.busy) return;
    const step = e.shiftKey ? 40 : 10;
    let handled = true;
    switch (e.key) {
      case 'ArrowLeft': this.panBy(-step, 0); break;
      case 'ArrowRight': this.panBy(step, 0); break;
      case 'ArrowUp': this.panBy(0, -step); break;
      case 'ArrowDown': this.panBy(0, step); break;
      case '+':
      case '=': this.zoomTo(this.zoom * 1.1); break;
      case '-':
      case '_': this.zoomTo(this.zoom / 1.1); break;
      case '0': this.reset(); break;
      case 'Enter': this.apply(); break;
      default: handled = false;
    }
    if (handled) e.preventDefault();
  }

  onDialogKeydown(e) {
    if (e.key === 'Escape') {
      e.preventDefault();
      e.stopPropagation();
      if (!this.busy) this.close(null);
      return;
    }
    if (e.key === 'Tab') {
      // Keep focus inside the dialog.
      const focusables = Array.from(this.dialog.querySelectorAll('button, input, [tabindex="0"]'))
        .filter((n) => !n.disabled && n.offsetParent !== null);
      if (!focusables.length) return;
      const first = focusables[0];
      const last = focusables[focusables.length - 1];
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first.focus();
      }
    }
  }

  // ---------------- Apply / export ----------------

  setBusy(busy) {
    this.busy = busy;
    this.dialog.classList.toggle('is-busy', busy);
    [this.applyBtn, this.cancelBtn, this.zoomInBtn, this.zoomOutBtn, this.slider, this.resetBtn].forEach((n) => {
      n.disabled = busy;
    });
    this.applyIcon.className = busy ? 'fa-solid fa-spinner fa-spin' : 'fa-solid fa-check';
    this.applyText.textContent = busy ? 'Applying\u2026' : this.applyLabel;
    if (!busy) this.syncControls();
  }

  showError(message) {
    this.errorBox.textContent = message;
    this.errorBox.classList.add('is-visible');
  }

  async apply() {
    if (this.busy || this.closed) return;
    this.errorBox.classList.remove('is-visible');
    this.setBusy(true);
    try {
      const file = await this.exportFile();
      const previewUrl = URL.createObjectURL(file);
      this.close({ file, previewUrl });
    } catch (err) {
      this.setBusy(false);
      this.showError('Something went wrong while cropping this image. Please try again or choose another file.');
    }
  }

  async exportFile() {
    const { sx, sy, size } = this.getCropRect();
    const outSize = this.getOutputSize();

    // Progressive downscaling (halving) keeps large photos sharp.
    let src = this.source;
    let srcX = sx;
    let srcY = sy;
    let srcSize = size;
    const temps = [];
    while (srcSize / outSize > 2) {
      const step = Math.max(outSize, Math.min(Math.floor(srcSize / 2), MAX_INTERMEDIATE_SIZE));
      const tmp = createCanvas(step, step);
      getSmoothContext(tmp).drawImage(src, srcX, srcY, srcSize, srcSize, 0, 0, step, step);
      temps.push(tmp);
      src = tmp;
      srcX = 0;
      srcY = 0;
      srcSize = step;
    }

    const out = createCanvas(outSize, outSize);
    const ctx = getSmoothContext(out);
    if (this.outputType === 'image/jpeg') {
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, outSize, outSize);
    }
    ctx.drawImage(src, srcX, srcY, srcSize, srcSize, 0, 0, outSize, outSize);
    temps.forEach(releaseCanvas);

    const blob = await canvasToBlob(out, this.outputType, this.outputType === 'image/jpeg' ? JPEG_QUALITY : undefined);
    releaseCanvas(out);
    if (!blob || !blob.size) throw new Error('Canvas export failed');

    const type = blob.type || this.outputType;
    return new File([blob], buildOutputFileName(this.file.name, type), { type, lastModified: Date.now() });
  }

  // ---------------- Teardown ----------------

  close(result) {
    if (this.closed) return;
    this.closed = true;

    this.listeners.forEach((off) => off());
    this.listeners = [];
    if (this.resizeObserver) this.resizeObserver.disconnect();

    if (this.backdrop && this.backdrop.parentNode) this.backdrop.parentNode.removeChild(this.backdrop);
    document.documentElement.classList.remove('avatar-cropper-open');

    if (this.previewSource !== this.source) releaseCanvas(this.previewSource);
    releaseCanvas(this.canvas);
    releaseSource(this.source);
    this.previewSource = null;
    this.source = null;

    if (activeModal === this) activeModal = null;

    const toFocus = this.previouslyFocused;
    if (toFocus && typeof toFocus.focus === 'function' && document.contains(toFocus)) {
      try { toFocus.focus({ preventScroll: true }); } catch (e) { /* ignore */ }
    }

    if (this.resolve) this.resolve(result);
  }
}
