# LaptopCheck — a 5-minute used laptop inspection

**[한국어](README.md)**

Put it on a USB stick, plug it into the laptop you are about to buy, and **double-click once**.
Nothing to install, and nothing on the seller's laptop is changed.

- **Automatic check (30 s):** battery wear, SSD wear, hidden failure history (unexpected shutdowns, blue screens), driver errors, and whether the hardware matches the listing
- **Guided manual tests (5 min):** dead pixels and burn-in, every key, touchscreen and touchpad, left/right speakers, microphone, webcam, charging ports, CPU heat under load
- **Verdict:** OK / needs checking / problem, plus copyable text, PDF and JSON report

> Works on any Windows 10/11 laptop regardless of brand. On macOS only the manual test page is available.

---

## How to use

### 1. Before you go (1 min)

1. Download `LaptopCheck-vX.Y.Z.zip` from [**Releases**](../../releases/latest).
2. **Extract it** and copy the whole `LaptopCheck` folder to a USB stick.
3. Do a dry run of `START.bat` on your own Windows PC if you can.
4. Bring: the USB stick, a phone hotspot, wired earphones (optional).

### 2. At the meeting (5 min)

1. Ask the seller first, e.g. "Mind if I run a read-only check tool? It doesn't change anything."
2. Plug in the USB stick and double-click `START.bat`.
   - **"Windows protected your PC"** → More info → Run anyway.
   - **UAC prompt** → Yes (needed for detailed SSD health).
3. When the browser opens, pick **Quick** at the top right and work down the menu on the left.
4. Enter the **listing specs** (model, CPU, RAM, storage, claimed battery %) to compare them with the real hardware.
5. Read the verdict on **Result** and copy the text into a note or a message to yourself.

---

## What it checks

| Area | Automatic | Manual |
|---|---|---|
| Battery | Health (% of design capacity), cycle count, vs. seller's claim | Live charging detection on each port |
| Storage | Health, SSD wear, power-on hours, temperature, read errors | — |
| Failure history | Unexpected shutdowns, blue screens and hardware errors in the last 90 days; log start date (sign of a recent wipe) | Shutdowns or fan noise under load |
| Specs | Model, CPU, RAM, storage vs. the listing | Box serial = device serial |
| Screen | Resolution, refresh rate, size | 8 solid colors + gradient for dead pixels, burn-in, bleed |
| Input | Touchscreen and precision touchpad detected | Every key, 100% touch area, five touchpad gestures |
| Audio & camera | Audio devices and webcam detected | Left/right speakers, sweep (rattle), mic level, webcam image |
| Wireless | Wi-Fi and Bluetooth adapters | Hotspot connection |
| Windows | Activation, drive encryption, Microsoft accounts | Seller signed out, reset agreed |

Every threshold is documented in [docs/CHECKS.md](docs/CHECKS.md).

## Is it safe?

- **Read-only.** No settings changed, nothing installed or deleted. A temporary battery report is written to `%TEMP%` and removed right away.
- **Offline.** Nothing is sent over the network. Results are saved only to `data.js` next to the tool.
- **Two readable files.** `check.ps1` (collects facts) and `LaptopCheck.html` (shows and judges them).
- Copied result text masks the serial number except the last 4 characters.

## FAQ

**"Files are missing" when I run it.** You ran it from inside the ZIP. Extract the ZIP first.

**I clicked "No" on the UAC prompt.** Fine. Only detailed SSD health and drive encryption are skipped.

**It shows a few unexpected shutdowns.** Holding the power button counts too. One or two are common; many deserve a question to the seller.

**Does it work on a MacBook?** Open `LaptopCheck.html` in a browser for the screen, keyboard, touchpad, speaker, webcam and heat tests. The page tells you where macOS shows battery health.

---

## For developers

```
src/START.bat          launcher (checks extraction → runs PowerShell)
src/check.ps1          collects hardware facts → data.js (language- and model-neutral)
src/LaptopCheck.html   viewer, judging RULES, manual tests, i18n (ko/en)
samples/data.sample.js sample data for local preview
tests/smoke.mjs        headless Chromium smoke test of rendering and judging
scripts/build.sh       builds the release ZIP
.github/workflows/     CI (real run on a Windows runner + smoke test) and tag-triggered releases
```

- Preview: `cp samples/data.sample.js src/data.js`, then open `src/LaptopCheck.html`.
- Test: `npm install && npx playwright install chromium && npm test`
- Release: `git tag v1.0.0 && git push --tags`
- Change thresholds in the `RULES` object; add a language by adding a key to `T` (missing strings fall back to English).

Issues and PRs welcome — especially results from other brands, JIS/ISO keyboard layouts and translations.

## License

[MIT](LICENSE)

> Results are guidance only. They do not guarantee the hardware's condition; the final decision is yours.
