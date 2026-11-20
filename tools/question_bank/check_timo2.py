# -*- coding: utf-8 -*-
"""Giải lại độc lập mọi câu trong questions_timo2.json từ `params` (vét cạn)."""
import json, os, itertools, sys
D = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "questions_timo2.json"), encoding="utf-8"))
bad = []

def solve(q):
    f, p = q["form"], q["params"]
    if f == "classsize": return p["taller"] + p["shorter"] + p["same"] + 1
    if f == "weekday_rel":
        t = p["day"]
        for _ in range(p["before"]): t = (t + 1) % 7
        sh = {"yesterday": 6, "tomorrow": 1, "dayafter": 2, "m": p["m"]}[p["ask"]]
        for _ in range(sh): t = (t + 1) % 7
        return p["options"].index(t)
    if f == "order3":
        n = p["n"]
        for perm in itertools.permutations(range(n)):  # perm[i] = cân nặng vật i
            if all(perm[h] > perm[l] for h, l in p["facts"]):
                w = list(perm)
                return w.index(max(w)) if p["ask"] == "max" else w.index(min(w))
    if f in ("seq_grow", "interleave"): return p["seq"][-1] if f == "seq_grow" else p["seq"][p["n"]]
    if f == "cyclepattern":
        seq = [p["pattern"][i % len(p["pattern"])] for i in range(p["n"])]
        if p["ask"] == "nth": return sorted("▲■●★").index(seq[-1])
        return seq.count(p["sym"])
    if f == "laps":
        t = 0
        for i in range(p["n"]):
            t += p["t"] + (p["r"] if i < p["n"] - 1 else 0)
        return t
    if f == "altsum":
        v = 0
        for i, x in enumerate(p["terms"]): v = v + x if i % 2 == 0 else v - x
        return v
    if f == "runsum": return sum(p["terms"])
    if f == "cryptarith":
        sols = [B for A in [p["A"]] for B in range(10) if B != A and
                ((10 * A + B) + A if p["op"] == "+" else (10 * A + B) - A) == p["res"]]
        allsols = {(A, B) for A in range(1, 10) for B in range(10) if A != B and
                   ((10 * A + B) + A if p["op"] == "+" else (10 * A + B) - A) == p["res"]}
        assert len(allsols) == 1, ("not unique", allsols)
        return sols[0]
    if f == "arrowchain":
        for x in range(0, 200):
            v = x
            for o, a in p["ops"]: v = v + a if o == "+" else v - a
            if v == p["end"]: return x
    if f == "signs":
        ok = [o for o in p["options"] if p["nums"][0] + sum(x if s == "+" else -x for s, x in zip(o, p["nums"][1:])) == p["value"]]
        assert len(ok) == 1, ok
        return p["options"].index(ok[0])
    if f == "flowerx":
        for x in range(0, 200):
            if p["k"] * x - p["a"] == x + p["b"]: return x
    if f == "factor_out":
        assert 2 <= p["m"] <= 5
        return sum(p["m"] * x for x in p["xs"])
    if f == "digitcond":
        k = p["k"]; c = 0
        for n in range(10, 100):
            t, u = divmod(n, 10)
            c += {"both_gt": t > k and u > k, "both_lt": t < k and u < k, "unit_lt": u < k,
                  "tens_gt_unit": t > u, "sum_eq": t + u == k}[p["kind"]]
        return c
    if f == "parity_ops":
        vals = [a + b if o == "+" else a - b for a, o, b in p["ops"]]
        return sum(1 for v in vals if (v % 2 == 0) == (p["want"] == "chẵn"))
    if f == "kth": return sorted(p["xs"], reverse=p["kind"] == "lớn")[p["k"] - 1]
    if f == "giveequal":
        for g in range(0, p["a"] + 1):
            if (p["a"] - g) - (p["b"] + g) == p["c"]: return g
    if f == "pages":
        k = 0
        while k * p["k"] < p["n"]: k += 1
        return k
    if f == "countsteps": return len(range(p["a"], p["b"] + 1, p["step"]))
    if f == "pointsegs": return len(list(itertools.combinations(range(p["n"]), 2)))
    if f == "shapeparts":
        tab = [(3, 3, 0), (4, 4, 0), (4, 4, 0), (12, 8, 6)]
        j = {"cạnh": 0, "đỉnh": 1, "mặt": 2}[p["what"]]
        return sum(c * tab[i][j] for i, c in zip(p["items"], p["cnts"]))
    if f == "makenum_parity":
        s = {10 * a + b for a in p["digits"] for b in p["digits"] if a != b and a != 0}
        return sum(1 for n in s if (n % 2 == 0) == (p["want"] == "chẵn"))
    if f == "minsum2":
        v = [10 * a + b + 10 * c + d for a, b, c, d in itertools.permutations(p["digits"])]
        return min(v) if p["kind"] == "min" else max(v)
    if f == "freebie":
        money, got, bought = p["M"], 0, 0
        while money >= p["p"]:
            money -= p["p"]; bought += 1; got += 1
            if bought % p["k"] == 0: got += 1
        return got
    if f == "vases":
        return sum(1 for a in range(1, p["n"]) for b in range(1, p["n"]) for c in range(1, p["n"]) if a + b + c == p["n"])
    if f == "kth_choose":
        pairs = list(itertools.permutations(range(p["n"]), 2))
        return len(pairs) // (2 if p["kind"] == "unord" else 1)
    raise KeyError(f)

def nums_in(q):
    import re
    return [int(x) for x in re.findall(r"\d+", q["question_vi"])]

ids = set()
for q in D["questions"]:
    try:
        a = solve(q)
    except Exception as e:
        bad.append((q["id"], "lỗi", repr(e))); continue
    if a != q["answer"]: bad.append((q["id"], q["answer"], a))
    if q["id"] in ids: bad.append((q["id"], "trùng id"))
    ids.add(q["id"])
    if q["answer_type"] == "number":
        if q["answer"] in q["distractors"] or len(q["distractors"]) < 3: bad.append((q["id"], "đáp án nhiễu"))
        if not (0 <= q["answer"] <= 200): bad.append((q["id"], "ngoài phạm vi", q["answer"]))
    else:
        if not (0 <= q["answer"] < len(q["choices"])): bad.append((q["id"], "chỉ số lựa chọn"))
    big = [n for n in nums_in(q) if n > 200]
    if big: bad.append((q["id"], "số quá lớn cho lớp 2", big))
    for k in ("question_vi", "question_en", "hint_vi", "hint_en", "explanation_vi", "explanation_en"):
        if not q[k].strip(): bad.append((q["id"], "thiếu", k))

dup = {}
for q in D["questions"]: dup.setdefault(q["question_vi"], []).append(q["id"])
bad += [("trùng đề", v) for v in dup.values() if len(v) > 1]
print(f"{len(D['questions'])} câu, {len(bad)} lỗi")
for b in bad[:30]: print(" ", b)
sys.exit(1 if bad else 0)
