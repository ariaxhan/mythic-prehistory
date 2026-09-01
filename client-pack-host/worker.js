export default {
  async fetch(request, env) {
    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response("Method not allowed", {
        status: 405,
        headers: { Allow: "GET, HEAD" },
      });
    }

    const url = new URL(request.url);
    const key = decodeURIComponent(url.pathname.replace(/^\/+/, "")) || "pack.toml";
    if (key.includes("..") || key.startsWith("/")) {
      return new Response("Invalid path", { status: 400 });
    }

    const object = request.method === "HEAD" ? await env.PACK.head(key) : await env.PACK.get(key);
    if (!object) return new Response("Not found", { status: 404 });

    const headers = new Headers();
    object.writeHttpMetadata(headers);
    headers.set("etag", object.httpEtag);
    headers.set("cache-control", "public, no-cache");
    headers.set("x-content-type-options", "nosniff");
    return new Response(request.method === "HEAD" ? null : object.body, { headers });
  },
};
