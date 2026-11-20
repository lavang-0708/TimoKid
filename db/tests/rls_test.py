"""Kiểm thử phân quyền theo gia đình (RLS) trên Neon Data API thật.

Tạo (hoặc đăng nhập lại) 2 tài khoản thử A và B qua Neon Auth, lấy JWT,
rồi gọi Data API để chứng minh:
- A tạo được gia đình, bé, lượt trả lời, ví, cài đặt, thư của mình.
- B không đọc, không sửa, không ghi được dữ liệu của A (kể cả khi đoán
  đúng id).
- attempts / wallet_ledger không sửa, không xóa được.
- Gửi lại cùng lô (cùng id) không tạo dòng trùng.
- Dòng cũ hơn không ghi đè dòng mới hơn (updated_at).
- claim_message chỉ trả quà một lần.
- Không có JWT thì không đọc được gì.

Chạy: TIMOKID_AUTH_URL=... TIMOKID_API_URL=... python3 db/tests/rls_test.py
(mặc định dùng URL của project `timokid`). Mật khẩu tài khoản thử đọc từ
biến môi trường TIMOKID_TEST_PASSWORD; không có thì sinh ngẫu nhiên và
tạo tài khoản mới mỗi lần chạy.
"""
import json
import os
import secrets
import sys
import urllib.error
import urllib.request
import uuid

AUTH = os.environ.get(
    "TIMOKID_AUTH_URL",
    "https://ep-damp-waterfall-a1cu82wt.neonauth.ap-southeast-1.aws.neon.tech/timokid/auth",
)
API = os.environ.get(
    "TIMOKID_API_URL",
    "https://ep-damp-waterfall-a1cu82wt.apirest.ap-southeast-1.aws.neon.tech/timokid/rest/v1",
)
ORIGIN = "http://localhost:5173"
FAILS = []


def http(method, url, body=None, headers=None):
    data = json.dumps(body).encode() if body is not None else None
    h = {"Content-Type": "application/json", "Origin": ORIGIN}
    h.update(headers or {})
    req = urllib.request.Request(url, data, h, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.read().decode()
            return r.status, (json.loads(raw) if raw else None), r.headers
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw), e.headers
        except ValueError:
            return e.code, raw, e.headers


def login(tag):
    """Đăng ký tài khoản mới (email ngẫu nhiên) rồi lấy JWT."""
    email = f"rls-{tag}-{secrets.token_hex(4)}@example.com"
    pw = os.environ.get("TIMOKID_TEST_PASSWORD") or secrets.token_urlsafe(16)
    st, body, hdr = http("POST", f"{AUTH}/sign-up/email",
                         {"email": email, "password": pw, "name": f"RLS {tag}"})
    assert st == 200, (st, body)
    cookie = "; ".join(
        c.split(";")[0] for c in hdr.get_all("Set-Cookie") or [])
    st, body, _ = http("GET", f"{AUTH}/token", headers={"Cookie": cookie})
    assert st == 200 and body.get("token", "").count(".") == 2, (st, body)
    return body["token"]


def api(tok, method, path, body=None, prefer=None):
    h = {}
    if tok:
        h["Authorization"] = f"Bearer {tok}"
    if prefer:
        h["Prefer"] = prefer
    return http(method, f"{API}/{path}", body, h)


def check(name, cond, detail=""):
    print(("OK   " if cond else "FAIL ") + name + ("" if cond else f"  -> {detail}"))
    if not cond:
        FAILS.append(name)


def main():
    a, b = login("a"), login("b")
    now = "2026-11-21T08:00:00+07:00"

    st, fam_a, _ = api(a, "POST", "rpc/ensure_family", {"p_display_name": "Nhà A"})
    check("A tạo gia đình", st == 200 and fam_a.get("id"), (st, fam_a))
    st, fam_b, _ = api(b, "POST", "rpc/ensure_family", {"p_display_name": "Nhà B"})
    check("B tạo gia đình", st == 200 and fam_b["id"] != fam_a["id"], (st, fam_b))
    st, again, _ = api(a, "POST", "rpc/ensure_family", {})
    check("ensure_family gọi lại trả đúng gia đình cũ", again["id"] == fam_a["id"], again)

    child = str(uuid.uuid4())
    st, body, _ = api(a, "POST", "children",
                      {"id": child, "name": "Bé A", "grade": 2,
                       "created_at": now, "updated_at": now})
    check("A tạo hồ sơ bé", st == 201, (st, body))

    st, body, _ = api(b, "POST", "children",
                      {"id": str(uuid.uuid4()), "family_id": fam_a["id"], "name": "Chen",
                       "created_at": now, "updated_at": now})
    check("B không tạo được bé trong gia đình A", st in (401, 403), (st, body))

    att = {"id": str(uuid.uuid4()), "child_id": child, "form_id": "logic.age",
           "strand": "logic", "level": 1, "rung": 1, "answer_type": "choice",
           "correct_first_try": True, "attempts_count": 1, "duration_ms": 5000,
           "created_at": now}
    pref = "resolution=ignore-duplicates,return=minimal"
    st, body, _ = api(a, "POST", "attempts?on_conflict=id", [att], pref)
    check("A gửi lượt trả lời", st == 201, (st, body))
    st, body, _ = api(a, "POST", "attempts?on_conflict=id", [att], pref)
    st2, rows, _ = api(a, "GET", f"attempts?child_id=eq.{child}&select=id")
    check("gửi lại cùng lô không tạo dòng trùng", st == 201 and len(rows) == 1, (st, rows))

    st, body, _ = api(a, "PATCH", f"attempts?id=eq.{att['id']}", {"duration_ms": 1})
    check("attempts không sửa được", st in (401, 403), (st, body))
    st, body, _ = api(a, "DELETE", f"attempts?id=eq.{att['id']}")
    check("attempts không xóa được", st in (401, 403), (st, body))

    led = {"id": str(uuid.uuid4()), "child_id": child, "currency": "xu",
           "amount": 10, "reason": "answer_first_try", "created_at": now}
    st, body, _ = api(a, "POST", "wallet_ledger?on_conflict=id", [led], pref)
    check("A ghi ví", st == 201, (st, body))
    st, body, _ = api(a, "PATCH", f"wallet_ledger?id=eq.{led['id']}", {"amount": 9999})
    check("wallet_ledger không sửa được", st in (401, 403), (st, body))

    for table in ("children", "attempts", "wallet_ledger", "child_balances", "child_daily_stats"):
        st, rows, _ = api(b, "GET", f"{table}?select=*")
        check(f"B không thấy {table} của A", st == 200 and rows == [], (st, rows))
    st, rows, _ = api(b, "GET", "families?select=*")
    check("B chỉ thấy gia đình của mình", st == 200 and [r["id"] for r in rows] == [fam_b["id"]], rows)

    st, body, _ = api(b, "POST", "attempts?on_conflict=id",
                      [dict(att, id=str(uuid.uuid4()))], pref)
    check("B không ghi được lượt trả lời cho bé của A", st in (401, 403), (st, body))
    st, body, _ = api(b, "PATCH", f"children?id=eq.{child}", {"name": "Hack"}, "return=representation")
    check("B không sửa được bé của A", st == 200 and body == [], (st, body))

    sp = {"id": str(uuid.uuid4()), "child_id": child, "scope": "strand", "key": "logic",
          "rung": 3, "created_at": now, "updated_at": "2026-11-21T09:00:00+07:00"}
    up = "resolution=merge-duplicates,return=minimal"
    api(a, "POST", "skill_progress?on_conflict=id", [sp], up)
    api(a, "POST", "skill_progress?on_conflict=id",
        [dict(sp, rung=1, updated_at="2026-11-21T08:30:00+07:00")], up)
    st, rows, _ = api(a, "GET", f"skill_progress?id=eq.{sp['id']}&select=rung")
    check("dòng cũ hơn không ghi đè dòng mới hơn", rows == [{"rung": 3}], rows)
    api(a, "POST", "skill_progress?on_conflict=id",
        [dict(sp, rung=4, updated_at="2026-11-21T10:00:00+07:00")], up)
    st, rows, _ = api(a, "GET", f"skill_progress?id=eq.{sp['id']}&select=rung")
    check("dòng mới hơn ghi đè được", rows == [{"rung": 4}], rows)

    st, body, _ = api(a, "POST", "settings",
                      {"child_id": child, "key": "answer_type_lock", "value": {"logic": "number"}},
                      "return=representation")
    check("A ghi cài đặt cho bé", st == 201, (st, body))
    st, rows, _ = api(b, "GET", "settings?select=*")
    check("B không thấy cài đặt của A", rows == [], rows)

    st, msg, _ = api(a, "POST", "messages",
                     {"child_id": child, "body": "Bố thưởng con", "gift_xu": 50},
                     "return=representation")
    check("A gửi thư có quà", st == 201, (st, msg))
    mid = msg[0]["id"]
    st, r1, _ = api(b, "POST", "rpc/claim_message", {"p_message_id": mid})
    check("B không nhận được quà của A", st >= 400, (st, r1))
    st, r1, _ = api(a, "POST", "rpc/claim_message", {"p_message_id": mid})
    st, r2, _ = api(a, "POST", "rpc/claim_message", {"p_message_id": mid})
    check("quà chỉ nhận một lần",
          r1 and r1[0]["claimed"] is True and r1[0]["gift_xu"] == 50
          and r2 and r2[0]["claimed"] is False and r2[0]["gift_xu"] == 0, (r1, r2))

    st, body, _ = api(None, "GET", "children?select=*")
    check("không có JWT thì không đọc được", st in (401, 403) or body == [], (st, body))

    print(f"\n{len(FAILS)} lỗi")
    sys.exit(1 if FAILS else 0)


if __name__ == "__main__":
    main()
