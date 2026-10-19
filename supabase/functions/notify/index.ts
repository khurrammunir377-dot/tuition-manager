import { SignJWT, importPKCS8 } from "npm:jose@5";
import { createClient } from "npm:@supabase/supabase-js@2";

const sa = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!);
const sb = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

let cached: { t: string; exp: number } | null = null;

async function accessToken(): Promise<string> {
  if (cached && cached.exp > Date.now()) return cached.t;
  const key = await importPKCS8(sa.private_key, "RS256");
  const jwt = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(sa.client_email)
    .setSubject(sa.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt()
    .setExpirationTime("55m")
    .sign(key);
  const r = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const j = await r.json();
  cached = { t: j.access_token, exp: Date.now() + 50 * 60 * 1000 };
  return cached.t;
}

async function sendAll(code: string, title: string, bodies: string[]) {
  if (bodies.length === 0) return "no event";
  const { data: toks } = await sb
    .from("push_tokens")
    .select("token")
    .eq("code", code);
  if (!toks?.length) return "no tokens";
  const at = await accessToken();
  for (const { token } of toks) {
    for (const body of bodies) {
      const r = await fetch(
        `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${at}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: { token, notification: { title, body } },
          }),
        },
      );
      if (r.status === 404 || r.status === 400) {
        // پرانا یا غلط ٹوکن صاف کریں
        await sb.from("push_tokens").delete().eq("token", token);
        break;
      }
    }
  }
  return "sent";
}

Deno.serve(async (req) => {
  if (req.headers.get("x-webhook-secret") !== Deno.env.get("WEBHOOK_SECRET")) {
    return new Response("unauthorized", { status: 401 });
  }
  const payload = await req.json();
  const { record, old_record } = payload;

  // ٹیچر نے سوال کا جواب دیا
  if (payload.table === "questions") {
    return new Response(await sendAll(record.code, "ٹیچر کا جواب", [record.a]));
  }

  const n = record.data ?? {};
  const o = old_record?.data ?? {};
  const title = record.center || "ٹیوشن";
  const name = n.name;
  const sameDay = o.today === n.today;
  const bodies: string[] = [];

  const oldAtt = sameDay ? o.att : null;
  if (n.att !== null && n.att !== undefined && n.att !== oldAtt) {
    bodies.push(n.att ? `${name} آج حاضر ہے ✅` : `${name} آج غیر حاضر ہے`);
  }
  const oldNote = sameDay ? (o.note ?? "") : "";
  if (n.note && n.note !== oldNote) {
    bodies.push(`${name}: آج کا سبق - ${n.note}`);
  }
  const oldPaid = o.month === n.month ? !!o.paid : false;
  if (n.paid && !oldPaid) bodies.push(`${name} کی فیس وصول ہو گئی ✅`);
  else if (!n.paid && o.month === n.month && typeof o.rem === "number" && n.rem < o.rem) {
    bodies.push(`${name}: قسط وصول ہوئی، باقی ${n.rem} روپے`);
  }

  const nt = n.tests?.[0];
  if (nt && JSON.stringify(nt) !== JSON.stringify(o.tests?.[0])) {
    bodies.push(`${name}: ${nt.name} - ${nt.got}/${nt.total}`);
  }
  const nh = n.hw?.[0];
  if (nh && nh.url !== o.hw?.[0]?.url) {
    bodies.push(`${name}: آج کا ہوم ورک لگ گیا`);
  }
  const newFirst = n.notices?.[0];
  const oldFirst = o.notices?.[0];
  if (newFirst && JSON.stringify(newFirst) !== JSON.stringify(oldFirst)) {
    bodies.push(newFirst.t);
  }
  return new Response(await sendAll(record.code, title, bodies));
});
