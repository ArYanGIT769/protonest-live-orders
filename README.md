# PROTONEST — Live Engineering Orders

Website: https://protonest-live-orders.netlify.app/

This repository packages the latest available PROTONEST Netlify export (the contact-fix build dated 30 August 2026), the Supabase database setup, and an earlier editable version of the website.

## What is in this repository

| Path | Contents |
| --- | --- |
| `PROTONEST-current-static-export.zip` | Static Next.js export for the live-order website, ready for static hosting. This is compiled output. |
| `PROTONEST-SUPABASE-SETUP.sql` | SQL schema, triggers, policies and related database setup for live orders. Review before running in your own Supabase project. |
| `PROTONEST-earlier-editable-source.zip` | Earlier editable Vite website with its HTML, CSS and JavaScript. This is **not** the source code of the newer Next.js export. |

## Run the current static export locally

```bash
unzip PROTONEST-current-static-export.zip
cd site
python3 -m http.server 8000
```

Open `http://localhost:8000/`. Hosting rewrites may be needed for extensionless routes such as `/account` and `/admin`; the export also includes corresponding HTML files.

## Work on the earlier editable website

```bash
unzip PROTONEST-earlier-editable-source.zip
cd legacy-source
npm ci
npm run dev
```

The earlier source is included for reference and development. Its build does not reproduce the newer live-order site exactly.

## Deployment and database

Unzip the current export and publish the **contents** of `site/` as the static site's root. Do not publish `database/` or `legacy-source/` as web assets. The database SQL should be applied separately in Supabase only after review. The client bundle contains the public Supabase URL and anonymous key needed by the deployed app; never add a Supabase service-role key or other private credentials to this repository.

The live site's behavior depends on the configured Supabase project and authentication settings. This archive does not include a backend server or the original editable Next.js source. If you have that source, add it as a later commit and move the compiled export to a release artifact.
