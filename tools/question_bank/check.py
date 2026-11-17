# -*- coding: utf-8 -*-
"""Kiểm tra độc lập: giải lại từng câu từ chính đề bài (đọc số trong câu hỏi), không dùng code sinh đề."""
import json, os, re, itertools, math

D = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "questions.json"), encoding="utf-8"))
Q = D["questions"]
DAYS = ["Chủ nhật", "Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy"]


def nums(s):
    return [int(x) for x in re.findall(r"\d+", s)]


def solve(q):
    t, f = q["question_vi"], q["form"]; n = nums(t)
    svg = q.get("figure_svg") or ""
    if f == "age":
        if "Mẹ hơn" in t: return n[0] + n[1]
        if "Khi" in t: a, b, c = n; return c - (b - a)
        m, c, T = n; return (T - m - c) // 2
    if f == "queue":
        if "đứng thứ" in t and "Một hàng có" in t: N, a = n; return N - a + 1
        if "Giữa" in t: a, b, k = n[0], n[1], n[2]; return a + b + k
        a, b = n; return a + b - 1
    if f == "balance":
        if t.startswith("1 quả dưa hấu nặng bằng") and "1 quả cam" in t: p, q2, r = n[1], n[3], n[4]; return p * q2 * r
        if t.startswith("1 "): return n[1] * n[2]
        k, kp, m, mq, r = n; return (kp // k) * (mq // m) * r
    if f == "backward":
        if "nhân 2, rồi cộng" in t: a, c = n[1], n[2]; return (c - a) // 2
        if "rồi nhân với 2" in t: a, c = n[0], n[2]; return c // 2 - a
        if "rồi trừ" in t: a, b, c = n; return c + b - a
        a, b = n; return b - a
    if f == "cut":
        if "phút" in t: tt, k = n; return (k - 1) * tt
        return n[0] - 1
    if f == "stairs": return (n[4] - 1) * n[2]
    if f == "trees": L, d = n; return L // d + 1
    if f == "legs":
        if "chuồng" in t: N, L = n; return (L - 2 * N) // 2
        a, b = n; return 2 * a + 4 * b
    if f == "equalize": a, b = n; return a - 2 * b
    if f == "pattern":
        seq_part = t.split(":", 1)[1]
        items = [x.strip() for x in seq_part.replace("...", "").split(",") if x.strip()]
        if "__" in items:
            i = items.index("__"); vals = [int(x) if x != "__" else None for x in items]
            d = vals[1] - vals[0] if vals[0] is not None and vals[1] is not None else vals[3] - vals[2]
            return vals[i - 1] + d
        v = [int(x) for x in items]
        if len(v) == 6 and v[1] - v[0] != v[3] - v[2] and v[2] - v[0] == 1: return v[4] + 1  # xen kẽ
        dif = [v[i + 1] - v[i] for i in range(len(v) - 1)]
        if len(set(dif)) == 1: return v[-1] + dif[0]
        return v[-1] + dif[-1] + (dif[-1] - dif[-2])
    if f == "quick":
        expr = t.split(":", 1)[1].split("=")[0]
        if "..." in expr:
            a, b, c, last = nums(expr)[:4]; return sum(range(a, last + 1, b - a))
        return sum(nums(expr))
    if f == "blank":
        expr = t.split(":", 1)[1]
        for x in range(0, 200):
            e = expr.replace("□", str(x)).replace("−", "-")
            lhs, rhs = e.split("=")
            if eval(lhs) == int(rhs): return x
    if f == "symbols":
        for s in range(0, 50):
            for tri in range(0, 50):
                for ci in range(0, 50):
                    env = {"★": s, "▲": tri, "●": ci}
                    ok = True
                    for part in t.split(":", 1)[1].split("Hỏi")[0].replace(" và ", ";").split(";"):
                        if "=" not in part: continue
                        lhs, rhs = part.split("=")
                        syms = [c for c in lhs if c in env]
                        if sum(env[c] for c in syms) != int(nums(rhs)[0]): ok = False; break
                    if ok:
                        return tri if "▲ bằng" in t else ci
    if f == "word":
        if "nhiều hơn" in t and "tất cả" not in t: return n[0] + n[1]
        if "ít hơn" in t: a, b = n; return 2 * a - b
        s, d = n; return (s - d) // 2
    if f == "multiply":
        if "chia đều" in t: return n[0] // n[1]
        if "bàn" in t: tt, c, br = n; return tt * c - br
        return n[0] * n[1]
    if f == "money": p, k, paid = n; return paid - p * k
    if f == "parity":
        a, b = (n[0], n[1]) if "Từ" in t else (n[0] + 1, n[1] - 1)
        return sum(1 for v in range(a, b + 1) if v % 2 == (1 if "lẻ" in t else 0))
    if f == "digitsum": return sum(1 for v in range(10, 100) if v // 10 + v % 10 == n[-1])
    if f == "cards":
        ds = n[:3]
        if "lớn nhất có hai" in t: return max(10 * a + b for a, b in itertools.permutations(ds, 2))
        if "nhỏ nhất có ba" in t: return min(100 * a + 10 * b + c for a, b, c in itertools.permutations(ds, 3) if a)
        p = [10 * a + b for a, b in itertools.permutations(ds, 2)]; return max(p) - min(p)
    if f == "digitcount": return sum(len(str(v)) for v in range(1, n[1] + 1))
    if f == "digitfreq": return sum(str(v).count(str(n[2])) for v in range(1, n[1] + 1))
    if f == "clues":
        if "số lẻ" in t:
            lo, s = n[0], n[1]
            sol = [v for v in range(10, 100) if v % 2 and v > lo and v // 10 + v % 10 == s and v // 10 > v % 10]
        else:
            s, d = n[0], n[1]
            sol = [v for v in range(10, 100) if v // 10 + v % 10 == s and v // 10 - v % 10 == d]
        assert len(sol) == 1, (t, sol); return sol[0]
    if f == "round": return len(range(n[0], n[1] + 1, 10))
    if f == "place": return 10 * n[0] + n[1] + 10 * n[2]
    if f == "fixed":
        if "khác nhau là" in t: return max(v for v in range(10, 100) if v // 10 != v % 10)
        if "bé nhất" in t: return min(v for v in range(10, 100) if v // 10 + v % 10 == 10)
        if "giống nhau" in t: return sum(1 for v in range(10, 100) if v // 10 == v % 10)
        if "hàng chục lớn hơn" in t: return sum(1 for v in range(10, 100) if v // 10 > v % 10)
        if "đơn vị lớn hơn" in t: return sum(1 for v in range(10, 100) if v // 10 < v % 10)
        return 90
    if f == "countsq":
        xs = sorted(set(re.findall(r'x1="([\d.]+)" y1="6" x2="\1"', svg))); ys = sorted(set(re.findall(r'x1="6" y1="([\d.]+)"', svg)))
        c, r = len(xs) - 1, len(ys) - 1
        return sum(1 for a in range(c + 1) for b in range(r + 1) for k in range(1, 10) if a + k <= c and b + k <= r)
    if f == "countrect":
        c = len(re.findall(r'x1="([\d.]+)" y1="6" x2="\1"', svg)) - 1
        return sum(1 for a in range(c) for b in range(a + 1, c + 1))
    if f == "counttri":
        k = svg.count("<line")
        return math.comb(k + 2, 2)
    if f == "perim":
        if "cạnh dài" in t: return 4 * n[0]
        if "chiều dài" in t and "chiều rộng" in t and "chu vi" not in t.split("Hỏi")[0]: return 2 * (n[0] + n[1])
        if "Một hình vuông có chu vi" in t: return n[0] // 4
        return n[0] // 2 - n[1]
    if f == "matches":
        if "2 hàng" in t: c = n[1]; return 3 * c + 2 * (c + 1)
        if "tam giác" in t: return 2 * n[0] + 1
        return 3 * n[0] + 1
    if f == "sides": return 3 * n[0] + 4 * n[1]
    if f == "cubes":
        if "3 × 3" in t: return 1 + 4 + 9
        N, k = n[0], n[2]; return sum(1 + k * i for i in range(N))
    if f == "shapeperim": k, s = n; return 2 * (k * s + s)
    if f == "cutpaper": return 1 + n[2]
    if f == "outfit":
        p = 1
        for x in n: p *= x
        return p
    if f in ("handshake", "tournament", "choose2"): return math.comb(n[0], 2)
    if f == "makenum":
        ds = n if t.startswith("Từ bốn") else n[:3]
        if t.startswith("Từ ba"): ds = n[:3]
        if "lặp lại" in t: return sum(1 for a in ds for b in ds if a)
        return sum(1 for a, b in itertools.permutations(ds, 2) if a)
    if f == "routes":
        if "thẳng" in t: return n[0] * n[1] + n[2]
        return n[0] * n[1]
    if f == "pigeon":
        if "kẹo dâu" in t and "2 viên kẹo dâu" in t: return n[1] + n[2] + 2
        return 3
    if f == "arrange":
        if "Bốn" in t: return 24
        if "giữa" in t: return 2
        return 6
    if f == "gridpath":
        xs = set(re.findall(r'x1="([\d.]+)" y1="24" x2="\1"', svg)); ys = set(re.findall(r'x1="24" y1="([\d.]+)"', svg))
        return math.comb(len(xs) - 1 + len(ys) - 1, len(xs) - 1)
    if f == "split": k = n[0]; return k // 2
    if f == "coins": return sum(1 for a in range(11) for b in range(6) for c in range(3) if a + 2 * b + 5 * c == 10)
    return None


bad, unchecked = [], []
for q in Q:
    if q["answer_type"] == "choice":
        assert 0 <= q["answer"] < len(q["choices"])
        if q["form"] == "weekday":
            t = q["question_vi"]; n = nums(t)
            start = next(i for i, d in enumerate(DAYS) if d in t)
            plus = n[-1] - 1 if "Ngày 1" in t else n[0]
            exp = DAYS[(start + plus) % 7]
            if q["choices"][q["answer"]]["vi"] != exp: bad.append((q["id"], exp))
        elif q["form"] == "compare":
            t = q["question_vi"]; rels = []
            for a, b in re.findall(r"(\w+) cao hơn (\w+)", t): rels.append((a, b))
            for b, a in re.findall(r"(\w+) thấp hơn (\w+)", t): rels.append((a, b))
            people = {p for r in rels for p in r}
            taller = {p for p, _ in rels}; shorter = {p for _, p in rels}
            exp = (people - shorter).pop() if "cao nhất" in t else (people - taller).pop()
            if q["choices"][q["answer"]]["vi"] != exp: bad.append((q["id"], exp))
        elif q["form"] == "parityrule":
            k = 3 if "ba số" in q["question_vi"] else 4
            exp = "Số lẻ" if k % 2 else "Số chẵn"
            if q["choices"][q["answer"]]["vi"] != exp: bad.append((q["id"], exp))
        continue
    s = solve(q)
    if s is None: unchecked.append(q["id"]); continue
    if s != q["answer"]: bad.append((q["id"], q["question_vi"], q["answer"], s))
    assert q["answer"] > 0 and q["answer"] not in q["distractors"] and len(set(q["distractors"])) == 3, q["id"]
    assert str(q["answer"]) in q["explanation_vi"], ("explanation", q["id"])

print("questions:", len(Q), "| bad:", len(bad), "| unchecked:", unchecked)
for b in bad: print(b)
