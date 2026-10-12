# Route2 – Service Route Planner

Plan a day of service calls: paste your calls, see them grouped by store, filter by how long they're past due, and get a driving order with Google Maps directions. Your calls and settings are saved in your own browser and never leave your device.

**Current version: 2.3**

## Pick your planner

| Edition | Stores | Use in your browser | Save a copy |
|---|---|---|---|
| **Company-wide** | All 1,443 stores | [**Open**](https://aaronzandman.github.io/Route2/planners/ALL.html) | [**Download**](https://aaronzandman.github.io/Route2/download.html?edition=ALL) |
| **Alabama** | 96 stores | [**Open**](https://aaronzandman.github.io/Route2/planners/AL.html) | [**Download**](https://aaronzandman.github.io/Route2/download.html?edition=AL) |
| **Florida** | 896 stores | [**Open**](https://aaronzandman.github.io/Route2/planners/FL.html) | [**Download**](https://aaronzandman.github.io/Route2/download.html?edition=FL) |
| **Georgia** | 222 stores | [**Open**](https://aaronzandman.github.io/Route2/planners/GA.html) | [**Download**](https://aaronzandman.github.io/Route2/download.html?edition=GA) |
| **Kentucky** | 11 stores | [**Open**](https://aaronzandman.github.io/Route2/planners/KY.html) | [**Download**](https://aaronzandman.github.io/Route2/download.html?edition=KY) |
| **North Carolina** | 61 stores | [**Open**](https://aaronzandman.github.io/Route2/planners/NC.html) | [**Download**](https://aaronzandman.github.io/Route2/download.html?edition=NC) |
| **South Carolina** | 72 stores | [**Open**](https://aaronzandman.github.io/Route2/planners/SC.html) | [**Download**](https://aaronzandman.github.io/Route2/download.html?edition=SC) |
| **Tennessee** | 60 stores | [**Open**](https://aaronzandman.github.io/Route2/planners/TN.html) | [**Download**](https://aaronzandman.github.io/Route2/download.html?edition=TN) |
| **Virginia** | 25 stores, route groups A–F | [**Open**](https://aaronzandman.github.io/Route2/planners/VA.html) | [**Download**](https://aaronzandman.github.io/Route2/download.html?edition=VA) |

- **Open** runs the planner right in your browser, on a phone or computer. Nothing to save, and it's always the newest version. Bookmark it.
- **Download** saves the planner file to your device so it works with no internet. Open the saved file in Edge or Chrome. Download again when a new version comes out.
- Either way, your calls and settings are saved in your own browser and never leave your device.
- Pick one way and stick with it, since each keeps its own saved data. To move data between them, use **Save backup file** and **Load backup file** in the planner.

[Download page with every edition](https://aaronzandman.github.io/Route2/)

## Getting your calls from SAP

1. In SAP, type **IW49N** in the command field and press **Enter**.
2. Select **Get Variant** (Shift+F5).
3. Choose your service-call variant and confirm.
4. **Execute** the report (F8).
5. Click the **Select All** icon in the upper-left corner of the results list.
6. Copy with **Ctrl+C**.
7. In the planner, paste into **Import calls** and select **Load calls**.

The report must show these 15 columns, in this order (header row optional):

| # | Column | # | Column |
|---|---|---|---|
| 1 | Order Type | 9 | Serial Number |
| 2 | MaintActivType | 10 | Order |
| 3 | Basic fin. date | 11 | Description |
| 4 | Earliest finish | 12 | Oper.WorkCenter |
| 5 | Priority | 13 | User status |
| 6 | Customer | 14 | Material |
| 7 | Personnel No. | 15 | Location |
| 8 | Activity | | |

If your columns are in a different order, change the layout in SAP (Ctrl+F8) and save it with your variant. The planner warns you if something looks out of order.

## What's in this repository

- `planners/` – every edition. `ALL.html` and `<STATE>.html` are always the newest; the versioned files (`route-planner-VA-v2.3.html`) are kept for reference.
- `index.html` – download page with every edition built in
- `source/` – shared planner code, store list, and the build script that makes every edition
