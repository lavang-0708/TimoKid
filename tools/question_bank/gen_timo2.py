# -*- coding: utf-8 -*-
"""Sinh thêm dạng bài TIMO lớp 2, rút từ đề thật (song ngữ Việt - Anh).

Nguồn dạng bài (chỉ lấy DẠNG, số và lời văn tự soạn lại):
  - Đề vòng loại TIMO lớp 2 năm 2026–2027, ca 1 và ca 2 (bản tổng hợp theo trí
    nhớ học sinh, mathx.vn).
  - 4 đề ôn vòng loại TIMO lớp 2 (mã câu 2.I.x … 2.V.x, codemath.vn).
Khuôn khổ lớp 2: số trong phạm vi 100 (dãy số tối đa 200), phép nhân chỉ trong
bảng 2–5, phép chia hết, không dùng số có 3–4 chữ số trong đề tổ hợp.

Mỗi dạng là một hàm sinh theo mức (1 Dễ, 2 Vừa, 3 Khó) và trả về `params`;
đáp án luôn do code tính. `check_timo2.py` giải lại độc lập bằng vét cạn từ
`params`. Chạy: python3 tools/question_bank/gen_timo2.py
"""
import json, os, random, itertools, math

R = random.Random(20261121)
NAMES = ["An", "Bình", "Chi", "Dũng", "Hà", "Lan", "Mai", "Minh", "Nam", "Ngọc",
         "Phương", "Quân", "Thảo", "Trang", "Tuấn", "Vy", "Linh", "Hùng", "Khoa", "My"]
DAYS_VI = ["Chủ nhật", "Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy"]
DAYS_EN = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
OUT = []
PER = 4  # số câu mẫu cho mỗi (dạng, mức)


def nm(k=1):
    return R.sample(NAMES, k)


def distract(ans, extra=()):
    out = []
    for c in list(extra) + [ans + d for d in (1, -1, 2, -2, 10, -10, 3, 5, 4)]:
        if c != ans and c >= 0 and c not in out:
            out.append(c)
    return out[:3]


SEEN = set()


def add(topic, form, diff, qvi, qen, ans, evi, een, hvi, hen, kw, params, wrong=(), choices=None):
    if qvi in SEEN:
        return
    SEEN.add(qvi)
    q = {"topic": topic, "form": form, "difficulty": diff,
         "question_vi": qvi, "question_en": qen, "hint_vi": hvi, "hint_en": hen,
         "explanation_vi": evi, "explanation_en": een,
         "keywords": [{"en": e, "vi": v} for e, v in kw], "figure_svg": None,
         "params": params,
         "source": "Dạng bài theo đề vòng loại TIMO lớp 2 (tự soạn số và lời)"}
    if choices is None:
        q["answer_type"], q["answer"], q["distractors"] = "number", ans, distract(ans, wrong)
    else:
        q["answer_type"] = "choice"
        q["choices"] = [{"vi": v, "en": e} for v, e in choices]
        q["answer"] = ans
    OUT.append(q)


def many(fn, diffs=(1, 2, 3), n=PER):
    for d in diffs:
        got = 0; tries = 0
        while got < n and tries < 300:
            tries += 1
            before = len(OUT)
            fn(d, key=fn(d, dry=True))
            got += len(OUT) - before


# ============================================================ TƯ DUY LÔGIC
def classsize(d, dry=False, key=None):
    """Có a bạn cao hơn X, b bạn thấp hơn X, c bạn cao bằng X → a+b+c+1."""
    if dry:
        lo, hi = {1: (3, 9), 2: (6, 15), 3: (10, 20)}[d]
        return (R.randint(lo, hi), R.randint(lo, hi), R.randint(0 if d == 1 else 1, 3))
    a, b, c = key
    x = nm()[0]
    ans = a + b + c + 1
    same_vi = f", {c} bạn cao bằng {x}" if c else ""
    same_en = f", and {c} classmates are as tall as {x}" if c else ""
    add("logic", "classsize", d,
        f"Trong lớp của {x}, có {a} bạn cao hơn {x}, {b} bạn thấp hơn {x}{same_vi}. Hỏi lớp có tất cả bao nhiêu học sinh?",
        f"In {x}'s class, {a} classmates are taller than {x}, {b} are shorter{same_en}. How many students are in the class?",
        ans, f"Số bạn khác {x}: {a} + {b} + {c} = {a+b+c}. Cộng thêm chính {x}: {a+b+c} + 1 = {ans} (học sinh).",
        f"Classmates other than {x}: {a} + {b} + {c} = {a+b+c}. Add {x}: {ans}.",
        f"Đừng quên đếm chính {x}.", f"Don't forget to count {x}.",
        [("taller", "cao hơn"), ("shorter", "thấp hơn"), ("same height", "cao bằng")],
        {"taller": a, "shorter": b, "same": c}, wrong=(a + b + c, a + b, ans + 1))


def weekday_rel(d, dry=False, key=None):
    """k ngày trước hôm nay là D; hỏi hôm qua / hôm kia / m ngày nữa là thứ mấy."""
    if dry:
        k = {1: R.randint(1, 3), 2: R.randint(4, 6), 3: R.randint(7, 13)}[d]
        ask = R.choice(["yesterday", "tomorrow"] + (["dayafter", "m"] if d == 3 else []))
        m = R.randint(3, 9) if ask == "m" else 0
        return (k, R.randint(0, 6), ask, m)
    k, dd, ask, m = key
    today = (dd + k) % 7
    shift = {"yesterday": -1, "tomorrow": 1, "dayafter": 2, "m": m}[ask]
    ans_day = (today + shift) % 7
    ask_vi = {"yesterday": "hôm qua", "tomorrow": "ngày mai", "dayafter": "ngày kia", "m": f"{m} ngày nữa"}[ask]
    ask_en = {"yesterday": "yesterday", "tomorrow": "tomorrow", "dayafter": "the day after tomorrow", "m": f"{m} days from today"}[ask]
    opts = [ans_day] + R.sample([x for x in range(7) if x != ans_day], 3)
    R.shuffle(opts)
    add("logic", "weekday_rel", d,
        f"Biết rằng {k} ngày trước hôm nay là {DAYS_VI[dd]}. Hỏi {ask_vi} là thứ mấy?",
        f"{k} days before today was {DAYS_EN[dd]}. What day of the week is {ask_en}?",
        opts.index(ans_day),
        f"Hôm nay = {DAYS_VI[dd]} + {k} ngày = {DAYS_VI[today]}. Vậy {ask_vi} là {DAYS_VI[ans_day]}.",
        f"Today = {DAYS_EN[dd]} + {k} days = {DAYS_EN[today]}. So {ask_en} is {DAYS_EN[ans_day]}.",
        "Tìm hôm nay là thứ mấy trước.", "Find today first.",
        [("days before", "ngày trước"), ("yesterday", "hôm qua"), ("tomorrow", "ngày mai")],
        {"before": k, "day": dd, "ask": ask, "m": m, "options": opts},
        choices=[(DAYS_VI[o], DAYS_EN[o]) for o in opts])


def order3(d, dry=False, key=None):
    """Ba (bốn) phép cân: tìm vật nặng nhất / nhẹ nhất."""
    if dry:
        n = 3 if d < 3 else 4
        return (tuple(R.sample(range(n), n)), R.choice(["max", "min"]), n)
    perm, ask, n = key  # perm[i] = hạng nặng của vật i (0 nhẹ nhất)
    obj_vi = ["bình xanh", "bình đỏ", "bình vàng", "bình tím"][:n]
    obj_en = ["blue vase", "red vase", "yellow vase", "purple vase"][:n]
    by = sorted(range(n), key=lambda i: perm[i])  # nhẹ → nặng
    facts = [(by[j + 1], by[j]) for j in range(n - 1)]  # (nặng hơn, nhẹ hơn)
    R.shuffle(facts)
    fv = ". ".join(f"{obj_vi[h].capitalize()} nặng hơn {obj_vi[l]}" for h, l in facts)
    fe = ". ".join(f"The {obj_en[h]} is heavier than the {obj_en[l]}" for h, l in facts)
    ans = by[-1] if ask == "max" else by[0]
    av, ae = ("nặng nhất", "heaviest") if ask == "max" else ("nhẹ nhất", "lightest")
    add("logic", "order3", d, f"{fv}. Hỏi chiếc bình nào {av}?", f"{fe}. Which vase is the {ae}?",
        ans, "Xếp theo thứ tự từ nặng đến nhẹ: " + " > ".join(obj_vi[i] for i in reversed(by)) + ".",
        "Order from heaviest: " + " > ".join(obj_en[i] for i in reversed(by)) + ".",
        "Nối các câu lại thành một hàng từ nặng đến nhẹ.", "Chain the facts into one order.",
        [("heavier", "nặng hơn"), (ae, av)], {"n": n, "rank": list(perm), "ask": ask, "facts": facts},
        choices=list(zip([o.capitalize() for o in obj_vi], obj_en)))


def seq_grow(d, dry=False, key=None):
    """Dãy có hiệu tăng dần (2, 6, 12, 20 …) hoặc giảm dần (50, 49, 47, 44 …)."""
    if dry:
        a0 = R.randint(1, 10) if d < 3 else R.randint(30, 60)
        dd0 = R.randint(1, 3); step = 1 if d == 1 else R.choice([1, 2])
        sign = 1 if d < 3 else -1
        tot = sum(dd0 + i * step for i in range(6))
        if sign < 0 and a0 - tot < 0:
            a0 = tot + R.randint(0, 10)
        return (a0, dd0, step, sign)
    a0, dd0, step, sign = key
    seq = [a0]; diff = dd0
    for _ in range(6):
        seq.append(seq[-1] + sign * diff); diff += step
    shown, ans = seq[:6], seq[6]
    diffs = [abs(seq[i + 1] - seq[i]) for i in range(6)]
    add("logic", "seq_grow", d, f"Tìm số tiếp theo của dãy: {', '.join(map(str, shown))}, ...",
        f"Find the next number: {', '.join(map(str, shown))}, ...", ans,
        f"Khoảng cách giữa hai số liền nhau là {', '.join(map(str, diffs[:5]))}: mỗi lần {'tăng' if step else ''} thêm {step}. Số tiếp theo cách {shown[-1]} là {diffs[5]}: {ans}.",
        f"The gaps are {', '.join(map(str, diffs[:5]))}, growing by {step}. Next gap {diffs[5]}: {ans}.",
        "Viết khoảng cách giữa các số liền nhau.", "Write down the gaps between neighbours.",
        [("sequence", "dãy số"), ("next", "tiếp theo")], {"seq": seq}, wrong=(shown[-1] + sign * diffs[4], ans + sign))


def interleave(d, dry=False, key=None):
    """Hai dãy xen kẽ: 50, 3, 45, 6, 40, 9 …"""
    if dry:
        a, da = R.randint(40, 60), R.choice([2, 3, 4, 5])
        b, db = R.randint(1, 5), R.choice([2, 3])
        return (a, da, b, db, R.choice([6, 7]) if d > 1 else 6)
    a, da, b, db, n = key
    seq = []
    for i in range(n + 1):
        seq.append(a - (i // 2) * da if i % 2 == 0 else b + (i // 2) * db)
    shown, ans = seq[:n], seq[n]
    add("logic", "interleave", d, f"Tìm số tiếp theo của dãy: {', '.join(map(str, shown))}, ...",
        f"Find the next number: {', '.join(map(str, shown))}, ...", ans,
        f"Đây là hai dãy xen kẽ: các số ở vị trí lẻ giảm dần {da}, các số ở vị trí chẵn tăng dần {db}. Số tiếp theo là {ans}.",
        f"Two sequences are mixed: odd places go down by {da}, even places go up by {db}. Next: {ans}.",
        "Tách các số ở vị trí lẻ và vị trí chẵn ra hai dãy.", "Split odd and even positions.",
        [("sequence", "dãy số"), ("alternate", "xen kẽ")], {"seq": seq, "n": n},
        wrong=(shown[-1] + db, shown[-1] - da))


def cyclepattern(d, dry=False, key=None):
    """Hình lặp lại theo chu kỳ: hình thứ n là hình gì / có bao nhiêu hình X trong n hình đầu."""
    if dry:
        L = {1: 3, 2: 4, 3: 5}[d]
        pat = tuple(R.choice("▲■●★") for _ in range(L))
        if len(set(pat)) < 2:
            pat = ("▲", "■") + pat[2:]
        ask = "nth" if d == 1 else R.choice(["nth", "count"])
        return (pat, R.randint(10, 25), ask)
    pat, n, ask = key
    L = len(pat)
    shown = " ".join(pat * 2)
    names_vi = {"▲": "tam giác", "■": "hình vuông", "●": "hình tròn", "★": "ngôi sao"}
    names_en = {"▲": "triangle", "■": "square", "●": "circle", "★": "star"}
    if ask == "nth":
        sym = pat[(n - 1) % L]
        opts = sorted(set("▲■●★"))
        add("logic", "cyclepattern", d, f"Các hình được xếp lặp lại theo quy luật: {shown} ... Hỏi hình thứ {n} là hình gì?",
            f"The shapes repeat: {shown} ... What is shape number {n}?", opts.index(sym),
            f"Mỗi nhóm có {L} hình. {n} = {L} × {(n-1)//L} + {(n-1)%L+1}, nên hình thứ {n} là hình thứ {(n-1)%L+1} của nhóm: {names_vi[sym]}.",
            f"Each group has {L} shapes. Shape {n} is position {(n-1)%L+1} in a group: {names_en[sym]}.",
            "Tìm xem một nhóm lặp lại có mấy hình.", "Find how many shapes are in one repeating group.",
            [("pattern", "quy luật"), ("repeat", "lặp lại")], {"pattern": list(pat), "n": n, "ask": ask},
            choices=[(f"{s} {names_vi[s]}", f"{s} {names_en[s]}") for s in opts])
    else:
        sym = max(set(pat), key=pat.count)
        full, rem = divmod(n, L)
        ans = full * pat.count(sym) + pat[:rem].count(sym)
        add("logic", "cyclepattern", d, f"Các hình được xếp lặp lại theo quy luật: {shown} ... Hỏi trong {n} hình đầu tiên có bao nhiêu {names_vi[sym]} {sym}?",
            f"The shapes repeat: {shown} ... How many {names_en[sym]}s {sym} are in the first {n} shapes?", ans,
            f"Mỗi nhóm {L} hình có {pat.count(sym)} {names_vi[sym]}. {n} hình = {full} nhóm và {rem} hình. Số {names_vi[sym]}: {full} × {pat.count(sym)} + {pat[:rem].count(sym)} = {ans}.",
            f"Each group of {L} has {pat.count(sym)}. {n} = {full} groups + {rem}. Total {ans}.",
            "Đếm theo từng nhóm lặp lại.", "Count group by group.",
            [("pattern", "quy luật"), ("first", "đầu tiên")], {"pattern": list(pat), "n": n, "ask": ask, "sym": sym},
            wrong=(full * pat.count(sym), ans + 1))


def laps(d, dry=False, key=None):
    """Mỗi lượt t phút, nghỉ r phút giữa hai lượt (không nghỉ sau lượt cuối)."""
    if dry:
        return (R.randint(2, 4) if d == 1 else R.randint(4, 8), R.choice([3, 5, 10]), R.choice([1, 2]))
    n, t, r = key
    x = nm()[0]
    ans = n * t + (n - 1) * r
    add("logic", "laps", d,
        f"{x} chạy {n} vòng quanh sân. Mỗi vòng chạy hết {t} phút, chạy xong mỗi vòng thì nghỉ {r} phút rồi mới chạy tiếp (chạy xong vòng cuối thì không nghỉ). Hỏi {x} mất tất cả bao nhiêu phút?",
        f"{x} runs {n} laps. Each lap takes {t} minutes, with a {r}-minute rest between laps (no rest after the last). How many minutes in total?",
        ans, f"Thời gian chạy: {n} × {t} = {n*t}. Số lần nghỉ: {n} − 1 = {n-1}, nghỉ {(n-1)*r} phút. Tổng: {ans} phút.",
        f"Running {n*t}, resting {n-1} times = {(n-1)*r}. Total {ans}.",
        "Số lần nghỉ ít hơn số vòng 1 lần.", "There is one fewer rest than laps.",
        [("lap", "vòng"), ("rest", "nghỉ")], {"n": n, "t": t, "r": r}, wrong=(n * (t + r), n * t))


# ============================================================ SỐ HỌC / ĐẠI SỐ
def altsum(d, dry=False, key=None):
    """a − (a−s) + (a−2t) − … : ghép cặp."""
    if dry:
        s = R.choice([2, 3])
        n = {1: 5, 2: 7, 3: 8}[d]
        a = R.randint(s * (n + 2), 50)
        return (a, s, n)
    a, s, n = key
    terms = [a - i * s for i in range(n)]
    expr = str(terms[0]) + "".join((" − " if i % 2 else " + ") + str(terms[i]) for i in range(1, n))
    ans = sum(t if i % 2 == 0 else -t for i, t in enumerate(terms))
    add("arith", "altsum", d, f"Tính nhanh: {expr} = ?", f"Calculate quickly: {expr.replace('−', '-')} = ?", ans,
        f"Ghép từng cặp (số trước trừ số sau), mỗi cặp bằng {s}. Có {n // 2} cặp" + (f" và còn số {terms[-1]}" if n % 2 else "") + f": kết quả {ans}.",
        f"Pair them: each pair is {s}. {n // 2} pairs" + (f" plus {terms[-1]}" if n % 2 else "") + f" = {ans}.",
        "Ghép hai số liền nhau thành một cặp.", "Group neighbours into pairs.",
        [("calculate quickly", "tính nhanh"), ("pair", "cặp")], {"terms": terms}, wrong=(ans + s, ans - s))


def runsum(d, dry=False, key=None):
    """Tổng dãy cách đều ngắn: 5+6+…+10, 2+4+…+18, 1+3+…+15 (ghép đầu–cuối)."""
    if dry:
        step = {1: 1, 2: R.choice([1, 2]), 3: 2}[d]
        n = {1: 6, 2: R.choice([6, 8]), 3: R.choice([8, 9])}[d]
        a = R.randint(1, 9) if step == 1 else R.choice([1, 2])
        return (a, step, n)
    a, step, n = key
    terms = [a + i * step for i in range(n)]
    ans = sum(terms)
    add("arith", "runsum", d, f"Tính nhanh: {' + '.join(map(str, terms))} = ?",
        f"Calculate quickly: {' + '.join(map(str, terms))} = ?", ans,
        f"Ghép số đầu với số cuối: {terms[0]} + {terms[-1]} = {terms[0]+terms[-1]}. Có {n // 2} cặp như vậy" + (f", còn số giữa {terms[n//2]}" if n % 2 else "") + f". Tổng: {ans}.",
        f"Pair first and last: {terms[0]+terms[-1]} each, {n // 2} pairs" + (f" plus {terms[n//2]}" if n % 2 else "") + f". Total {ans}.",
        "Ghép số đầu với số cuối, số thứ hai với số kế cuối …", "Pair the first with the last …",
        [("sum", "tổng"), ("calculate quickly", "tính nhanh")], {"terms": terms}, wrong=(ans - step, ans + 10))


def cryptarith(d, dry=False, key=None):
    """AB ± A = KQ, A ≠ B là chữ số; tìm B."""
    if dry:
        while True:
            A, B = R.randint(1, 9), R.randint(0, 9)
            op = "+" if d == 1 else R.choice(["+", "−"])
            res = (10 * A + B) + A if op == "+" else (10 * A + B) - A
            f = (lambda a, b: 10 * a + b + a) if op == "+" else (lambda a, b: 10 * a + b - a)
            sols = [(a, b) for a in range(1, 10) for b in range(10) if a != b and f(a, b) == res]
            if A != B and 10 <= res <= 99 and len(sols) == 1:
                return (A, B, op, res)
    A, B, op, res = key
    add("arith", "cryptarith", d,
        f"Biết A và B là hai chữ số khác nhau và số có hai chữ số AB {op} A = {res}. Hỏi B bằng mấy?",
        f"A and B are different digits and the 2-digit number AB {op.replace('−', '-')} A = {res}. Find B.",
        B, f"AB là số có chữ số hàng chục A, hàng đơn vị B. Thử A: chỉ có A = {A} cho AB = {10*A+B}, {10*A+B} {op} {A} = {res}. Vậy B = {B}.",
        f"Try each A: only A = {A} works, giving AB = {10*A+B}. So B = {B}.",
        "Chữ số hàng chục của kết quả gợi ý giá trị của A.", "The tens digit of the result hints at A.",
        [("digit", "chữ số"), ("different", "khác nhau")], {"A": A, "op": op, "res": res}, wrong=(A, res % 10))


def arrowchain(d, dry=False, key=None):
    """? → +a → −b → +c → kết quả. Tính ngược."""
    if dry:
        k = {1: 2, 2: 3, 3: 4}[d]
        start = R.randint(5, 40)
        ops = []; v = start
        for _ in range(k):
            o = R.choice(["+", "−"]); x = R.randint(3, 25)
            if o == "−" and v - x < 1:
                o = "+"
            if o == "+" and v + x > 99:
                o = "−"
            v = v + x if o == "+" else v - x
            ops.append((o, x))
        return (start, tuple(ops), v)
    start, ops, end = key
    chain = " → ".join(f"{o}{x}" for o, x in ops)
    back = " ".join(f"{'−' if o == '+' else '+'} {x}" for o, x in reversed(ops))
    add("arith", "arrowchain", d, f"Một số đi qua các phép tính theo mũi tên: ? → {chain} → {end}. Tìm số ở dấu ?",
        f"A number goes through: ? → {chain.replace('−', '-')} → {end}. Find ?.", start,
        f"Đi ngược từ {end} và làm phép tính ngược lại: {end} {back} = {start}.",
        f"Go backwards from {end} with the opposite operations: {start}.",
        "Đi ngược từ cuối lên, cộng thành trừ, trừ thành cộng.", "Work backwards: plus becomes minus.",
        [("arrow", "mũi tên"), ("backwards", "ngược lại")], {"ops": [list(t) for t in ops], "end": end},
        wrong=(end, start + 2 * ops[0][1]))


def signs(d, dry=False, key=None):
    """Điền + / − vào a _ b _ c _ d = kq (một cách duy nhất)."""
    if dry:
        while True:
            n = 4 if d < 3 else 5
            nums = [R.randint(10, 25)] + [R.randint(1, 9) for _ in range(n - 1)]
            sg = tuple(R.choice("+−") for _ in range(n - 1))
            v = nums[0] + sum(x if s == "+" else -x for s, x in zip(sg, nums[1:]))
            sols = [p for p in itertools.product("+−", repeat=n - 1)
                    if nums[0] + sum(x if s == "+" else -x for s, x in zip(p, nums[1:])) == v]
            if len(sols) == 1 and v > 0:
                return (tuple(nums), sg, v)
    nums, sg, v = key
    def fmt(p):
        return str(nums[0]) + "".join(f" {s} {x}" for s, x in zip(p, nums[1:])) + f" = {v}"
    wrongs = [p for p in itertools.product("+−", repeat=len(nums) - 1) if p != sg]
    opts = [sg] + R.sample(wrongs, 3); R.shuffle(opts)
    blank = str(nums[0]) + "".join(f" … {x}" for x in nums[1:]) + f" = {v}"
    add("arith", "signs", d, f"Điền dấu + hoặc − vào chỗ … để được phép tính đúng: {blank}",
        f"Fill in + or − to make it true: {blank}", opts.index(sg),
        f"Thử từng cách: chỉ có {fmt(sg)} là đúng.", f"Try each option: only {fmt(sg).replace('−', '-')} is correct.",
        "Tính thử từng đáp án.", "Check each option.", [("sign", "dấu"), ("correct", "đúng")],
        {"nums": list(nums), "value": v, "options": ["".join(o) for o in opts]},
        choices=[(fmt(o), fmt(o).replace("−", "-")) for o in opts])


def flowerx(d, dry=False, key=None):
    """✿ + ✿ − a = ✿ + b → ✿ = a + b (và biến thể ✿ + ✿ + ✿)."""
    if dry:
        k = 2 if d < 3 else 3
        return (k, R.randint(5, 25), R.randint(5, 25))
    k, a, b = key
    lhs = " + ".join(["✿"] * k)
    if k == 2:
        ans = a + b
        ex = f"Bớt một ✿ ở cả hai bên: ✿ − {a} = {b}, nên ✿ = {b} + {a} = {ans}."
    else:
        if (a + b) % 2:
            b += 1
        ans = (a + b) // 2
        ex = f"Bớt một ✿ ở cả hai bên: ✿ + ✿ − {a} = {b}, nên ✿ + ✿ = {a + b}, ✿ = {ans}."
    add("arith", "flowerx", d, f"Biết {lhs} − {a} = ✿ + {b}. Hỏi ✿ bằng bao nhiêu?",
        f"{lhs} - {a} = ✿ + {b}. What is ✿?", ans, ex, ex,
        "Bớt đi cùng một bông hoa ở hai bên dấu bằng.", "Take one flower away from both sides.",
        [("equal", "bằng nhau")], {"k": k, "a": a, "b": b}, wrong=(b - a if b > a else a - b, ans * 2))


def factor_out(d, dry=False, key=None):
    """2 × a + b × 2 + 2 × c … = 2 × (a + b + c …), bảng nhân 2–5."""
    if dry:
        m = {1: 2, 2: R.choice([2, 3]), 3: R.choice([3, 4, 5])}[d]
        n = 3 if d == 1 else 4
        while True:
            xs = tuple(R.randint(2, 15) for _ in range(n))
            if 10 <= sum(xs) <= 30 and m * sum(xs) <= 100:
                return (m, xs, tuple(R.choice([0, 1]) for _ in range(n)))
    m, xs, sides = key
    parts = [f"{m} × {x}" if s else f"{x} × {m}" for x, s in zip(xs, sides)]
    ans = m * sum(xs)
    add("arith", "factor_out", d, f"Tính nhanh: {' + '.join(parts)} = ?", f"Calculate quickly: {' + '.join(parts)} = ?", ans,
        f"Mỗi tích đều có thừa số {m}: {m} × ({' + '.join(map(str, xs))}) = {m} × {sum(xs)} = {ans}.",
        f"Each product has a factor {m}: {m} × {sum(xs)} = {ans}.",
        f"Tìm thừa số chung {m}.", f"Find the common factor {m}.",
        [("product", "tích"), ("factor", "thừa số")], {"m": m, "xs": list(xs)}, wrong=(sum(xs), ans + m))


# ============================================================ LÝ THUYẾT SỐ
def digitcond(d, dry=False, key=None):
    """Đếm số có 2 chữ số thỏa điều kiện về chữ số."""
    if dry:
        kind = {1: R.choice(["both_gt", "both_lt"]), 2: R.choice(["both_gt", "both_lt", "unit_lt"]), 3: R.choice(["unit_lt", "tens_gt_unit", "sum_eq"])}[d]
        k = {"both_gt": R.randint(5, 7), "both_lt": R.randint(3, 5), "unit_lt": R.randint(2, 5),
             "tens_gt_unit": 0, "sum_eq": R.randint(5, 12)}[kind]
        return (kind, k)
    kind, k = key
    nums = range(10, 100)
    f = {"both_gt": lambda n: n // 10 > k and n % 10 > k, "both_lt": lambda n: n // 10 < k and n % 10 < k,
         "unit_lt": lambda n: n % 10 < k, "tens_gt_unit": lambda n: n // 10 > n % 10,
         "sum_eq": lambda n: n // 10 + n % 10 == k}[kind]
    ans = sum(1 for n in nums if f(n))
    cv = {"both_gt": f"cả hai chữ số đều lớn hơn {k}", "both_lt": f"cả hai chữ số đều nhỏ hơn {k}",
          "unit_lt": f"chữ số hàng đơn vị nhỏ hơn {k}", "tens_gt_unit": "chữ số hàng chục lớn hơn chữ số hàng đơn vị",
          "sum_eq": f"tổng hai chữ số bằng {k}"}[kind]
    ce = {"both_gt": f"both digits are greater than {k}", "both_lt": f"both digits are less than {k}",
          "unit_lt": f"the units digit is less than {k}", "tens_gt_unit": "the tens digit is greater than the units digit",
          "sum_eq": f"the digit sum is {k}"}[kind]
    add("number", "digitcond", d, f"Có bao nhiêu số có hai chữ số mà {cv}?", f"How many 2-digit numbers have {ce}?", ans,
        f"Liệt kê theo chữ số hàng chục (hàng chục không được là 0). Có tất cả {ans} số.",
        f"List by the tens digit (not 0). There are {ans}.",
        "Hàng chục không thể là 0.", "The tens digit cannot be 0.", [("digit", "chữ số"), ("2-digit number", "số có hai chữ số")],
        {"kind": kind, "k": k}, wrong=(ans + (1 if kind == "both_lt" else 0) + 1, ans * 2 if ans < 40 else ans - 9))


def parity_ops(d, dry=False, key=None):
    """Trong 6 phép tính có bao nhiêu kết quả chẵn / lẻ."""
    if dry:
        ops = []
        for _ in range(6):
            o = R.choice(["+", "−"]); a = R.randint(11, 70); b = R.randint(3, 40 if o == "+" else a - 1)
            ops.append((a, o, b))
        return (tuple(ops), R.choice(["chẵn", "lẻ"]))
    ops, want = key
    vals = [a + b if o == "+" else a - b for a, o, b in ops]
    ans = sum(1 for v in vals if (v % 2 == 0) == (want == "chẵn"))
    lst = ";  ".join(f"{a} {o} {b}" for a, o, b in ops)
    we = "even" if want == "chẵn" else "odd"
    add("number", "parity_ops", d, f"Trong các phép tính sau, có bao nhiêu phép tính có kết quả là số {want}?  {lst}",
        f"How many of these results are {we}?  {lst.replace('−', '-')}", ans,
        "Cộng hoặc trừ hai số cùng chẵn hoặc cùng lẻ thì được số chẵn; một chẵn một lẻ thì được số lẻ. Kết quả: " + ", ".join(map(str, vals)) + f". Có {ans} số {want}.",
        "Same parity → even, different parity → odd. Results: " + ", ".join(map(str, vals)) + f". {ans} are {we}.",
        "Không cần tính hết, chỉ cần xem chữ số hàng đơn vị chẵn hay lẻ.", "Only look at the units digits.",
        [("even", "chẵn"), ("odd", "lẻ")], {"ops": [list(t) for t in ops], "want": want}, wrong=(6 - ans, ans + 1))


def kth(d, dry=False, key=None):
    """Sắp xếp dãy số, tìm số lớn (bé) thứ k."""
    if dry:
        n = {1: 6, 2: 8, 3: 8}[d]
        return (tuple(R.sample(range(10, 100), n)), R.choice([2, 3]) if d > 1 else 2, R.choice(["lớn", "bé"]))
    xs, k, kind = key
    s = sorted(xs, reverse=(kind == "lớn"))
    ans = s[k - 1]
    ke = "largest" if kind == "lớn" else "smallest"
    add("number", "kth", d, f"Cho các số: {', '.join(map(str, xs))}. Hỏi số {kind} thứ {k} là số nào?",
        f"Numbers: {', '.join(map(str, xs))}. Which is the {k}{'nd' if k == 2 else 'rd'} {ke}?", ans,
        f"Sắp xếp {'từ lớn đến bé' if kind == 'lớn' else 'từ bé đến lớn'}: {', '.join(map(str, s))}. Số thứ {k} là {ans}.",
        f"Sorted: {', '.join(map(str, s))}. Number {k} is {ans}.",
        "Sắp xếp các số trước.", "Sort the numbers first.", [("largest", "lớn nhất"), ("smallest", "bé nhất")],
        {"xs": list(xs), "k": k, "kind": kind}, wrong=(s[0], s[k] if k < len(s) else s[k - 2]))


def giveequal(d, dry=False, key=None):
    """A có a, B có b; A cho B bao nhiêu để bằng nhau (d=3: để A còn hơn B c)."""
    if dry:
        while True:
            a, b = R.randint(20, 90), R.randint(10, 60)
            c = 0 if d < 3 else R.choice([2, 4, 6, 10])
            if a > b and (a - b - c) > 0 and (a - b - c) % 2 == 0:
                return (a, b, c)
    a, b, c = key
    x, y = nm(2)
    ans = (a - b - c) // 2
    if c == 0:
        qv = f"{x} có {a} viên bi, {y} có {b} viên bi. {x} phải cho {y} bao nhiêu viên để số bi của hai bạn bằng nhau?"
        qe = f"{x} has {a} marbles and {y} has {b}. How many must {x} give {y} so they have the same?"
    else:
        qv = f"{x} có {a} viên bi, {y} có {b} viên bi. {x} phải cho {y} bao nhiêu viên để {x} còn nhiều hơn {y} {c} viên?"
        qe = f"{x} has {a} marbles and {y} has {b}. How many must {x} give {y} so that {x} has {c} more than {y}?"
    add("number", "giveequal", d, qv, qe, ans,
        f"Lúc đầu {x} hơn {y} {a - b} viên. Mỗi viên {x} cho đi làm khoảng cách giảm 2. Cần giảm {a - b} − {c} = {a - b - c}, nên cho {ans} viên.",
        f"The gap is {a - b}; each marble given shrinks it by 2. It must shrink by {a - b - c}: give {ans}.",
        "Cho đi 1 viên thì khoảng cách giảm 2 viên.", "Giving 1 marble closes the gap by 2.",
        [("give", "cho"), ("the same", "bằng nhau")], {"a": a, "b": b, "c": c}, wrong=(a - b, a - b - c))


def pages(d, dry=False, key=None):
    """Xếp n đồ vào hộp/trang, mỗi trang tối đa k: ít nhất bao nhiêu trang."""
    if dry:
        k = R.randint(4, 9)
        return (R.randint(10, 30), R.randint(5, 20) if d > 1 else 0, k)
    a, b, k = key
    x = nm()[0]
    n = a + b
    ans = -(-n // k)
    if b:
        qv = f"{x} có {a} con tem, anh của {x} có {b} con tem. Mỗi trang album dán được nhiều nhất {k} con tem. Hỏi cần ít nhất bao nhiêu trang để dán hết tem của hai anh em?"
        qe = f"{x} has {a} stamps and his brother has {b}. Each album page holds at most {k}. At least how many pages are needed for all of them?"
    else:
        qv = f"Có {a} quả trứng, mỗi hộp đựng được nhiều nhất {k} quả. Hỏi cần ít nhất bao nhiêu hộp để đựng hết số trứng?"
        qe = f"There are {a} eggs and each box holds at most {k}. At least how many boxes are needed?"
    add("number", "pages", d, qv, qe, ans,
        f"Có {n} vật. {n} = {k} × {n // k} + {n % k}" + (f": {n // k} trang đầy và 1 trang cho {n % k} vật còn lại, tất cả {ans}." if n % k else f": vừa đủ {ans}."),
        f"{n} items: {n // k} full" + (f" plus 1 more = {ans}." if n % k else f" = {ans}."),
        "Phần còn thừa vẫn cần thêm một trang.", "Leftovers still need one more page.",
        [("at most", "nhiều nhất"), ("at least", "ít nhất")], {"n": n, "k": k}, wrong=(n // k, ans + 1))


def countsteps(d, dry=False, key=None):
    """Đánh số các quả bóng bằng các số chẵn (lẻ) từ a đến b: có bao nhiêu quả."""
    if dry:
        step = 2 if d < 3 else R.choice([3, 5])
        a = R.randint(2, 20); a -= a % step
        b = R.randint(a + 20, 90); b -= (b - a) % step
        return (a, b, step)
    a, b, step = key
    ans = (b - a) // step + 1
    sv = {2: "các số chẵn" if a % 2 == 0 else "các số lẻ", 3: "các số cách nhau 3 đơn vị", 5: "các số cách nhau 5 đơn vị"}[step]
    add("number", "countsteps", d, f"Các quả bóng được đánh số bằng {sv} liên tiếp từ {a} đến {b}. Hỏi có bao nhiêu quả bóng?",
        f"Balls are numbered every {step} from {a} to {b}. How many balls are there?", ans,
        f"Số khoảng cách: ({b} − {a}) : {step} = {(b-a)//step}. Số quả bóng nhiều hơn số khoảng 1: {ans}.",
        f"Gaps: ({b} - {a}) ÷ {step} = {(b-a)//step}. Balls = gaps + 1 = {ans}.",
        "Số quả bóng nhiều hơn số khoảng cách 1.", "There is one more ball than gaps.",
        [("even", "chẵn"), ("from … to …", "từ … đến …")], {"a": a, "b": b, "step": step}, wrong=(ans - 1, b - a))


# ============================================================ HÌNH HỌC
def pointsegs(d, dry=False, key=None):
    """n điểm, không có 3 điểm thẳng hàng: vẽ được bao nhiêu đoạn thẳng."""
    if dry:
        return ({1: R.choice([3, 4]), 2: R.choice([4, 5]), 3: R.choice([5, 6])}[d],)
    (n,) = key
    ans = n * (n - 1) // 2
    add("geo", "pointsegs", d, f"Cho {n} điểm, không có ba điểm nào thẳng hàng. Nối hai điểm bất kỳ được một đoạn thẳng. Hỏi vẽ được nhiều nhất bao nhiêu đoạn thẳng?",
        f"There are {n} points, no three in a line. Joining any two makes a segment. At most how many segments?", ans,
        f"Mỗi điểm nối với {n - 1} điểm còn lại, nhưng mỗi đoạn được đếm 2 lần: {n} × {n - 1} : 2 = {ans}.",
        f"Each point joins {n - 1} others; each segment is counted twice: {ans}.",
        "Đặt tên các điểm rồi liệt kê từng đoạn.", "Name the points and list the segments.",
        [("point", "điểm"), ("segment", "đoạn thẳng")], {"n": n}, wrong=(n * (n - 1), n))


def shapeparts(d, dry=False, key=None):
    """Đếm cạnh / đỉnh / mặt của các hình quen thuộc."""
    if dry:
        pool = [("tam giác", "triangle", 3, 3, None), ("hình vuông", "square", 4, 4, None),
                ("hình chữ nhật", "rectangle", 4, 4, None), ("hình lập phương", "cube", 12, 8, 6)]
        items = R.sample(range(4), 2 if d < 3 else 3)
        cnts = tuple(R.randint(1, 3) for _ in items)
        what = R.choice(["cạnh", "đỉnh"]) if d < 3 else R.choice(["cạnh", "đỉnh", "mặt"])
        if what == "mặt":
            items, cnts = (3,), (R.randint(2, 4),)
        return (tuple(items), cnts, what)
    items, cnts, what = key
    pool = [("hình tam giác", "triangle", 3, 3, 0), ("hình vuông", "square", 4, 4, 0),
            ("hình chữ nhật", "rectangle", 4, 4, 0), ("hình lập phương", "cube", 12, 8, 6)]
    idx = {"cạnh": 2, "đỉnh": 3, "mặt": 4}[what]
    we = {"cạnh": "edges/sides", "đỉnh": "vertices", "mặt": "faces"}[what]
    ans = sum(c * pool[i][idx] for i, c in zip(items, cnts))
    lv = " và ".join(f"{c} {pool[i][0]}" for i, c in zip(items, cnts))
    le = " and ".join(f"{c} {pool[i][1]}{'s' if c > 1 else ''}" for i, c in zip(items, cnts))
    add("geo", "shapeparts", d, f"Có {lv}. Hỏi tất cả có bao nhiêu {what}?", f"There are {le}. How many {we} in total?", ans,
        " + ".join(f"{c} × {pool[i][idx]}" for i, c in zip(items, cnts)) + f" = {ans}.",
        " + ".join(f"{c} × {pool[i][idx]}" for i, c in zip(items, cnts)) + f" = {ans}.",
        "Nhớ: hình lập phương có 12 cạnh, 8 đỉnh, 6 mặt.", "A cube has 12 edges, 8 vertices, 6 faces.",
        [("side / edge", "cạnh"), ("vertex", "đỉnh"), ("face", "mặt")], {"items": list(items), "cnts": list(cnts), "what": what},
        wrong=(ans + 1, ans - 1))


# ============================================================ TỔ HỢP
def makenum_parity(d, dry=False, key=None):
    """Chọn 2 chữ số khác nhau từ tập (có thể có 0) lập số có 2 chữ số chẵn/lẻ."""
    if dry:
        k = {1: 3, 2: 4, 3: 5}[d]
        while True:
            ds = tuple(sorted(R.sample(range(0, 10), k)))
            if d == 1 and 0 in ds:
                continue
            return (ds, R.choice(["chẵn", "lẻ"]))
    ds, want = key
    nums = [10 * a + b for a in ds for b in ds if a != b and a != 0 and (b % 2 == 0) == (want == "chẵn")]
    ans = len(nums)
    we = "even" if want == "chẵn" else "odd"
    add("comb", "makenum_parity", d, f"Chọn 2 chữ số khác nhau từ các chữ số {', '.join(map(str, ds))} để lập số có hai chữ số. Hỏi lập được bao nhiêu số {want}?",
        f"Choose 2 different digits from {', '.join(map(str, ds))} to make 2-digit numbers. How many {we} numbers can be made?", ans,
        f"Chọn chữ số hàng đơn vị là số {want} trước, rồi chọn hàng chục (khác 0, khác hàng đơn vị). Các số: {', '.join(map(str, sorted(nums)))}. Có {ans} số.",
        f"Pick the units digit first, then the tens (not 0, not the same). Numbers: {', '.join(map(str, sorted(nums)))}. {ans} numbers.",
        "Chọn chữ số hàng đơn vị trước; hàng chục không được là 0.", "Choose the units digit first; tens can't be 0.",
        [("digit", "chữ số"), (we, want)], {"digits": list(ds), "want": want}, wrong=(ans + 1, len(ds) * (len(ds) - 1)))


def minsum2(d, dry=False, key=None):
    """Dùng hết 4 chữ số lập hai số có 2 chữ số; tổng nhỏ nhất / lớn nhất."""
    if dry:
        return (tuple(sorted(R.sample(range(1, 10), 4))), "min" if d < 3 else R.choice(["min", "max"]))
    ds, kind = key
    best = None
    for p in itertools.permutations(ds):
        s = 10 * p[0] + p[1] + 10 * p[2] + p[3]
        if best is None or (s < best if kind == "min" else s > best):
            best = s
    a, b, c, e = sorted(ds)
    if kind == "min":
        ex = f"Hai chữ số nhỏ nhất {a}, {b} đặt ở hàng chục, {c}, {e} ở hàng đơn vị: {10*a+c} + {10*b+e} = {best}."
    else:
        ex = f"Hai chữ số lớn nhất {e}, {c} đặt ở hàng chục, {b}, {a} ở hàng đơn vị: {10*e+b} + {10*c+a} = {best}."
    kv, ke = ("nhỏ nhất", "smallest") if kind == "min" else ("lớn nhất", "largest")
    add("comb", "minsum2", d, f"Dùng cả bốn chữ số {', '.join(map(str, ds))} (mỗi chữ số dùng một lần) để lập hai số có hai chữ số rồi cộng lại. Hỏi tổng {kv} là bao nhiêu?",
        f"Use all of the digits {', '.join(map(str, ds))} once to make two 2-digit numbers, then add them. What is the {ke} sum?", best,
        ex, ex, "Chữ số ở hàng chục có giá trị gấp 10 lần.", "Tens digits count 10 times more.",
        [(ke, kv), ("digit", "chữ số")], {"digits": list(ds), "kind": kind},
        wrong=(10 * a + b + 10 * c + e, best + 9))


def freebie(d, dry=False, key=None):
    """Mỗi món giá p; mua k món được tặng 1. Có M tiền thì được nhiều nhất bao nhiêu món."""
    if dry:
        p = R.choice([2, 3, 5]); k = R.choice([3, 4, 5])
        buy = R.randint(k, 3 * k) if d > 1 else R.choice([k, 2 * k])
        return (p, k, buy * p)
    p, k, M = key
    buy = M // p
    ans = buy + buy // k
    add("comb", "freebie", d, f"Mỗi chiếc bút chì giá {p} nghìn đồng. Cứ mua {k} chiếc thì được tặng thêm 1 chiếc. Với {M} nghìn đồng, bạn có được nhiều nhất bao nhiêu chiếc bút chì?",
        f"Each pencil costs {p} thousand dong. For every {k} you buy you get 1 free. With {M} thousand dong, at most how many pencils can you get?", ans,
        f"Mua được {M} : {p} = {buy} chiếc. Số lần được tặng: {buy} : {k} = {buy // k} (dư {buy % k}). Tổng: {buy} + {buy // k} = {ans}.",
        f"Buy {buy}. Free: {buy // k}. Total {ans}.",
        "Tính số bút mua được trước, rồi đến số bút được tặng.", "Count bought pencils, then free ones.",
        [("free", "tặng"), ("at most", "nhiều nhất")], {"p": p, "k": k, "M": M}, wrong=(buy, ans + 1))


def vases(d, dry=False, key=None):
    """Chia n bông hoa giống nhau vào 3 lọ khác nhau, lọ nào cũng có hoa."""
    if dry:
        return ({1: R.choice([4, 5]), 2: R.choice([5, 6]), 3: R.choice([6, 7])}[d],)
    (n,) = key
    ans = sum(1 for a in range(1, n) for b in range(1, n) if n - a - b >= 1)
    add("comb", "vases", d, f"Có {n} bông hoa giống nhau cắm vào 3 lọ khác nhau, lọ nào cũng có ít nhất 1 bông. Hỏi có bao nhiêu cách cắm?",
        f"{n} identical flowers go into 3 different vases, each vase gets at least 1. How many ways?", ans,
        f"Liệt kê theo số hoa ở lọ thứ nhất (từ 1 đến {n - 2}) rồi đếm cách chia phần còn lại cho hai lọ kia. Tổng: {ans} cách.",
        f"List by the first vase (1 to {n - 2}) and split the rest. Total {ans}.",
        "Chia trường hợp theo số hoa ở lọ thứ nhất.", "Split by how many are in the first vase.",
        [("identical", "giống nhau"), ("at least", "ít nhất")], {"n": n}, wrong=(ans - 1, n))


def kth_choose(d, dry=False, key=None):
    """Chọn 2 bạn trong n bạn đi thi (không phân biệt thứ tự) / chọn lớp trưởng + lớp phó (có thứ tự)."""
    if dry:
        return ({1: R.randint(3, 4), 2: R.randint(4, 5), 3: R.randint(5, 6)}[d], "ord" if d == 3 and R.random() < .5 else "unord")
    n, kind = key
    ans = n * (n - 1) // (2 if kind == "unord" else 1)
    if kind == "unord":
        qv = f"Lớp có {n} bạn giỏi toán. Cô cần chọn 2 bạn đi thi. Hỏi cô có bao nhiêu cách chọn?"
        qe = f"There are {n} good maths students. The teacher picks 2 for a contest. How many ways?"
        ex = f"Mỗi bạn ghép được với {n - 1} bạn khác, mỗi cặp bị đếm 2 lần: {n} × {n - 1} : 2 = {ans}."
    else:
        qv = f"Nhóm có {n} bạn. Cần chọn 1 bạn làm nhóm trưởng và 1 bạn khác làm nhóm phó. Hỏi có bao nhiêu cách chọn?"
        qe = f"A group has {n} children. Pick a leader and a different deputy. How many ways?"
        ex = f"Có {n} cách chọn nhóm trưởng, rồi {n - 1} cách chọn nhóm phó: {n} × {n - 1} = {ans}."
    add("comb", "kth_choose", d, qv, qe, ans, ex, ex, "Đếm số cách chọn từng bạn một.", "Count choices one at a time.",
        [("choose", "chọn"), ("ways", "cách")], {"n": n, "kind": kind}, wrong=(n * (n - 1) if kind == "unord" else ans // 2, ans + 1))


FORMS = [classsize, weekday_rel, order3, seq_grow, interleave, cyclepattern, laps,
         altsum, runsum, cryptarith, arrowchain, signs, flowerx, factor_out,
         digitcond, parity_ops, kth, giveequal, pages, countsteps,
         pointsegs, shapeparts,
         makenum_parity, minsum2, freebie, vases, kth_choose]

for fn in FORMS:
    many(fn)

cnt = {}
for q in OUT:
    cnt[q["topic"]] = cnt.get(q["topic"], 0) + 1
    q["id"] = f"t2-{q['topic']}-{cnt[q['topic']]:03d}"

meta = {"name": "TIMO lớp 2 - dạng bài bổ sung theo đề vòng loại 2026–2027", "grade": 2, "version": 1,
        "forms": [f.__name__ for f in FORMS], "count": len(OUT),
        "note": "Dạng bài lấy theo đề thật; số và lời văn tự soạn. Đáp án do code tính, check_timo2.py giải lại."}
json.dump({"meta": meta, "questions": OUT},
          open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "questions_timo2.json"), "w", encoding="utf-8"),
          ensure_ascii=False, indent=1)
print(len(OUT), cnt)
