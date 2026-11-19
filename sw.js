// 하이클린 업무관리 · 앱 설치용 서비스 워커
// 화면이나 자료를 저장(캐시)하지 않습니다. 항상 최신 화면과 자료를 서버에서 받아 옵니다.
// 인터넷이 끊겼을 때만 안내 화면을 보여 줍니다.
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (e) => e.waitUntil(self.clients.claim()));
self.addEventListener("fetch", (e) => {
  if (e.request.mode !== "navigate") return;
  e.respondWith(
    fetch(e.request).catch(() =>
      new Response(
        '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>하이클린 업무관리</title>' +
          '<body style="font-family:sans-serif;display:grid;place-items:center;min-height:90vh;text-align:center;color:#333">' +
          '<div><h2>인터넷에 연결되어 있지 않습니다</h2><p>연결을 확인한 뒤 다시 시도해 주세요.</p>' +
          '<button onclick="location.reload()" style="padding:10px 24px;font-size:16px;border:0;border-radius:8px;background:#1f5fae;color:#fff">다시 시도</button></div></body>',
        { headers: { "Content-Type": "text/html; charset=utf-8" } }
      )
    )
  );
});
