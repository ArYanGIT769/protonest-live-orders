# PROTONEST — Live Engineering Orders

[Live Website](https://protonest-live-orders.netlify.app/)

## Overview

PROTONEST is a digital engineering-services platform for handling customer enquiries, technical-file submissions, quotations, and live production-order updates from one place.

## Key Features

- Customer sign-up and secure account access
- Engineering-service selection and technical-file submission
- Order quotation and production-status tracking
- Customer dashboard for orders and updates
- Admin dashboard for managing submitted orders
- Contact workflow through email and WhatsApp

## Technology

- Next.js static web export
- Supabase for authentication and database workflows
- HTML, CSS and JavaScript
- Netlify deployment

## Repository Structure

- `site/` — deployed static website build, including homepage, customer account, admin pages, CSS and JavaScript assets
- `PROTONEST-SUPABASE-SETUP.sql` — database schema, policies and setup
- `PROTONEST-current-static-export.zip` — backup of the deployed website files

## Run Locally

```bash
cd site
python -m http.server 8000
