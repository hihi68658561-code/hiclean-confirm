// 하이클린 업무관리 · 문자 보내기 (솔라피)
// Supabase > Edge Functions 에 이름 'send-sms' 로 배포합니다.
// 필요한 비밀 값(Edge Functions > Secrets): SOLAPI_API_KEY, SOLAPI_API_SECRET, SOLAPI_SENDER(등록된 발신번호, 숫자만)
// 카카오 알림톡(선택): SOLAPI_PFID(솔라피에 연결한 카카오 채널 pfId), SOLAPI_TPL_VISIT(승인된 '방문 안내' 템플릿 ID)
// 이미지 첨부(MMS): 요청에 image:{data:"<JPG base64>"}가 있으면 그림문자로 보냅니다 (JPG, 200KB 이하).
//   두 값이 있으면 kakao:{template:"visit"}가 붙은 메시지는 알림톡으로 보내고, 실패하면 같은 내용을 문자로 대신 보냅니다.
import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...CORS, "Content-Type": "application/json" } });

const hex = (buf: ArrayBuffer) => [...new Uint8Array(buf)].map((x) => x.toString(16).padStart(2, "0")).join("");
async function solapiAuth(key: string, secret: string) {
  const date = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
  const salt = hex(crypto.getRandomValues(new Uint8Array(16)).buffer);
  const k = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = hex(await crypto.subtle.sign("HMAC", k, new TextEncoder().encode(date + salt)));
  return `HMAC-SHA256 apiKey=${key}, date=${date}, salt=${salt}, signature=${sig}`;
}
// 한글 2바이트 기준 길이 (SMS 90바이트 / LMS 2000바이트)
const bytes = (s: string) => [...s].reduce((a, ch) => a + (ch.charCodeAt(0) > 127 ? 2 : 1), 0);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "POST만 됩니다" }, 405);
  const KEY = Deno.env.get("SOLAPI_API_KEY"), SECRET = Deno.env.get("SOLAPI_API_SECRET");
  const FROM = (Deno.env.get("SOLAPI_SENDER") || "").replace(/\D/g, "");
  if (!KEY || !SECRET || !FROM) return json({ error: "문자 설정(SOLAPI_API_KEY·SOLAPI_API_SECRET·SOLAPI_SENDER)이 없습니다" }, 500);

  // 로그인한 직원의 권한으로만 동작 (비밀 키를 쓰지 않음). 프로그램이 보낸 공개 키(apikey)와 로그인 토큰 사용
  const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  const apikey = req.headers.get("apikey") || Deno.env.get("SUPABASE_ANON_KEY") || "";
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, apikey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  // 보낸 사람 확인: 로그인한 직원만
  const { data: u } = await admin.auth.getUser(token);
  if (!u?.user) return json({ error: "로그인이 필요합니다" }, 401);
  const { data: st } = await admin.from("staff").select("name,role,active").eq("user_id", u.user.id).maybeSingle();
  if (!st || !st.active) return json({ error: "문자를 보낼 권한이 없습니다" }, 403);

  let body: { probe?: boolean; image?: { data?: string; name?: string }; messages?: { to: string; text: string; subject?: string; customer_id?: string; ref_type?: string; ref_id?: string; kakao?: { template?: string; variables?: Record<string, string> } }[] };
  try { body = await req.json(); } catch { return json({ error: "잘못된 요청입니다" }, 400); }
  // 프로그램이 '이미지 첨부(MMS)를 지원하는 버전인지' 물어볼 때
  if (body.probe) return json({ ok: true, v: 2, mms: true });
  const list = (body.messages || []).map((m) => ({ ...m, to: String(m.to || "").replace(/\D/g, ""), text: String(m.text || "").trim() }));
  if (!list.length) return json({ error: "보낼 문자가 없습니다" }, 400);
  if (list.length > 200) return json({ error: "한 번에 200건까지 보낼 수 있습니다" }, 400);
  for (const m of list) {
    if (!/^0\d{8,10}$/.test(m.to)) return json({ error: `받는 번호가 올바르지 않습니다: ${m.to || "(없음)"}` }, 400);
    if (!m.text) return json({ error: "문자 내용이 비어 있습니다" }, 400);
    if (bytes(m.text) > 2000) return json({ error: "문자 내용이 너무 깁니다 (2000바이트 이하)" }, 400);
  }

  // 이미지 첨부(MMS): JPG 200KB 이하 한 장. 솔라피 저장소에 올린 뒤 받은 fileId를 문자에 붙인다
  let imageId = "";
  if (body.image?.data) {
    const b64 = String(body.image.data).replace(/^data:[^,]*,/, "").replace(/\s+/g, "");
    if (!/^\/9j\//.test(b64)) return json({ error: "이미지는 JPG만 보낼 수 있습니다" }, 400);
    if (b64.length * 0.75 > 200 * 1024) return json({ error: "이미지가 너무 큽니다 (200KB 이하)" }, 400);
    try {
      const up = await fetch("https://api.solapi.com/storage/v1/files", {
        method: "POST",
        headers: { Authorization: await solapiAuth(KEY, SECRET), "Content-Type": "application/json" },
        body: JSON.stringify({ file: b64, type: "MMS", name: String(body.image.name || "image.jpg").slice(0, 100) }),
      });
      const uo = await up.json().catch(() => ({}));
      if (!up.ok || !uo?.fileId) return json({ error: "이미지를 올리지 못했습니다: " + (uo?.errorMessage || uo?.errorCode || `HTTP ${up.status}`) }, 502);
      imageId = uo.fileId;
    } catch (e) {
      return json({ error: "이미지를 올리지 못했습니다: " + String(e) }, 502);
    }
  }

  const PFID = Deno.env.get("SOLAPI_PFID") || "";
  const TPL: Record<string, string> = { visit: Deno.env.get("SOLAPI_TPL_VISIT") || "" };
  const messages = list.map((m) => {
    const lms = bytes(m.text) > 90;
    const tid = m.kakao?.template ? TPL[m.kakao.template] : "";
    if (imageId) return { to: m.to, from: FROM, text: m.text, type: "MMS", imageId, subject: (m.subject || "하이클린").slice(0, 20) };
    if (PFID && tid) {
      // 알림톡: 실패하면 text 내용으로 문자 대체 발송 (disableSms: false)
      const variables: Record<string, string> = {};
      for (const [k, v] of Object.entries(m.kakao?.variables || {})) variables[`#{${k}}`] = String(v ?? "");
      return { to: m.to, from: FROM, text: m.text, type: "ATA", kakaoOptions: { pfId: PFID, templateId: tid, variables, disableSms: false } };
    }
    return { to: m.to, from: FROM, text: m.text, type: lms ? "LMS" : "SMS", ...(lms ? { subject: (m.subject || "하이클린").slice(0, 20) } : {}) };
  });
  let res: Response, out: any;
  try {
    res = await fetch("https://api.solapi.com/messages/v4/send-many/detail", {
      method: "POST",
      headers: { Authorization: await solapiAuth(KEY, SECRET), "Content-Type": "application/json" },
      body: JSON.stringify({ messages }),
    });
    out = await res.json().catch(() => ({}));
  } catch (e) {
    return json({ error: "문자 회사에 연결하지 못했습니다: " + String(e) }, 502);
  }
  const failed: Record<string, string> = {};
  if (!res.ok) list.forEach((m) => (failed[m.to] = out?.errorMessage || out?.errorCode || `HTTP ${res.status}`));
  for (const f of out?.failedMessageList || []) failed[String(f.to || "").replace(/\D/g, "")] = f.statusMessage || f.statusCode || "실패";
  const groupId = out?.groupInfo?.groupId || "";

  const rows = list.map((m, i) => ({
    customer_id: m.customer_id || null, ref_type: m.ref_type || "", ref_id: m.ref_id || null,
    to_phone: m.to, from_phone: FROM, content: m.text, msg_type: messages[i].type,
    status: failed[m.to] ? "실패" : "접수", error: failed[m.to] || "", group_id: groupId,
    by_name: st.name || "", created_by: u.user.id,
  }));
  const { error: logErr } = await admin.from("sms_logs").insert(rows);
  if (logErr) console.error("sms_logs insert", logErr.message);
  const nf = rows.filter((r) => r.status === "실패").length;
  return json({ ok: nf === 0, mms: !!imageId, sent: rows.length - nf, failed: rows.filter((r) => r.status === "실패").map((r) => ({ to: r.to_phone, error: r.error })) }, res.ok ? 200 : 502);
});
