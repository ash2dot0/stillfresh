
export default {
  async fetch(req) {
    if (req.method !== 'POST') {
      return new Response('Only POST allowed', { status: 405 })
    }

    const body = await req.json()

    // Placeholder for OpenAI call
    return new Response(JSON.stringify({
      scan_group_id: body.scan_group_id,
      items: [],
      meta: { status: "worker alive" }
    }), {
      headers: { 'Content-Type': 'application/json' }
    })
  }
}
