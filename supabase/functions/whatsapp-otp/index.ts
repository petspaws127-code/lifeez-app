// supabase/functions/whatsapp-otp/index.ts
//
// Sends + verifies WhatsApp login codes via the WhatsApp Business Cloud API.
//
// Deploy:  supabase functions deploy whatsapp-otp
// Secrets: supabase secrets set WHATSAPP_TOKEN=... WHATSAPP_PHONE_NUMBER_ID=...
//   (WHATSAPP_TOKEN = Meta System User token with whatsapp_business_messaging)
// Meta setup: create a message template (e.g. "otp_code") with a {{1}}
//   body parameter, then put its name in OTP_TEMPLATE_NAME below.
//
// Flow:
//   1. App → {action:"send", phone} → code sent over WhatsApp, hash stored.
//   2. App → {action:"verify", phone, code} → on success returns a
//      magic-link token_hash; the Flutter app redeems it with
//      supabase.auth.verifyOtp(...) to establish a real session.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const WHATSAPP_TOKEN = Deno.env.get("WHATSAPP_TOKEN")!; // TODO: set secret
const PHONE_NUMBER_ID = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID")!; // TODO: set secret
const OTP_TEMPLATE_NAME = "TODO_YOUR_OTP_TEMPLATE_NAME"; // TODO: Meta template name

const json = (obj: unknown, status = 200) =>
  new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json" },
  });

async function sha256Hex(s: string): Promise<string> {
  const buf = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(s),
  );
  return [...new Uint8Array(buf)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  const { action, phone, code } = await req.json();
  if (!phone) return json({ error: "phone is required" }, 400);

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);

  if (action === "send") {
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();
    const { error: dbErr } = await supabase.from("whatsapp_otps").upsert({
      phone,
      code_hash: await sha256Hex(otp),
      expires_at: expiresAt,
    });
    if (dbErr) return json({ error: dbErr.message }, 500);

    const waRes = await fetch(
      `https://graph.facebook.com/v21.0/${PHONE_NUMBER_ID}/messages`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${WHATSAPP_TOKEN}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          messaging_product: "whatsapp",
          to: phone,
          type: "template",
          template: {
            name: OTP_TEMPLATE_NAME,
            language: { code: "en_US" },
            components: [
              {
                type: "body",
                parameters: [{ type: "text", text: otp }],
              },
            ],
          },
        }),
      },
    );
    if (!waRes.ok) {
      return json({ error: `WhatsApp send failed: ${await waRes.text()}` }, 502);
    }
    return json({ ok: true });
  }

  if (action === "verify") {
    const { data } = await supabase
      .from("whatsapp_otps")
      .select()
      .eq("phone", phone)
      .eq("code_hash", await sha256Hex(code ?? ""))
      .gt("expires_at", new Date().toISOString())
      .maybeSingle();
    if (!data) return json({ error: "Invalid or expired code." }, 401);
    await supabase.from("whatsapp_otps").delete().eq("phone", phone);

    // One auth user per WhatsApp number (synthetic email).
    const email = `${phone.replace(/[^0-9]/g, "")}@whatsapp.ailifeassistant.app`;
    const { data: listed } = await supabase.auth.admin.listUsers();
    let user = listed?.users.find((u) => u.email === email);
    if (!user) {
      const created = await supabase.auth.admin.createUser({
        email,
        email_confirm: true,
        user_metadata: { login_provider: "whatsapp", phone },
      });
      if (created.error || !created.data.user) {
        return json({ error: created.error?.message ?? "user create failed" }, 500);
      }
      user = created.data.user;
    }

    // Mint a one-time magic-link token; the app redeems it for a session.
    const link = await supabase.auth.admin.generateLink({
      type: "magiclink",
      email,
    });
    const actionLink = link.data?.properties?.action_link;
    if (link.error || !actionLink) {
      return json({ error: "Could not create session." }, 500);
    }
    const tokenHash = new URL(actionLink).searchParams.get("token_hash");
    return json({ ok: true, token_hash: tokenHash });
  }

  return json({ error: "Unknown action." }, 400);
});
