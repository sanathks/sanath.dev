import type { APIRoute } from "astro";

const getSitemapIndex = (sitemapUrl: URL) => `<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <sitemap>
    <loc>${sitemapUrl.href}</loc>
  </sitemap>
</sitemapindex>`;

export const GET: APIRoute = ({ site }) => {
  const sitemapUrl = new URL("sitemap-0.xml", site);
  return new Response(getSitemapIndex(sitemapUrl), {
    headers: {
      "Content-Type": "application/xml; charset=utf-8",
    },
  });
};
