"""Cut the booth illustration into the textures the game draws.

    python tools/build_ui_assets.py

Needs Pillow, numpy and opencv-python-headless. Reads
`source_files/booth_ui_source.png` (the reference painting, 1672x941) and writes
`assets/ui/*.png`. Run it again whenever the painting changes; nothing else in
the project is generated.

The painting is scaled once to the 1920x1080 viewport here, so every texture is
drawn 1:1 in game and every coordinate below is a game coordinate.

What it produces:

  booth_plate.png     the whole room with every LIVE element taken out: the packet
                      and the line behind it, the ID sheet, the manual's text, the
                      info panel's text and the packet tag number. The game draws
                      those back on top from real data.
  packet_box.png      the box at the glass, cut out of the painting.
  id_document.png     the ID sheet, with its four value cells wiped clean. Its
                      placement on screen is printed when this runs and lives in
                      DOC_SPRITE_RECT in inspection_window.gd.
  btn_<name>_<state>.png
                      the two arcade caps, masked to the cap, in normal / hover /
                      pressed / disabled. Each is the size of its BTN_* rect.
"""

from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "source_files" / "booth_ui_source.png"
OUT = ROOT / "assets" / "ui"
W, H = 1920, 1080

# --- regions, in game (1920x1080) coordinates --------------------------------
# The packet standing at the glass, and the column of "ghost" boxes behind it
# (the rest of the line), which sit in a dark doorway between two lit uprights.
BOX = (861, 362, 1059, 596)            # x0, y0, x1, y1
QUEUE_CLEAR = (857, 236, 1064, 601)    # everything between the uprights
# Search window for the ID sheet; the sheet itself is found by brightness.
DOC_SEARCH = (522, 689, 1032, 1004)
# The four value cells on the ID sheet (text bands only, between the dashed rules).
DOC_VALUE_CELLS = [
    (776, 783, 996, 813),
    (776, 823, 996, 849),
    (776, 857, 996, 884),
    (776, 892, 996, 922),
]
# Manual body text, its title bar text, the info panel text, the packet tag number.
MANUAL_BODY = (98, 752, 442, 970)
MANUAL_SEAL = (330, 930, 470, 1060)    # leave the faded seal alone
MANUAL_TITLE = (100, 709, 426, 745)
INFO_TEXT = (1484, 948, 1884, 1014)
PKT_TEXT = (1040, 809, 1136, 856)
# Button caps.
BTN_ALLOW = (1400, 676, 1606, 852)
BTN_BLOCK = (1645, 676, 1856, 852)
# Columns each cap actually spans; the housing either side is lit the same colour.
CAP_COLS = {"allow": (1404, 1602), "block": (1652, 1848)}
# Rows the caps actually occupy. The mask is cut to these so the red glow on the
# housing above and the hazard stripe below are not picked up as cap.
CAP_ROWS = (689, 847)


def lum(img: np.ndarray) -> np.ndarray:
    return img[..., :3].astype(np.float32).mean(axis=2)


def region_mask(shape, box) -> np.ndarray:
    m = np.zeros(shape[:2], bool)
    x0, y0, x1, y1 = box
    m[y0:y1, x0:x1] = True
    return m


def inpaint(img: np.ndarray, mask: np.ndarray, grow: int = 2, radius: int = 4) -> np.ndarray:
    """Remove `mask` pixels (text strokes) by Telea inpainting. Works well for thin
    strokes on flat paper or a flat panel, which is all it is used for."""
    m = mask.astype(np.uint8) * 255
    if grow:
        m = cv2.dilate(m, np.ones((grow * 2 + 1, grow * 2 + 1), np.uint8))
    bgr = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)
    out = cv2.inpaint(bgr, m, radius, cv2.INPAINT_TELEA)
    return cv2.cvtColor(out, cv2.COLOR_BGR2RGB)


def noise(shape, sigma: float, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    return rng.normal(0.0, sigma, shape)


def clear_text(img: np.ndarray, box, dark_text: bool, threshold: float,
               exclude=None, grow=2) -> np.ndarray:
    L = lum(img)
    m = region_mask(img.shape, box) & ((L < threshold) if dark_text else (L > threshold))
    if exclude is not None:
        m &= ~region_mask(img.shape, exclude)
    return inpaint(img, m, grow=grow)


def clear_queue(img: np.ndarray) -> np.ndarray:
    """Take the packet and the line out of the window.

    Each row is rebuilt by blending between the background just inside the two
    lit uprights either side of it. The doorway behind the line is dark, flat and
    banded horizontally (floor, rail, plinth), which is exactly what a per-row
    blend reproduces; a general inpaint smears it into fog instead."""
    out = img.astype(np.float32).copy()
    x0, y0, x1, y1 = QUEUE_CLEAR
    # Anchor columns just INSIDE the uprights (not on them, or the doorway comes
    # out lit), smoothed down the column so single noisy rows do not streak.
    left = cv2.blur(out[:, x0:x0 + 4].mean(axis=1, keepdims=True), (1, 5))[:, 0]
    right = cv2.blur(out[:, x1 - 4:x1].mean(axis=1, keepdims=True), (1, 5))[:, 0]
    t = np.linspace(0.0, 1.0, x1 - x0)[:, None]
    for y in range(y0, y1):
        out[y, x0:x1] = left[y] * (1 - t) + right[y] * t
    out[y0:y1, x0:x1] += noise((y1 - y0, x1 - x0, 1), 1.4, 7)
    return np.clip(out, 0, 255).astype(np.uint8)


def document_mask(img: np.ndarray) -> np.ndarray:
    """The ID sheet: the big bright blob in DOC_SEARCH, with its text and the ring
    punches closed over so the cut-out is one solid sheet."""
    x0, y0, x1, y1 = DOC_SEARCH
    L = lum(img[y0:y1, x0:x1])
    bright = (L > 135).astype(np.uint8)
    n, labels, stats, _ = cv2.connectedComponentsWithStats(bright, 8)
    biggest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    sheet = (labels == biggest).astype(np.uint8) * 255
    sheet = cv2.morphologyEx(sheet, cv2.MORPH_CLOSE, np.ones((15, 15), np.uint8))
    # Fill every hole: text, rules and emblem are inside the sheet.
    contours, _ = cv2.findContours(sheet, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    filled = np.zeros_like(sheet)
    cv2.drawContours(filled, contours, -1, 255, thickness=-1)
    full = np.zeros(img.shape[:2], np.uint8)
    full[y0:y1, x0:x1] = filled
    return full > 0


def empty_tray(img: np.ndarray, sheet: np.ndarray) -> np.ndarray:
    """What is under the sheet once it has been picked up: the dark board, and the
    slot the sheets are fed through along its bottom edge."""
    out = img.astype(np.float32).copy()
    ys, xs = np.nonzero(sheet)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    grown = cv2.dilate(sheet.astype(np.uint8), np.ones((7, 7), np.uint8)) > 0

    # Board colour: the dark metal the painting shows around the sheet, a little
    # lighter toward the bottom where the desk catches the light.
    base = np.array([38.0, 35.0, 32.0])
    yy = np.arange(img.shape[0], dtype=np.float32)[:, None, None]
    shade = base * (0.88 + 0.22 * np.clip((yy - y0) / max(1, (y1 - y0)), 0, 1))
    board = np.broadcast_to(shade, out.shape).copy()
    board += noise(out.shape[:2] + (1,), 2.4, 11)
    # A few scuffs so it is not a flat fill.
    rng = np.random.default_rng(5)
    for _ in range(90):
        sx = int(rng.integers(x0, x1)); sy = int(rng.integers(y0, y1))
        ln = int(rng.integers(4, 26))
        board[sy, sx:sx + ln] += rng.uniform(5, 13)
    # Recessed: an inner shadow that fades in from the edge of the opening.
    dist = cv2.distanceTransform(grown.astype(np.uint8), cv2.DIST_L2, 5)
    board *= (1.0 - 0.45 * np.exp(-dist / 7.0))[..., None]
    out[grown] = board[grown]

    # The feed slot: a dark mouth with a lit lower lip, under the sheet's foot.
    slot_y = int(y1) - 4
    sx0, sx1 = int(x0) + 6, int(x1) - 4
    out[slot_y:slot_y + 6, sx0:sx1] = [8, 7, 6]
    out[slot_y + 6:slot_y + 8, sx0:sx1] = [88, 80, 66]
    out[slot_y - 2:slot_y, sx0:sx1] = [14, 13, 12]
    return np.clip(out, 0, 255).astype(np.uint8)


def button_mask(img: np.ndarray, box, hue_ok, cols) -> np.ndarray:
    x0, y0, x1, y1 = box
    crop = img[y0:y1, x0:x1]
    hsv = cv2.cvtColor(crop, cv2.COLOR_RGB2HSV)
    h = hsv[..., 0].astype(int) * 2
    s = hsv[..., 1] / 255.0
    v = hsv[..., 2] / 255.0
    m = (hue_ok(h) & (s > 0.32) & (v > 0.18)).astype(np.uint8) * 255
    m[:CAP_ROWS[0] - y0] = 0
    m[CAP_ROWS[1] - y0:] = 0
    m[:, :cols[0] - x0] = 0
    m[:, cols[1] - x0:] = 0
    # Knock off thin glow fringes on the housing beside the cap.
    m = cv2.morphologyEx(m, cv2.MORPH_OPEN, np.ones((9, 9), np.uint8))
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    n, labels, stats, _ = cv2.connectedComponentsWithStats(m, 8)
    biggest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    m = ((labels == biggest) * 255).astype(np.uint8)
    contours, _ = cv2.findContours(m, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    filled = np.zeros_like(m)
    cv2.drawContours(filled, contours, -1, 255, thickness=-1)
    # Feather one pixel so the state swaps do not leave a hard outline.
    filled = cv2.GaussianBlur(filled, (3, 3), 0)
    return filled


def write_button(img: np.ndarray, box, name: str, hue_ok) -> None:
    x0, y0, x1, y1 = box
    crop = img[y0:y1, x0:x1].astype(np.float32)
    alpha = button_mask(img, box, hue_ok, CAP_COLS[name])

    def save(rgb, state):
        rgba = np.dstack([np.clip(rgb, 0, 255).astype(np.uint8), alpha])
        Image.fromarray(rgba, "RGBA").save(OUT / f"btn_{name}_{state}.png")

    grey = crop.mean(axis=2, keepdims=True)
    save(crop, "normal")
    save(crop * 1.22 + 14.0, "hover")
    # Pressed: darker and pushed down two pixels into the housing.
    pressed = np.roll(crop * 0.78, 2, axis=0)
    pressed[:2] = crop[:2] * 0.6
    save(pressed, "pressed")
    # Disabled: the lamp inside the cap is turned down. Kept gentle on purpose —
    # the painting shows the caps lit while the sheet is still unread, so the
    # locked state should read as "dimmed", not "switched off".
    save((crop * 0.75 + grey * 0.25) * 0.72, "disabled")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    src = Image.open(SOURCE).convert("RGB").resize((W, H), Image.LANCZOS)
    art = np.asarray(src).copy()

    # --- the packet at the glass ---
    x0, y0, x1, y1 = BOX
    Image.fromarray(art[y0:y1, x0:x1]).convert("RGBA").save(OUT / "packet_box.png")

    # --- the ID sheet, with blank value cells ---
    sheet = document_mask(art)
    doc_src = art.copy()
    L = lum(doc_src)
    cells = np.zeros(sheet.shape, bool)
    for c in DOC_VALUE_CELLS:
        cells |= region_mask(doc_src.shape, c)
    doc_src = inpaint(doc_src, cells & (L < 150), grow=2)
    ys, xs = np.nonzero(sheet)
    dx0, dx1, dy0, dy1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    a = cv2.GaussianBlur(sheet.astype(np.uint8) * 255, (3, 3), 0)
    rgba = np.dstack([doc_src, a])[dy0:dy1, dx0:dx1]
    Image.fromarray(rgba, "RGBA").save(OUT / "id_document.png")

    # --- buttons (cut from the untouched painting) ---
    write_button(art, BTN_ALLOW, "allow", lambda h: (h > 55) & (h < 170))
    write_button(art, BTN_BLOCK, "block", lambda h: (h < 22) | (h > 335))

    # --- the plate ---
    plate = clear_queue(art)
    plate = empty_tray(plate, sheet)
    plate = clear_text(plate, MANUAL_BODY, dark_text=True, threshold=160, exclude=MANUAL_SEAL)
    plate = clear_text(plate, MANUAL_TITLE, dark_text=False, threshold=95)
    plate = clear_text(plate, INFO_TEXT, dark_text=False, threshold=45)
    plate = clear_text(plate, PKT_TEXT, dark_text=True, threshold=68)
    Image.fromarray(plate).save(OUT / "booth_plate.png")

    print(f"DOC_SPRITE_RECT = Rect2({dx0}, {dy0}, {dx1 - dx0}, {dy1 - dy0})")
    print(f"BOX = Rect2({x0}, {y0}, {x1 - x0}, {y1 - y0})")
    print(f"BTN_ALLOW = Rect2({BTN_ALLOW[0]}, {BTN_ALLOW[1]}, "
          f"{BTN_ALLOW[2] - BTN_ALLOW[0]}, {BTN_ALLOW[3] - BTN_ALLOW[1]})")
    print(f"BTN_BLOCK = Rect2({BTN_BLOCK[0]}, {BTN_BLOCK[1]}, "
          f"{BTN_BLOCK[2] - BTN_BLOCK[0]}, {BTN_BLOCK[3] - BTN_BLOCK[1]})")


if __name__ == "__main__":
    main()
