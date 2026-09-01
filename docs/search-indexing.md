# Search indexing runbook

The canonical project site is:

`https://mahdihedhli.github.io/BlackOmarchy/`

Crawler endpoints:

- Sitemap: `https://mahdihedhli.github.io/BlackOmarchy/sitemap.xml`
- Robots: `https://mahdihedhli.github.io/BlackOmarchy/robots.txt`

## Google Search Console

1. Add a **URL-prefix property** for the canonical project-site URL above.
2. Choose HTML-file or HTML-tag verification.
   - For HTML-file verification, add Google's supplied file unchanged to `docs/`.
   - For HTML-tag verification, add Google's supplied meta element to `docs/index.html`.
3. After the verification change is published, submit `sitemap.xml` under **Sitemaps**.
4. Inspect the canonical homepage URL and select **Request indexing**.

Official guidance:
[Ask Google to recrawl a site](https://developers.google.com/search/docs/crawling-indexing/ask-google-to-recrawl).

## Bing Webmaster Tools

The simplest path is **Import from Google Search Console** after Google
verification. Otherwise, add the site directly and use Bing's supplied XML
file or meta tag in the same way described above.

After verification, submit the sitemap and the canonical homepage URL.
IndexNow is optional for this small, low-frequency static site.

Official guidance:
[Submit URLs to Bing](https://www.bing.com/webmasters/help/URL-Submission-62f2860b)
and [submit a sitemap](https://www.bing.com/webmasters/help/sitemaps-3b5cf6ed).

## Maintenance

- Update `sitemap.xml` when the canonical URL changes or separately indexable
  HTML pages are added.
- Update `<lastmod>` only when the public page changes materially.
- Keep the canonical, Open Graph URL, sitemap, robots file, manifest start URL,
  and GitHub repository homepage aligned.
- Do not add fake verification tokens. Search-engine verification values are
  account-specific and should be committed only after the provider issues them.
