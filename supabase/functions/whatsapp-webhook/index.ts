// supabase/functions/whatsapp-webhook/index.ts
//
// Inbound WhatsApp webhook for the WhatsApp Business Cloud API.
//
// Meta dashboard → WhatsApp → Configuration → Webhook:
//   Callback URL: https://<your-supabase-ref>.supabase.co/functions/v1/whatsapp-webhook
//   Verify token: the WHATSAPP_VERIFY_TOKEN secret you set below.
//   Subscribe to the "messages" field.
//
// Deploy:  supabase functions deploy whatsapp-webhook
// Secrets: supabase secrets set WHATSAPP_VERIFY_TOKEN=... WHATSAPP_TOKEN=...
//          WHATSAPP_PHONE_NUMBER_ID=...
//
// TODO (to go live):
//   1. Parse entry[].changes[].value.messages[] for inbound text/audio.
//   2. Transcribe voice notes (e.g. Whisper API) — text comes as-is.
//   3. Dedupe with message_log.external_message_id (WhatsApp wamid).
//   4. Run the SAME intent parsing as the app's
//      lib/services/command_parser.dart (port the regexes or call an
//      LLM for intent classification), write the resulting rows
//      (tasks/expenses/bills/...) for the mapped user.
//   5. Reply to the user through the WhatsApp Cloud API send endpoint.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const VERIFY_TOKEN = Deno.env.get("WHATSAPP_VERIFY_TOKEN")!; // TODO: set secret
const WHATSAPP_TOKEN = Deno.env.get("WHATSAPP_TOKEN")!; // TODO: set secret
const PHONE_NUMBER_ID = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID")!; // TODO: set secret

async function reply(to: string, text: string) {
  await fetch(
    `https://graph.facebook.com/v21.0/${PHONE_NUMBER_ID}/messages`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${WHATSAPP_TOKEN}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        messaging_product: "whatsapp",
        to,
        type: "text",
        text: { body: text },
      }),
    },
  );
}

serve(async (req) => {
  const url = new URL(req.url);

  // --- Verification handshake (Meta calls this once when you subscribe)
  if (req.method === "GET") {
    const mode = url.searchParams.get("hub.mode");
    const token = url.searchParams.get("hub.verify_token");
    const challenge = url.searchParams.get("hub.challenge");
    if (mode === "subscribe" && token === VERIFY_TOKEN) {
      return new Response(challenge ?? "", { status: 200 });
    }
    return new Response("Forbidden", { status: 403 });
  }

  // --- Inbound events
  if (req.method === "POST") {
    const body = await req.json();
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);

    for (const entry of body.entry ?? []) {
      for (const change of entry.changes ?? []) {
        const value = change.value ?? {};
        for (const msg of value.messages ?? []) {
          const wamid: string | undefined = msg.id;
          const from: string | undefined = msg.from;
          const text: string | undefined =
            msg.text?.body ?? (msg.audio ? "[voice note]" : undefined);
          if (!wamid || !from || !text) continue;

          // Dedupe: never process the same WhatsApp message twice.
          const { data: seen } = await supabase
            .from("message_log")
            .select("id")
            .eq("external_message_id", wamid)
            .maybeSingle();
          if (seen) continue;

          // TODO: map `from` (phone) → user_id via whatsapp_connections,
          // parse intent (mirror lib/services/command_parser.dart),
          // write the data rows, then:
          await supabase.from("message_log").insert({
            user_id: null, // TODO: resolved user id
            direction: "in",
            body: text,
            intent: "TODO",
            external_message_id: wamid,
          });

          await reply(
            from,
            "Got it — I understood your message. (Full command handling is wired up next.)",
          );
        }
      }
    }
    return new Response("EVENT_RECEIVED", { status: 200 });
  }

  return new Response("Method not allowed", { status: 405 });
});
