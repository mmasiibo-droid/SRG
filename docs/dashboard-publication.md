# Tableau Public dashboard — publication handoff

**Status: website reachable; desktop sign-in still blocked.**
The owner is signed in to the Tableau Public website, and the safe aggregate
CSV was imported into Tableau Public 2023.2. The existing local worksheet is
still open and shows seven marks with total net sales of UGX 50,400. Native
HTTPS requests to Tableau Public's `/app` routes now return HTTP 200, but
Tableau 2023.2's embedded sign-in still shows `ERR_CONNECTION_RESET`, including
after reloading the sign-in page. The website session does not authenticate
the desktop client. No public workbook or live view URL has been created. Do
not present the local worksheet or CSV as a published Tableau view.

## Safe import file

Open [`workspace-synthetic-sales-aggregates.csv`](../dashboard/workspace-synthetic-sales-aggregates.csv)
from the `dashboard/` folder. The local profiling pipeline regenerates it from
accepted, cleansed sales and product rows. It has seven grouped records with
month, district, channel, product category, net sales (UGX), transaction
count, and net units. It excludes customer IDs, order IDs, payment references,
phone numbers, and row-level transaction data.

The fixture README identifies these values as fabricated test fixtures.
Retain a visible dashboard disclaimer that they are not SRG business findings.

## Build and publish in Tableau Public

1. In the open Tableau Public 2023.2 local workbook, verify the **Text file**
   connection points to the safe CSV. Check that there are seven rows and
   these fields: `month`, `district`, `channel`, `category`,
   `net_sales_ugx`, `transactions`, and `net_units`.
2. Set the four dimension fields to String (month is ISO `YYYY-MM` text).
   Set `net_sales_ugx` and `net_units` to Number (decimal), and `transactions`
   to Number (whole).
3. Build a monthly sales worksheet with `month` on Columns and `SUM(net_sales_ugx)`
   on Rows. Build a category sales bar chart with `category` and
   `SUM(net_sales_ugx)`. Add KPI sheets for total net sales, transaction count,
   and net units. Keep the negative return in both amount and units.
4. Add filters for month, district, channel, and category; apply them to all
   relevant worksheets and assemble the views into a dashboard.
5. Put this disclaimer prominently on the dashboard:
   **Synthetic workspace fixtures only — not SRG business findings.**
   Note that one of eight input sales rows was quarantined and the displayed
   values are grouped aggregates of the seven accepted rows.
6. Review the workbook for sensitive fields and confirm the data source is
   only the grouped CSV. Tableau Public workbooks and published data are public;
   anyone may be able to view, download, or reuse them. Do not publish private
   or real customer data to Tableau Public.
7. The Tableau Public website sign-in is complete, but the desktop client
   needs its own successful authentication. Retry the desktop sign-in or use
   an updated Tableau Public client if its embedded page continues to reset.
   Then use **File → Save to Tableau Public** (wording can differ slightly by
   version). Publish only after confirming the workbook contains this
   synthetic aggregate dataset.
8. Open the published view in a signed-out/private browser. Copy the actual
   public view URL into `docs/portfolio.md` and the finalization checklist.
   Never use a local `file:` URL or invent a Tableau URL.

**Live Tableau Public URL:** Not published — Tableau 2023.2 desktop
authentication still fails with `ERR_CONNECTION_RESET`; authenticate, save,
and verify the resulting view before adding a link.

Do not share credentials in the project or chat. The browser session is
authenticated and native requests now reach Tableau Public's `/app` routes,
but the desktop embedded sign-in continues to reset. If that remains the
case, keep the local worksheet as the demonstration and state that external
publication is blocked.
