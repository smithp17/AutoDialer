# README

Autodialer dashboard

Upload phone numbers in bulk, trigger “Call All Pending,” run per‑row calls, and execute a simple AI prompt action.​

Clean REST routes: collection actions for bulk_upload, call_all, ai_prompt; member action call_now.​

Dark, responsive UI with KPI cards and a sortable table.​

LinkedIn scraper (local Python)

“Scrape now” button posts to Rails; the server runs a Python script, captures stdout/stderr to a log file, and avoids storing large data in cookies.​

“Download JSON” streams the results using send_data for correctness and performance.​

Designed Python stack: Selenium WebDriver for authenticated navigation, BeautifulSoup (bs4) for parsing, requests/urllib3 for HTTP, pandas/json for shaping outputs.​

AI micro‑blog (/blog)

Paste up to 10 topics; generates ~30‑word micro posts via an OpenAI‑compatible Chat Completions endpoint at https://api.perplexity.ai.​

Valid models include sonar and sonar‑pro; configured via environment variables.​

Saves each post to app/blog/YYYY‑MM‑DD‑slug.md with YAML front matter (title = topic); renders Markdown with Redcarpet; per‑post Delete button via form‑based DELETE.​


SETUP

Install Ruby gems:

bundle install​

Configure environment:

Set PPLX_API_KEY and (optional) PPLX_MODEL (e.g., sonar or sonar‑pro).​

Start the server:

rails server and open http://localhost:3000​

Scraper dependencies (Python):

pip install selenium beautifulsoup4 requests pandas and ensure a local browser/WebDriver is available.​






This is my .env file format

TWILIO_ACCOUNT_SID=AC70734fa548*******8f462134b
TWILIO_AUTH_TOKEN=fa35f09844*********888882a
TWILIO_PHONE_NUMBER=+1 3198********8

PPLX_API_KEY=pplx-LQhQsgRcrwVtBkj******************gIuZsIh

PPLX_BASE_URL=https://api.perplexity.ai

PPLX_MODEL=sonar-pro


EMAIL=smit@eventbutterfly.com
PASSWORD=*******8