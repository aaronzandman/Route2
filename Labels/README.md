# V175 Scan Station

Scan a material number or serial number, see which bin it lives in, and print its label on the Zebra GK420d.

**Live page:** https://aaronzandman.github.io/Route2/Labels/

No inventory is stored in this repository. Each person loads their own SAP exports into the page,
and the files are read in the browser only. They are never uploaded. The page remembers them on that computer until
you load new ones or click **Forget files on this computer**.

## What's in the repo

| Path | What it is |
|---|---|
| `index.html` | The scan station page (works on GitHub Pages) |
| `layout/v175_bins.csv` | Which bin each material number goes in, plus maker / model / part type for the label |
| `layout/v175_locations.csv` | Bin names and where each bin is in the van |
| `bridge/Start-V175-Labels.bat` | Starts the print bridge on the PC with the Zebra |
| `bridge/v175_bridge.ps1` | The print bridge (built-in Windows PowerShell, nothing to install) |
| `v175_TEST_label.zpl` | One test label to print and scan before printing a batch |

## Files you load in the page (same columns as the SAP exports)

| File | Required columns |
|---|---|
| Van inventory (e.g. `VanInventory.xlsx`) | `Material`, `Material Description`, `Storage Location`, `Unrestricted` |
| Serialized items (e.g. `7510.xlsx`) | `Serial Number`, `Material`, `Location` (`Description` is used if present) |

`.xlsx` and `.csv` both work. Only rows whose storage location / location matches the van box (default `V175`) are used.
The page tells you which file is which by its columns, so you can pick both at once or drag them onto the page.

## Set up the Zebra GK420d (once)

The GK420d is a **direct thermal** printer: use direct-thermal 35 x 20 mm labels with a gap between them, and no ribbon.

### 1. Load the labels
1. Open the lid (press the two release tabs on the sides) and slide the roll holders apart.
2. Put the roll in with labels coming off the **top** of the roll, printed side up, and let the holders close on it.
3. Pull the labels over the platen roller at the front, under the guides. Slide the guides in until they just touch the label edges.
4. Close the lid until it clicks. Press **Feed** once: one label should come out and stop.

### 2. Install the driver
1. Plug the printer into the PC by USB and turn it on.
2. Download **ZDesigner** from zebra.com (support page for the GK420d > Drivers) and run it. Choose **Install Printer** > the **GK420d (203 dpi)** model > the USB port it found.
3. Windows now lists a printer called *ZDesigner GK420d*.

### 3. Share it as ZEBRA
1. Windows Settings > **Bluetooth & devices** > **Printers & scanners** > *ZDesigner GK420d* > **Printer properties**.
2. **Sharing** tab: tick **Share this printer** and set the share name to `ZEBRA`. Click **OK**.
3. If Windows asks to turn on file and printer sharing, say yes, for **private** networks only.
4. Check it: open Command Prompt in the `Labels` folder and run
   `copy /b v175_TEST_label.zpl \\localhost\ZEBRA`
   A label should print. If you see *"The network name cannot be found"*, the share name isn't exactly `ZEBRA`.

### 4. Set the label size and calibrate
Start the bridge (below), open the page, and press **Calibrate printer**. That sends `bridge/zebra_setup.zpl`, which:
- sets gap-sensing media, direct thermal, 280 x 160 dots (35 x 20 mm), print speed 3 in/s
- saves those settings in the printer
- runs a media calibration (`~JC`): a few blank labels feed out, then it stops at the start of a label

Without the page: `copy /b bridge\zebra_setup.zpl \\localhost\ZEBRA`.
Or by hand: with the printer on, **hold Feed until the light flashes twice**, then let go. Holding until **one** flash prints a configuration report.

Redo the calibration whenever you load a different label roll, or if a blank label comes out between printed ones.

### Troubleshooting
| Problem | Fix |
|---|---|
| Blank label between real ones, or printing runs across the gap | Calibrate (press **Calibrate printer**, or hold Feed for two flashes) |
| Print is too light or patchy | Wrong label type (needs direct thermal), or raise darkness in ZDesigner: Printing Preferences > Options > Darkness |
| Text or barcode cut off on one side | The roll guides are too loose. Slide them against the labels and calibrate |
| Status light red or flashing | Lid not fully closed, or out of labels |
| Page shows *Printer bridge offline* | Start `bridge\Start-V175-Labels.bat` and keep its window open |

## Set up printing (once per PC)

1. Share the Zebra GK420d in Windows as `ZEBRA` (so `\\localhost\ZEBRA` works).
2. Copy the `bridge` folder to the PC. Double-click `Start-V175-Labels.bat` and keep its window open.
   If Windows blocks it: right-click the file > Properties > tick **Unblock**.
3. The bridge opens https://aaronzandman.github.io/Route2/Labels/ for you. If Chrome/Edge asks to let the site **access devices on your local network**, choose **Allow**.
   The badge at the top turns green: *Printer ready*.

The bridge only listens on this computer (`127.0.0.1` / `::1`, port 9123). It prints RAW ZPL with
`copy /b file.zpl \\localhost\ZEBRA`. The ZPL goes to the printer as-is: the driver only passes it through, and no PDFs or images are involved. Every print is logged in `bridge/logs/print_log.csv`.

## Before printing a batch

Press **Test label** (or scan/type `T`). It prints material 18000376. Scan that label: the page should show bin **D-A1-1**.
Blank labels between real ones mean the printer needs media recalibration, not a code fix.

## Scanning

| Scan or type | Result |
|---|---|
| `18000376` | Shows the bin, prints 1 label |
| `CNC41931WD` (a serial) | Shows the bin, prints that unit's label with its serial |
| `18000376\|1` (one of these labels) | Reads the material number back out |
| `5*18000376` | 5 labels |
| A serialized material with several units | Lists the serials. Tap one, or scan the serial |
| Unknown code | Beep, a CHECK ME label, and the code is logged once in `bridge/logs/unknown_scans.csv`. Type a material # in its `Tag` column and the code works on the next scan |

## Label (35 x 20 mm, 280 x 160 dots)

Data Matrix ECC 200, forced 18x18, 7 dots per module at `^FO12,17`, payload `<material>|1`.
Text to the right at x=146: bin code, maker, model (serial labels: `SN ...`), part type, description (wraps to 2 lines), material number.

## Moving a part or adding a new one

Edit `layout/v175_bins.csv` on GitHub (`Material,Bin,Maker,Model,Group`). Parts in the inventory that aren't in this file
show as **NO BIN**, and the page counts them after you load your files.
