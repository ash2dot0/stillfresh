export default {
  async fetch(request, env) {
    return new Response(
      JSON.stringify({ status: "stillfresh worker alive" }),
      { headers: { "Content-Type": "application/json" } }
    )
  }
}
