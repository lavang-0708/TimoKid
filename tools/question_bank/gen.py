# -*- coding: utf-8 -*-
"""Sinh ngân hàng câu hỏi ôn TIMO lớp 2 (song ngữ Việt - Anh).
Mọi đáp án được tính bằng code; check.py kiểm tra lại độc lập."""
import json, os, random, itertools, math

R = random.Random(2026)
NAMES = ["An", "Bình", "Chi", "Dũng", "Hà", "Lan", "Mai", "Minh", "Nam", "Ngọc",
         "Phương", "Quân", "Thảo", "Trang", "Tuấn", "Vy", "Linh", "Hùng", "Khoa", "My"]
DAYS_VI = ["Chủ nhật", "Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy"]
DAYS_EN = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

TOPICS = {
    "logic": ("Tư duy lôgic", "Logical Thinking"),
    "arith": ("Số học / Đại số", "Arithmetic / Algebra"),
    "number": ("Lý thuyết số", "Number Theory"),
    "geo": ("Hình học", "Geometry"),
    "comb": ("Tổ hợp", "Combinatorics"),
}

POOL = {k: [] for k in TOPICS}


def names(k):
    return R.sample(NAMES, k)


def distractors(ans, extra=()):
    cands = [e for e in extra if e != ans and e > 0]
    for d in (1, -1, 2, -2, 10, -10, 3, 5):
        cands.append(ans + d)
    out = []
    for c in cands:
        if c > 0 and c != ans and c not in out:
            out.append(c)
    first = out[:len([e for e in extra if e != ans and e > 0])]
    rest = [c for c in out if c not in first]
    R.shuffle(rest)
    return (first + rest)[:3]


def add(topic, diff, form, qvi, qen, ans, evi, een, hvi, hen, kw, wrong=(),
        choices=None, figure=None):
    q = {
        "topic": topic, "difficulty": diff, "form": form,
        "question_vi": qvi, "question_en": qen,
        "hint_vi": hvi, "hint_en": hen,
        "explanation_vi": evi, "explanation_en": een,
        "keywords": [{"en": e, "vi": v} for e, v in kw],
        "figure_svg": figure,
    }
    if choices is None:
        q["answer_type"] = "number"
        q["answer"] = ans
        q["distractors"] = distractors(ans, wrong)
    else:
        q["answer_type"] = "choice"
        q["choices"] = [{"vi": v, "en": e} for v, e in choices]
        q["answer"] = ans  # chỉ số của lựa chọn đúng
    POOL[topic].append(q)


# ---------------------------------------------------------------- SVG helpers
def svg_wrap(w, h, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" '
            f'width="{w}" height="{h}"><g fill="none" stroke="#333" stroke-width="3" '
            f'stroke-linejoin="round" stroke-linecap="round">{body}</g></svg>')


def svg_grid(rows, cols, s=50):
    pad = 6
    b = ""
    for r in range(rows + 1):
        b += f'<line x1="{pad}" y1="{pad + r*s}" x2="{pad + cols*s}" y2="{pad + r*s}"/>'
    for c in range(cols + 1):
        b += f'<line x1="{pad + c*s}" y1="{pad}" x2="{pad + c*s}" y2="{pad + rows*s}"/>'
    return svg_wrap(cols * s + 2 * pad, rows * s + 2 * pad, b)


def svg_fan(k):
    """Tam giác có đỉnh ở trên, k đoạn thẳng nối đỉnh xuống cạnh đáy."""
    W, H, pad = 260, 180, 10
    ax, ay = W / 2, pad
    bx0, bx1, by = pad, W - pad, H - pad
    b = f'<polygon points="{ax},{ay} {bx0},{by} {bx1},{by}"/>'
    for i in range(1, k + 1):
        x = bx0 + (bx1 - bx0) * i / (k + 1)
        b += f'<line x1="{ax}" y1="{ay}" x2="{x:.1f}" y2="{by}"/>'
    return svg_wrap(W, H, b)


def svg_path_grid(rows, cols, s=50):
    pad = 24
    g = svg_grid(rows, cols, s)
    w, h = cols * s + 2 * pad, rows * s + 2 * pad
    b = ""
    for r in range(rows + 1):
        b += f'<line x1="{pad}" y1="{pad + r*s}" x2="{pad + cols*s}" y2="{pad + r*s}"/>'
    for c in range(cols + 1):
        b += f'<line x1="{pad + c*s}" y1="{pad}" x2="{pad + c*s}" y2="{pad + rows*s}"/>'
    b += (f'</g><g font-family="sans-serif" font-size="18" fill="#c0392b">'
          f'<circle cx="{pad}" cy="{pad + rows*s}" r="6"/>'
          f'<text x="{pad - 20}" y="{pad + rows*s + 20}">A</text>'
          f'<circle cx="{pad + cols*s}" cy="{pad}" r="6"/>'
          f'<text x="{pad + cols*s + 6}" y="{pad - 8}">B</text>')
    return svg_wrap(w, h, b)


# ====================================================================== LOGIC
def gen_logic():
    # L1 tuổi
    for _ in range(4):
        n = names(1)[0]; a = R.randint(6, 9); d = R.randint(24, 32)
        add("logic", 1, "age", f"Năm nay {n} {a} tuổi. Mẹ hơn {n} {d} tuổi. Hỏi năm nay mẹ bao nhiêu tuổi?",
            f"This year {n} is {a} years old. Mom is {d} years older than {n}. How old is Mom this year?",
            a + d, f"Tuổi mẹ = {a} + {d} = {a + d} (tuổi).", f"Mom's age = {a} + {d} = {a + d}.",
            "Mẹ hơn bao nhiêu tuổi thì cộng thêm bấy nhiêu.", "'Older by' means add.",
            [("years old", "tuổi"), ("older than", "lớn tuổi hơn")], wrong=(a + d - 10, d - a))
    for _ in range(4):
        n = names(1)[0]; a = R.randint(3, 6); gap = R.randint(24, 30); b = a + gap; c = R.randint(b + 3, b + 12)
        add("logic", 2, "age", f"Khi {n} {a} tuổi thì mẹ {b} tuổi. Khi mẹ {c} tuổi thì {n} bao nhiêu tuổi?",
            f"When {n} was {a} years old, Mom was {b}. When Mom is {c}, how old will {n} be?",
            c - gap, f"Mẹ luôn hơn {n}: {b} − {a} = {gap} tuổi. Khi mẹ {c} tuổi thì {n}: {c} − {gap} = {c - gap} tuổi.",
            f"Mom is always {b} − {a} = {gap} years older. So {n} is {c} − {gap} = {c - gap}.",
            "Hai người hơn kém nhau bao nhiêu tuổi thì mãi mãi hơn kém nhau bấy nhiêu.",
            "The age difference never changes.",
            [("years old", "tuổi"), ("when", "khi")], wrong=(c - b + a + 1, c - a))
    for _ in range(4):
        m = R.randint(28, 36); c = R.randint(5, 9); k = R.randint(2, 6); T = m + c + 2 * k
        add("logic", 3, "age", f"Năm nay mẹ {m} tuổi, con {c} tuổi. Hỏi sau mấy năm nữa thì tổng số tuổi của hai mẹ con là {T} tuổi?",
            f"This year Mom is {m} and her child is {c}. In how many years will the sum of their ages be {T}?",
            k, f"Hiện tổng tuổi là {m} + {c} = {m + c}. Mỗi năm tổng tăng 2 tuổi (mỗi người 1 tuổi). Cần tăng {T} − {m + c} = {T - m - c}, nên cần {T - m - c} : 2 = {k} năm.",
            f"Now the sum is {m + c}. Each year the sum grows by 2. It must grow by {T - m - c}, so {T - m - c} ÷ 2 = {k} years.",
            "Mỗi năm, cả hai người đều thêm 1 tuổi.", "Every year, both people get 1 year older.",
            [("sum", "tổng"), ("in ... years", "sau ... năm")], wrong=(2 * k, k + 1))

    # L2 xếp hàng
    for _ in range(4):
        n = names(1)[0]; a = R.randint(3, 9); b = R.randint(3, 9)
        add("logic", 1, "queue", f"Trong một hàng, {n} đứng thứ {a} tính từ đầu hàng và đứng thứ {b} tính từ cuối hàng. Hỏi hàng có bao nhiêu bạn?",
            f"In a line, {n} is {a}th from the front and {b}th from the back. How many children are in the line?",
            a + b - 1, f"Đếm cả hai phía thì {n} bị đếm 2 lần: {a} + {b} − 1 = {a + b - 1} bạn.",
            f"{n} is counted twice: {a} + {b} − 1 = {a + b - 1}.",
            "Thử vẽ hàng ra giấy và đếm.", "Draw the line and count.",
            [("line", "hàng"), ("front", "đầu hàng"), ("back", "cuối hàng")], wrong=(a + b, a + b - 2))
    for _ in range(3):
        n = names(1)[0]; N = R.randint(10, 25); a = R.randint(2, N - 2)
        add("logic", 1, "queue", f"Một hàng có {N} bạn. {n} đứng thứ {a} tính từ đầu hàng. Hỏi {n} đứng thứ mấy tính từ cuối hàng?",
            f"There are {N} children in a line. {n} is {a}th from the front. What position is {n} from the back?",
            N - a + 1, f"Phía sau {n} có {N} − {a} = {N - a} bạn, nên {n} đứng thứ {N - a} + 1 = {N - a + 1} tính từ cuối.",
            f"There are {N - a} children behind {n}, so {n} is {N - a + 1}th from the back.",
            "Đếm số bạn đứng sau.", "Count the children behind.",
            [("position", "vị trí, thứ tự"), ("from the back", "tính từ cuối")], wrong=(N - a, N - a + 2))
    for _ in range(4):
        x, y = names(2); a = R.randint(3, 7); k = R.randint(2, 6); b = R.randint(3, 7)
        add("logic", 3, "queue", f"Các bạn xếp một hàng dọc. {x} đứng thứ {a} tính từ đầu hàng. {y} đứng sau {x} và đứng thứ {b} tính từ cuối hàng. Giữa {x} và {y} có {k} bạn. Hỏi hàng có bao nhiêu bạn?",
            f"Children stand in a column. {x} is {a}th from the front. {y} is behind {x} and is {b}th from the back. There are {k} children between {x} and {y}. How many children are there?",
            a + k + b, f"Tính từ đầu đến {x}: {a} bạn. Giữa hai bạn: {k} bạn. Tính từ {y} đến cuối: {b} bạn. Tổng: {a} + {k} + {b} = {a + k + b} bạn.",
            f"Front to {x}: {a}. Between: {k}. {y} to the back: {b}. Total {a + k + b}.",
            "Chia hàng thành 3 phần rồi cộng lại.", "Split the line into 3 parts.",
            [("between", "ở giữa"), ("column", "hàng dọc"), ("behind", "phía sau")], wrong=(a + k + b - 1, a + k + b + 1, a + k + b - 2))

    # L3 cái cân
    fruits = [("quả dưa hấu", "watermelon"), ("quả bưởi", "pomelo"), ("quả dứa", "pineapple")]
    small = [("quả táo", "apples"), ("quả cam", "oranges"), ("quả chanh", "lemons")]
    for _ in range(4):
        (bv, be), (sv, se) = R.choice(fruits), R.choice(small); p = R.randint(2, 5); r = R.randint(2, 4)
        add("logic", 1, "balance", f"1 {bv} nặng bằng {p} {sv}. Hỏi {r} {bv} nặng bằng bao nhiêu {sv}?",
            f"1 {be} weighs the same as {p} {se}. {r} {be}s weigh the same as how many {se}?",
            r * p, f"Mỗi {bv} đổi được {p} {sv}, nên {r} {bv} bằng {r} × {p} = {r * p} {sv}.",
            f"{r} × {p} = {r * p}.", "Đổi từng quả một.", "Swap one at a time.",
            [("weigh", "cân nặng"), ("the same as", "bằng với")], wrong=(r + p,))
    for _ in range(4):
        p, q = R.randint(2, 4), R.randint(2, 4); r = R.randint(1, 2)
        add("logic", 2, "balance", f"1 quả dưa hấu nặng bằng {p} quả cam. 1 quả cam nặng bằng {q} quả táo. Hỏi {r} quả dưa hấu nặng bằng bao nhiêu quả táo?",
            f"1 watermelon weighs the same as {p} oranges. 1 orange weighs the same as {q} apples. {r} watermelon(s) weigh the same as how many apples?",
            r * p * q, f"1 dưa = {p} cam = {p} × {q} = {p * q} táo. Vậy {r} dưa = {r} × {p * q} = {r * p * q} táo.",
            f"1 watermelon = {p * q} apples, so {r} = {r * p * q} apples.",
            "Đổi dưa ra cam trước, rồi đổi cam ra táo.", "Change watermelon to oranges first, then to apples.",
            [("balance", "cái cân"), ("weigh", "cân nặng")], wrong=(p + q, r * (p + q)))
    for _ in range(4):
        p, q = R.randint(2, 3), R.randint(2, 4); k, m = R.randint(2, 3), R.randint(2, 3); r = R.randint(2, 3)
        add("logic", 3, "balance", f"{k} quả bưởi nặng bằng {k * p} quả cam. {m} quả cam nặng bằng {m * q} quả chanh. Hỏi {r} quả bưởi nặng bằng bao nhiêu quả chanh?",
            f"{k} pomelos weigh the same as {k * p} oranges. {m} oranges weigh the same as {m * q} lemons. {r} pomelos weigh the same as how many lemons?",
            r * p * q, f"1 bưởi = {k * p} : {k} = {p} cam. 1 cam = {m * q} : {m} = {q} chanh. 1 bưởi = {p * q} chanh, nên {r} bưởi = {r * p * q} chanh.",
            f"1 pomelo = {p} oranges, 1 orange = {q} lemons, so 1 pomelo = {p * q} lemons and {r} pomelos = {r * p * q}.",
            "Tìm xem 1 quả bưởi bằng mấy quả cam.", "First find how many oranges 1 pomelo weighs.",
            [("pomelo", "quả bưởi"), ("lemon", "quả chanh")], wrong=(k * p * q, r * p + q))

    # L4 tính ngược
    for _ in range(3):
        a = R.randint(5, 20); x = R.randint(5, 40); b = x + a
        add("logic", 1, "backward", f"Mai nghĩ ra một số. Lấy số đó cộng {a} thì được {b}. Hỏi Mai nghĩ ra số nào?",
            f"Mai thinks of a number. She adds {a} and gets {b}. What is her number?",
            x, f"Làm ngược lại: {b} − {a} = {x}.", f"Work backwards: {b} − {a} = {x}.",
            "Làm ngược: cộng thì đổi thành trừ.", "Undo adding by subtracting.",
            [("think of a number", "nghĩ ra một số"), ("add", "cộng")], wrong=(b + a,))
    for _ in range(4):
        a = R.randint(5, 25); b = R.randint(3, 15); x = R.randint(10, 40); c = x + a - b
        add("logic", 2, "backward", f"Nam nghĩ ra một số. Lấy số đó cộng {a}, rồi trừ đi {b} thì được {c}. Hỏi Nam nghĩ ra số nào?",
            f"Nam thinks of a number. He adds {a}, then subtracts {b}, and gets {c}. What is his number?",
            x, f"Làm ngược từ cuối: {c} + {b} = {c + b}; {c + b} − {a} = {x}.",
            f"Backwards: {c} + {b} = {c + b}, then {c + b} − {a} = {x}.",
            "Bắt đầu từ kết quả và làm ngược từng bước.", "Start from the result and undo each step.",
            [("subtract", "trừ"), ("then", "rồi")], wrong=(c - b + a, c + a - b))
    for _ in range(4):
        x = R.randint(3, 15); a = R.randint(3, 12)
        if R.random() < 0.5:
            c = 2 * x + a
            add("logic", 3, "backward", f"Lan nghĩ ra một số. Lấy số đó nhân 2, rồi cộng {a} thì được {c}. Hỏi Lan nghĩ ra số nào?",
                f"Lan thinks of a number. She multiplies it by 2, then adds {a}, and gets {c}. What is her number?",
                x, f"Ngược lại: {c} − {a} = {c - a}; {c - a} : 2 = {x}.", f"{c} − {a} = {c - a}; {c - a} ÷ 2 = {x}.",
                "Nhân thì ngược lại là chia.", "Undo multiplying by dividing.",
                [("multiply", "nhân"), ("double", "gấp đôi")], wrong=(c - a, (c + a) // 2))
        else:
            c = 2 * (x + a)
            add("logic", 3, "backward", f"Lan nghĩ ra một số. Lấy số đó cộng {a}, rồi nhân với 2 thì được {c}. Hỏi Lan nghĩ ra số nào?",
                f"Lan thinks of a number. She adds {a}, then multiplies by 2, and gets {c}. What is her number?",
                x, f"Ngược lại: {c} : 2 = {c // 2}; {c // 2} − {a} = {x}.", f"{c} ÷ 2 = {c // 2}; {c // 2} − {a} = {x}.",
                "Bước cuối làm ngược trước.", "Undo the last step first.",
                [("multiply", "nhân"), ("add", "cộng")], wrong=(c // 2, c - a))

    # L5 thứ trong tuần
    def day_q(diff, start, plus, vi_tmpl, en_tmpl):
        ans_d = (start + plus) % 7
        opts = [ans_d] + R.sample([d for d in range(7) if d != ans_d], 3)
        R.shuffle(opts)
        add("logic", diff, "weekday", vi_tmpl, en_tmpl, opts.index(ans_d),
            f"Cứ 7 ngày lại quay về thứ cũ. {plus} = 7 × {plus // 7} + {plus % 7}, nên chỉ cần đếm thêm {plus % 7} ngày từ {DAYS_VI[start]}: được {DAYS_VI[ans_d]}.",
            f"Every 7 days the weekday repeats. Count {plus % 7} more days from {DAYS_EN[start]}: {DAYS_EN[ans_d]}.",
            "Một tuần có 7 ngày.", "A week has 7 days.",
            [("week", "tuần"), ("day", "ngày")], choices=[(DAYS_VI[o], DAYS_EN[o]) for o in opts])
    for _ in range(3):
        s = R.randint(0, 6); p = R.randint(2, 5)
        day_q(1, s, p, f"Hôm nay là {DAYS_VI[s]}. Hỏi {p} ngày nữa là thứ mấy?", f"Today is {DAYS_EN[s]}. What day is it in {p} days?")
    for _ in range(3):
        s = R.randint(0, 6); p = R.randint(8, 16)
        day_q(2, s, p, f"Hôm nay là {DAYS_VI[s]}. Hỏi {p} ngày nữa là thứ mấy?", f"Today is {DAYS_EN[s]}. What day is it in {p} days?")
    for _ in range(3):
        s = R.randint(0, 6); dd = R.randint(15, 30)
        day_q(3, s, dd - 1, f"Ngày 1 của một tháng là {DAYS_VI[s]}. Hỏi ngày {dd} của tháng đó là thứ mấy?",
              f"The 1st of a month is a {DAYS_EN[s]}. What day of the week is the {dd}th of that month?")

    # L6 cưa gỗ, bậc thang, trồng cây
    for _ in range(3):
        n = R.randint(3, 9)
        add("logic", 1, "cut", f"Bác thợ cưa một khúc gỗ thành {n} đoạn. Hỏi bác phải cưa bao nhiêu lần?",
            f"A carpenter saws a log into {n} pieces. How many cuts does he make?",
            n - 1, f"Mỗi lần cưa thêm được 1 đoạn. Từ 1 đoạn lên {n} đoạn cần {n} − 1 = {n - 1} lần cưa.",
            f"Each cut adds one piece, so {n} − 1 = {n - 1} cuts.", "Vẽ khúc gỗ và các vết cưa.", "Draw the log and the cuts.",
            [("saw / cut", "cưa / cắt"), ("piece", "đoạn, mảnh")], wrong=(n, n + 1))
    for _ in range(3):
        n = R.randint(4, 8); t = R.randint(2, 5)
        add("logic", 2, "cut", f"Mỗi lần cưa mất {t} phút. Hỏi cưa một khúc gỗ thành {n} đoạn mất bao nhiêu phút?",
            f"Each cut takes {t} minutes. How long does it take to saw a log into {n} pieces?",
            (n - 1) * t, f"Cần {n} − 1 = {n - 1} lần cưa, mỗi lần {t} phút: {n - 1} × {t} = {(n - 1) * t} phút.",
            f"{n - 1} cuts × {t} minutes = {(n - 1) * t} minutes.", "Số lần cưa ít hơn số đoạn 1.", "Cuts = pieces − 1.",
            [("minute", "phút"), ("each", "mỗi")], wrong=(n * t,))
    for _ in range(3):
        f = R.randint(3, 6); k = R.randint(8, 15)
        add("logic", 2, "stairs", f"Đi từ tầng 1 lên tầng 2 phải bước {k} bậc thang. Hỏi đi từ tầng 1 lên tầng {f} phải bước bao nhiêu bậc? (Các tầng có số bậc bằng nhau.)",
            f"It takes {k} steps to go from floor 1 to floor 2. How many steps from floor 1 to floor {f}? (Each floor has the same number of steps.)",
            (f - 1) * k, f"Từ tầng 1 lên tầng {f} phải đi qua {f} − 1 = {f - 1} đoạn cầu thang: {f - 1} × {k} = {(f - 1) * k} bậc.",
            f"Floor 1 to floor {f} is {f - 1} flights: {f - 1} × {k} = {(f - 1) * k} steps.",
            "Lên tầng 2 chỉ cần 1 đoạn cầu thang.", "Going to floor 2 is only 1 flight.",
            [("floor", "tầng"), ("step", "bậc thang")], wrong=(f * k,))
    for _ in range(3):
        d = R.choice([2, 3, 5]); n = R.randint(4, 9); L = d * n
        add("logic", 3, "trees", f"Một con đường dài {L} m. Người ta trồng cây ở một bên đường, cây nọ cách cây kia {d} m, ở cả hai đầu đường đều có cây. Hỏi trồng bao nhiêu cây?",
            f"A road is {L} m long. Trees are planted on one side, {d} m apart, with a tree at both ends. How many trees are there?",
            n + 1, f"Có {L} : {d} = {n} khoảng cách. Trồng cả hai đầu nên số cây nhiều hơn số khoảng 1: {n} + 1 = {n + 1} cây.",
            f"{L} ÷ {d} = {n} gaps; trees = gaps + 1 = {n + 1}.",
            "Vẽ thử con đường ngắn và đếm cây, đếm khoảng.", "Draw a short road and count trees vs gaps.",
            [("apart", "cách nhau"), ("both ends", "cả hai đầu")], wrong=(n, n - 1))

    # L7 chân gà chó
    for _ in range(3):
        a, b = R.randint(2, 6), R.randint(2, 5)
        add("logic", 1, "legs", f"Trong sân có {a} con gà và {b} con chó. Hỏi có tất cả bao nhiêu cái chân?",
            f"In the yard there are {a} chickens and {b} dogs. How many legs are there in total?",
            2 * a + 4 * b, f"Gà: {a} × 2 = {2 * a} chân. Chó: {b} × 4 = {4 * b} chân. Tổng: {2 * a + 4 * b} chân.",
            f"Chickens {2 * a} legs + dogs {4 * b} legs = {2 * a + 4 * b}.", "Gà có 2 chân, chó có 4 chân.", "A chicken has 2 legs, a dog has 4.",
            [("leg", "chân"), ("chicken", "con gà"), ("dog", "con chó")], wrong=(2 * (a + b), 4 * (a + b)))
    for _ in range(4):
        n = R.randint(5, 10); d = R.randint(1, n - 1); L = 2 * n + 2 * d
        add("logic", 3, "legs", f"Trong chuồng có {n} con gà và thỏ, đếm được tất cả {L} cái chân. Hỏi có bao nhiêu con thỏ?",
            f"There are {n} chickens and rabbits, with {L} legs in total. How many rabbits are there?",
            d, f"Nếu cả {n} con đều là gà thì có {2 * n} chân, thiếu {L} − {2 * n} = {L - 2 * n} chân. Mỗi con thỏ có thêm 2 chân, nên số thỏ là {L - 2 * n} : 2 = {d} con.",
            f"If all {n} were chickens: {2 * n} legs. Extra {L - 2 * n} legs ÷ 2 = {d} rabbits.",
            "Thử giả sử tất cả đều là gà.", "Pretend they are all chickens first.",
            [("rabbit", "con thỏ"), ("in total", "tất cả")], wrong=(n - d, L // 4))

    # L8 so sánh cao thấp (lựa chọn)
    def chain_q(diff, k):
        ppl = names(k)  # thứ tự từ cao nhất -> thấp nhất
        rels = []
        for i in range(k - 1):
            hi, lo = ppl[i], ppl[i + 1]
            if R.random() < 0.5:
                rels.append((f"{hi} cao hơn {lo}", f"{hi} is taller than {lo}"))
            else:
                rels.append((f"{lo} thấp hơn {hi}", f"{lo} is shorter than {hi}"))
        R.shuffle(rels)
        ask_tall = R.random() < 0.5
        ans_name = ppl[0] if ask_tall else ppl[-1]
        opts = ppl[:]; R.shuffle(opts)
        qv = ". ".join(r[0] for r in rels) + ". " + ("Ai cao nhất?" if ask_tall else "Ai thấp nhất?")
        qe = ". ".join(r[1] for r in rels) + ". " + ("Who is the tallest?" if ask_tall else "Who is the shortest?")
        order = " > ".join(ppl)
        add("logic", diff, "compare", qv, qe, opts.index(ans_name),
            f"Xếp từ cao đến thấp: {order}. Vậy {'cao nhất' if ask_tall else 'thấp nhất'} là {ans_name}.",
            f"From tallest to shortest: {order}. So the answer is {ans_name}.",
            "Xếp các bạn thành một hàng từ cao đến thấp.", "Put everyone in order from tallest to shortest.",
            [("taller", "cao hơn"), ("shorter", "thấp hơn"), ("tallest", "cao nhất")],
            choices=[(o, o) for o in opts])
    for _ in range(3): chain_q(1, 3)
    for _ in range(3): chain_q(2, 4)
    for _ in range(2): chain_q(3, 5)

    # L9 chia bi bằng nhau
    for _ in range(4):
        x, y = names(2); b = R.randint(2, 8); yv = R.randint(5, 20); a = yv + 2 * b
        add("logic", 3, "equalize", f"{x} có {a} viên bi. Nếu {x} cho {y} {b} viên thì số bi của hai bạn bằng nhau. Hỏi lúc đầu {y} có bao nhiêu viên bi?",
            f"{x} has {a} marbles. If {x} gives {y} {b} marbles, they will have the same number. How many marbles did {y} have at first?",
            yv, f"Sau khi cho, {x} còn {a} − {b} = {a - b} viên. Lúc đó {y} cũng có {a - b} viên, nên lúc đầu {y} có {a - b} − {b} = {yv} viên.",
            f"After giving, {x} has {a - b}. {y} also has {a - b} after receiving {b}, so at first {y} had {yv}.",
            "Tính số bi của {x} sau khi cho trước.".replace("{x}", x), f"First find how many {x} has after giving.",
            [("marble", "viên bi"), ("give", "cho"), ("at first", "lúc đầu")], wrong=(a - b, a - 2 * b + 1, a - b + b))


# ====================================================================== ARITH
def gen_arith():
    # A1 dãy số
    for _ in range(5):
        s = R.randint(1, 20); d = R.randint(2, 5); seq = [s + d * i for i in range(5)]
        add("arith", 1, "pattern", f"Tìm số tiếp theo của dãy: {', '.join(map(str, seq))}, ...",
            f"Find the next number: {', '.join(map(str, seq))}, ...",
            s + 5 * d, f"Mỗi số hơn số trước {d} đơn vị. Số tiếp theo: {seq[-1]} + {d} = {s + 5 * d}.",
            f"Each number is {d} more than the one before: {seq[-1]} + {d} = {s + 5 * d}.",
            "Lấy số sau trừ số trước xem hơn nhau bao nhiêu.", "Look at the difference between neighbours.",
            [("next number", "số tiếp theo"), ("pattern", "quy luật")], wrong=(seq[-1] + d + 1, seq[-1] + d - 1))
    for _ in range(4):
        s = R.randint(60, 99); d = R.randint(3, 9); seq = [s - d * i for i in range(6)]; hide = R.randint(1, 4)
        shown = [str(v) if i != hide else "__" for i, v in enumerate(seq)]
        add("arith", 2, "pattern", f"Điền số còn thiếu vào chỗ trống: {', '.join(shown)}",
            f"Fill in the missing number: {', '.join(shown)}",
            seq[hide], f"Mỗi số kém số trước {d} đơn vị. Số còn thiếu: {seq[hide - 1]} − {d} = {seq[hide]}.",
            f"Each number is {d} less: {seq[hide - 1]} − {d} = {seq[hide]}.",
            "Dãy số đang giảm dần đều.", "The numbers go down by the same amount.",
            [("missing", "còn thiếu"), ("blank", "chỗ trống")], wrong=(seq[hide] + d, seq[hide] - d))
    for _ in range(4):
        s = R.randint(1, 5); d0 = R.randint(1, 3); seq = [s]
        for i in range(5): seq.append(seq[-1] + d0 + i)
        add("arith", 3, "pattern", f"Tìm số tiếp theo của dãy: {', '.join(map(str, seq))}, ...",
            f"Find the next number: {', '.join(map(str, seq))}, ...",
            seq[-1] + d0 + 5, f"Khoảng cách giữa các số tăng dần: +{d0}, +{d0 + 1}, +{d0 + 2}, +{d0 + 3}, +{d0 + 4}. Tiếp theo là +{d0 + 5}: {seq[-1]} + {d0 + 5} = {seq[-1] + d0 + 5}.",
            f"Differences grow by 1 each time; next add {d0 + 5}: {seq[-1] + d0 + 5}.",
            "Viết ra khoảng cách giữa hai số liền nhau.", "Write down the gaps between neighbours.",
            [("increase", "tăng"), ("difference", "hiệu, khoảng cách")], wrong=(seq[-1] + d0 + 4, seq[-1] + d0 + 6))
    for _ in range(3):
        a = R.randint(1, 4); b = R.choice([10, 20, 5])
        seq = []
        for i in range(3): seq += [a + i, b * (i + 1)]
        add("arith", 3, "pattern", f"Tìm số tiếp theo của dãy: {', '.join(map(str, seq))}, ...",
            f"Find the next number: {', '.join(map(str, seq))}, ...",
            a + 3, f"Dãy gồm hai dãy xen kẽ: {a}, {a + 1}, {a + 2}, ... và {b}, {2 * b}, {3 * b}, ... Số tiếp theo thuộc dãy thứ nhất: {a + 3}.",
            f"Two patterns take turns: {a}, {a + 1}, {a + 2}, ... and {b}, {2 * b}, {3 * b}, ... Next is {a + 3}.",
            "Thử nhìn các số ở vị trí lẻ và vị trí chẵn riêng.", "Look at every other number.",
            [("alternate", "xen kẽ"), ("pattern", "quy luật")], wrong=(4 * b, a + 4))

    # A2 tính nhanh
    for _ in range(4):
        k = R.randint(4, 7); v = R.randint(2, 9)
        add("arith", 1, "quick", f"Tính: {' + '.join([str(v)] * k)} = ?", f"Calculate: {' + '.join([str(v)] * k)} = ?",
            k * v, f"Có {k} số {v}: {v} × {k} = {k * v}.", f"{k} lots of {v}: {v} × {k} = {k * v}.",
            "Cộng nhiều số giống nhau là phép nhân.", "Adding the same number many times is multiplication.",
            [("calculate", "tính"), ("plus", "cộng")], wrong=(k * v + v, k + v))
    for _ in range(4):
        a, b = R.randint(11, 39), R.randint(11, 39); c, d = 100 - a, 100 - b
        terms = [a, b, c, d]; R.shuffle(terms)
        add("arith", 2, "quick", f"Tính nhanh: {' + '.join(map(str, terms))} = ?", f"Calculate quickly: {' + '.join(map(str, terms))} = ?",
            200, f"Ghép cặp tròn trăm: ({a} + {c}) + ({b} + {d}) = 100 + 100 = 200.",
            f"Pair to make hundreds: ({a} + {c}) + ({b} + {d}) = 200.",
            "Tìm hai số cộng lại tròn 100.", "Find pairs that make 100.",
            [("quickly", "nhanh"), ("pair", "cặp")], wrong=(190, 210))
    for _ in range(4):
        st = R.choice([1, 2]); step = R.choice([1, 2]) if st == 1 else 2; n = R.randint(5, 10)
        terms = [st + step * i for i in range(n)]; tot = sum(terms)
        add("arith", 3, "quick", f"Tính: {terms[0]} + {terms[1]} + {terms[2]} + ... + {terms[-1]} = ? (cộng các số cách đều {step} đơn vị)",
            f"Calculate: {terms[0]} + {terms[1]} + {terms[2]} + ... + {terms[-1]} = ? (numbers go up by {step})",
            tot, f"Ghép số đầu với số cuối: {terms[0]} + {terms[-1]} = {terms[0] + terms[-1]}. Có {n} số nên có {n} : 2 cặp như vậy" + (f": {terms[0] + terms[-1]} × {n // 2} = {tot}." if n % 2 == 0 else f" (số ở giữa là {terms[n // 2]}). Tổng = {tot}."),
            f"Pair first and last: each pair is {terms[0] + terms[-1]}. Total = {tot}.",
            "Ghép số đầu với số cuối, số thứ hai với số kế cuối...", "Pair the first with the last, the second with the second last...",
            [("sum", "tổng"), ("first / last", "đầu / cuối")], wrong=(tot - terms[-1], tot + step))

    # A3 điền vào ô trống
    for _ in range(4):
        a = R.randint(5, 40); x = R.randint(5, 50)
        add("arith", 1, "blank", f"Điền số thích hợp vào ô trống: □ + {a} = {x + a}", f"Fill in the box: □ + {a} = {x + a}",
            x, f"□ = {x + a} − {a} = {x}.", f"□ = {x + a} − {a} = {x}.", "Muốn tìm số hạng, lấy tổng trừ số hạng kia.", "Missing addend = total − other addend.",
            [("fill in", "điền"), ("box", "ô trống")], wrong=(x + 2 * a,))
    for _ in range(4):
        a = R.randint(10, 30); b = R.randint(3, 15); x = R.randint(5, 40); c = x + a - b
        add("arith", 2, "blank", f"Điền số thích hợp vào ô trống: □ + {a} − {b} = {c}", f"Fill in the box: □ + {a} − {b} = {c}",
            x, f"□ + {a} = {c} + {b} = {c + b}, nên □ = {c + b} − {a} = {x}.", f"□ + {a} = {c + b}, so □ = {x}.",
            "Làm ngược từ phải sang trái.", "Work backwards from the right.",
            [("equation", "phép tính, đẳng thức"), ("correct", "đúng")], wrong=(c - a + b, c + a - b))
    for _ in range(4):
        a = R.randint(30, 60); x = R.randint(5, 25); b = R.randint(5, 20); c = a - x + b
        add("arith", 3, "blank", f"Điền số thích hợp vào ô trống: {a} − □ + {b} = {c}", f"Fill in the box: {a} − □ + {b} = {c}",
            x, f"{a} − □ = {c} − {b} = {c - b}, nên □ = {a} − {c - b} = {x}.", f"{a} − □ = {c - b}, so □ = {a} − {c - b} = {x}.",
            "Tìm {a} − □ bằng bao nhiêu trước.".replace("{a}", str(a)), f"First find what {a} − □ equals.",
            [("minus", "trừ"), ("equals", "bằng")], wrong=(a - c - b if a - c - b > 0 else x + 7, x + 2 * b))

    # A4 hình đại diện số
    for _ in range(4):
        s = R.randint(3, 12); t = s + R.randint(2, 10)
        add("arith", 2, "symbols", f"Biết: ★ + ★ = {2 * s} và ★ + ▲ = {t}. Hỏi ▲ bằng bao nhiêu?",
            f"★ + ★ = {2 * s} and ★ + ▲ = {t}. What is ▲?",
            t - s, f"★ = {2 * s} : 2 = {s}. ▲ = {t} − {s} = {t - s}.", f"★ = {s}, so ▲ = {t} − {s} = {t - s}.",
            "Tìm ★ trước.", "Find ★ first.", [("star", "ngôi sao"), ("triangle", "tam giác")], wrong=(t - 2 * s if t > 2 * s else t, s))
    for _ in range(4):
        s = R.randint(2, 8); tri = R.randint(3, 10); ci = R.randint(2, 9)
        add("arith", 3, "symbols", f"Biết: ★ + ★ + ★ = {3 * s}; ▲ + ★ = {tri + s}; ● + ▲ = {ci + tri}. Hỏi ● bằng bao nhiêu?",
            f"★ + ★ + ★ = {3 * s}; ▲ + ★ = {tri + s}; ● + ▲ = {ci + tri}. What is ●?",
            ci, f"★ = {3 * s} : 3 = {s}. ▲ = {tri + s} − {s} = {tri}. ● = {ci + tri} − {tri} = {ci}.",
            f"★ = {s}, ▲ = {tri}, ● = {ci}.", "Tìm lần lượt ★, rồi ▲, rồi ●.", "Find ★, then ▲, then ●.",
            [("circle", "hình tròn"), ("star", "ngôi sao")], wrong=(tri, ci + s))

    # A5 lời văn hơn kém
    for _ in range(4):
        x, y = names(2); a = R.randint(10, 40); b = R.randint(3, 15)
        add("arith", 1, "word", f"{x} có {a} cái kẹo. {y} có nhiều hơn {x} {b} cái kẹo. Hỏi {y} có bao nhiêu cái kẹo?",
            f"{x} has {a} candies. {y} has {b} more candies than {x}. How many candies does {y} have?",
            a + b, f"{y} có: {a} + {b} = {a + b} cái kẹo.", f"{a} + {b} = {a + b}.", "'Nhiều hơn' thì làm phép cộng.", "'More than' means add.",
            [("more than", "nhiều hơn"), ("candy", "cái kẹo")], wrong=(a - b,))
    for _ in range(4):
        x, y = names(2); a = R.randint(20, 45); b = R.randint(3, 12)
        add("arith", 2, "word", f"{x} có {a} quyển truyện. {y} có ít hơn {x} {b} quyển. Hỏi cả hai bạn có bao nhiêu quyển truyện?",
            f"{x} has {a} storybooks. {y} has {b} fewer than {x}. How many storybooks do they have altogether?",
            2 * a - b, f"{y} có {a} − {b} = {a - b} quyển. Cả hai: {a} + {a - b} = {2 * a - b} quyển.",
            f"{y} has {a - b}. Altogether {a} + {a - b} = {2 * a - b}.", "Tìm số truyện của {y} trước.".replace("{y}", y), f"First find how many {y} has.",
            [("fewer than", "ít hơn"), ("altogether", "cả hai, tất cả")], wrong=(a - b, 2 * a + b, a + b))
    for _ in range(4):
        x, y = names(2); small = R.randint(10, 30); d = R.randint(2, 12); s = 2 * small + d
        add("arith", 3, "word", f"{x} và {y} có tất cả {s} viên bi. {x} có nhiều hơn {y} {d} viên. Hỏi {y} có bao nhiêu viên bi?",
            f"{x} and {y} have {s} marbles altogether. {x} has {d} more than {y}. How many marbles does {y} have?",
            small, f"Nếu bớt đi {d} viên của {x} thì hai bạn có số bi bằng nhau: {s} − {d} = {s - d}. Số bi của {y}: {s - d} : 2 = {small} viên.",
            f"Take away the extra {d}: {s - d}, then split in half: {small}.",
            "Bớt phần hơn đi để hai phần bằng nhau.", "Remove the difference so both parts are equal.",
            [("altogether", "tất cả"), ("more than", "nhiều hơn")], wrong=(small + d, (s + d) // 2 + 1, s - d))

    # A6 nhân chia lớp 2
    for _ in range(4):
        b = R.choice([2, 3, 4, 5]); k = R.randint(3, 9)
        add("arith", 1, "multiply", f"Mỗi hộp có {b} cái bút. Hỏi {k} hộp như thế có bao nhiêu cái bút?",
            f"Each box has {b} pens. How many pens are in {k} boxes?",
            b * k, f"{b} × {k} = {b * k} cái bút.", f"{b} × {k} = {b * k}.", "Lấy số bút một hộp nhân với số hộp.", "Pens per box × number of boxes.",
            [("each", "mỗi"), ("box", "hộp")], wrong=(b + k,))
    for _ in range(4):
        p = R.choice([2, 3, 4, 5]); each = R.randint(3, 9); tot = p * each
        add("arith", 2, "multiply", f"Cô giáo chia đều {tot} quả cam cho {p} bạn. Hỏi mỗi bạn được mấy quả cam?",
            f"The teacher shares {tot} oranges equally among {p} children. How many oranges does each child get?",
            each, f"{tot} : {p} = {each} quả.", f"{tot} ÷ {p} = {each}.", "Chia đều là làm phép chia.", "Share equally means divide.",
            [("share equally", "chia đều"), ("each", "mỗi")], wrong=(tot - p,))
    for _ in range(4):
        t = R.randint(4, 8); c = R.choice([2, 4]); broken = R.randint(2, 5)
        add("arith", 3, "multiply", f"Lớp học có {t} cái bàn, mỗi bàn kê {c} cái ghế. Có {broken} cái ghế bị hỏng được mang đi sửa. Hỏi trong lớp còn bao nhiêu cái ghế?",
            f"A classroom has {t} tables with {c} chairs at each table. {broken} chairs are broken and taken away. How many chairs are left?",
            t * c - broken, f"Lúc đầu có {t} × {c} = {t * c} ghế. Còn lại: {t * c} − {broken} = {t * c - broken} ghế.",
            f"{t} × {c} = {t * c}; {t * c} − {broken} = {t * c - broken}.", "Tính số ghế lúc đầu trước.", "First find how many chairs there were.",
            [("chair", "cái ghế"), ("left", "còn lại")], wrong=(t * c, t + c - broken))

    # A7 tiền
    for _ in range(4):
        p = R.choice([2, 3, 4, 5]); k = R.randint(2, 4); paid = R.choice([20, 50]) if p * k < 20 else 50
        add("arith", 2, "money", f"Một quyển vở giá {p} nghìn đồng. Mẹ mua {k} quyển và đưa cô bán hàng {paid} nghìn đồng. Hỏi cô bán hàng trả lại mẹ bao nhiêu nghìn đồng?",
            f"A notebook costs {p} thousand dong. Mom buys {k} notebooks and pays with {paid} thousand dong. How much change (in thousand dong) does she get?",
            paid - p * k, f"Tiền vở: {p} × {k} = {p * k} nghìn. Trả lại: {paid} − {p * k} = {paid - p * k} nghìn đồng.",
            f"Cost {p * k}; change {paid} − {p * k} = {paid - p * k}.", "Tính tiền mua vở trước.", "First find the cost.",
            [("cost", "giá"), ("change", "tiền thối lại")], wrong=(p * k, paid - p))


# ===================================================================== NUMBER
def gen_number():
    # N1 đếm chẵn lẻ
    for _ in range(4):
        a = R.randint(1, 10); b = a + R.randint(8, 14); odd = R.random() < 0.5
        cnt = sum(1 for v in range(a, b + 1) if v % 2 == (1 if odd else 0))
        add("number", 1, "parity", f"Từ {a} đến {b} có bao nhiêu số {'lẻ' if odd else 'chẵn'}?",
            f"How many {'odd' if odd else 'even'} numbers are there from {a} to {b}?",
            cnt, f"Liệt kê các số {'lẻ' if odd else 'chẵn'}: {', '.join(str(v) for v in range(a, b + 1) if v % 2 == (1 if odd else 0))}. Có {cnt} số.",
            f"List them: {', '.join(str(v) for v in range(a, b + 1) if v % 2 == (1 if odd else 0))}. That is {cnt}.",
            "Số chẵn có chữ số tận cùng 0, 2, 4, 6, 8.", "Even numbers end in 0, 2, 4, 6, 8.",
            [("odd number", "số lẻ"), ("even number", "số chẵn")], wrong=(b - a + 1 - cnt + (1 if (b - a) % 2 == 1 else 0) + 1, cnt + 1))
    for _ in range(4):
        a = R.randint(10, 40); b = R.randint(60, 99); odd = R.random() < 0.5
        cnt = sum(1 for v in range(a, b + 1) if v % 2 == (1 if odd else 0))
        add("number", 2, "parity", f"Có bao nhiêu số {'lẻ' if odd else 'chẵn'} lớn hơn {a - 1} và nhỏ hơn {b + 1}?",
            f"How many {'odd' if odd else 'even'} numbers are greater than {a - 1} and less than {b + 1}?",
            cnt, f"Ta đếm các số {'lẻ' if odd else 'chẵn'} từ {a} đến {b}. Số đầu là {min(v for v in range(a, b + 1) if v % 2 == (1 if odd else 0))}, số cuối là {max(v for v in range(a, b + 1) if v % 2 == (1 if odd else 0))}, hai số liền nhau cách 2 đơn vị: ({max(v for v in range(a, b + 1) if v % 2 == (1 if odd else 0))} − {min(v for v in range(a, b + 1) if v % 2 == (1 if odd else 0))}) : 2 + 1 = {cnt} số.",
            f"Count from {a} to {b}: (last − first) ÷ 2 + 1 = {cnt}.",
            "Số các số cách đều = (số cuối − số đầu) : khoảng cách + 1.", "Count = (last − first) ÷ gap + 1.",
            [("greater than", "lớn hơn"), ("less than", "nhỏ hơn")], wrong=(cnt - 1, cnt + 1))

    # N2 tổng chữ số
    for k in [3, 5, 7, 9, 11, 12, 15, 16]:
        nums = [v for v in range(10, 100) if v // 10 + v % 10 == k]
        add("number", 2 if k <= 9 else 3, "digitsum", f"Có bao nhiêu số có hai chữ số mà tổng hai chữ số của nó bằng {k}?",
            f"How many 2-digit numbers have digits that add up to {k}?",
            len(nums), f"Đó là các số: {', '.join(map(str, nums))}. Có {len(nums)} số.",
            f"They are: {', '.join(map(str, nums))}. So {len(nums)}.",
            "Cho chữ số hàng chục chạy từ 1 đến 9 rồi tìm chữ số hàng đơn vị.", "Try tens digit 1, 2, 3, ... and find the ones digit.",
            [("2-digit number", "số có hai chữ số"), ("digit", "chữ số"), ("add up to", "có tổng bằng")], wrong=(len(nums) + 1, len(nums) - 1))

    # N3 lập số lớn nhất / nhỏ nhất
    for _ in range(4):
        ds = R.sample(range(1, 10), 3)
        mx = int("".join(map(str, sorted(ds, reverse=True)[:2])))
        add("number", 1, "cards", f"Từ ba tấm thẻ ghi số {', '.join(map(str, ds))}, hãy lập số lớn nhất có hai chữ số (mỗi thẻ dùng một lần).",
            f"Using cards {', '.join(map(str, ds))}, make the greatest 2-digit number (use each card once).",
            mx, f"Hàng chục chọn số lớn nhất, hàng đơn vị chọn số lớn thứ hai: {mx}.",
            f"Biggest digit in the tens place, next biggest in the ones place: {mx}.",
            "Chữ số hàng chục quan trọng hơn chữ số hàng đơn vị.", "The tens digit matters more.",
            [("greatest", "lớn nhất"), ("card", "tấm thẻ")], wrong=(int(str(mx)[::-1]),))
    for _ in range(4):
        ds = [0] + R.sample(range(1, 10), 2)
        perms = [int("".join(map(str, p))) for p in itertools.permutations(ds, 3) if p[0] != 0]
        mn = min(perms)
        add("number", 2, "cards", f"Từ ba tấm thẻ ghi số {', '.join(map(str, sorted(ds)))}, hãy lập số nhỏ nhất có ba chữ số (mỗi thẻ dùng một lần).",
            f"Using cards {', '.join(map(str, sorted(ds)))}, make the smallest 3-digit number (use each card once).",
            mn, f"Chữ số 0 không đứng đầu được, nên hàng trăm là chữ số nhỏ nhất khác 0, sau đó đặt 0, rồi chữ số còn lại: {mn}.",
            f"0 cannot go first, so start with the smallest non-zero digit, then 0: {mn}.",
            "Số có ba chữ số không bắt đầu bằng 0.", "A 3-digit number cannot start with 0.",
            [("smallest", "nhỏ nhất"), ("3-digit number", "số có ba chữ số")], wrong=(int("".join(map(str, sorted(ds[1:]) + [0]))), int("0" + "".join(map(str, sorted(ds[1:])))) if False else mn + 9))
    for _ in range(4):
        ds = R.sample(range(1, 10), 3)
        perms = [int("".join(map(str, p))) for p in itertools.permutations(ds, 2)]
        add("number", 3, "cards", f"Từ ba tấm thẻ ghi số {', '.join(map(str, ds))}, lập các số có hai chữ số khác nhau (mỗi số dùng hai thẻ khác nhau). Hỏi hiệu của số lớn nhất và số nhỏ nhất lập được là bao nhiêu?",
            f"Using cards {', '.join(map(str, ds))}, make 2-digit numbers with two different cards. What is the difference between the greatest and the smallest?",
            max(perms) - min(perms), f"Số lớn nhất: {max(perms)}. Số nhỏ nhất: {min(perms)}. Hiệu: {max(perms)} − {min(perms)} = {max(perms) - min(perms)}.",
            f"Greatest {max(perms)}, smallest {min(perms)}, difference {max(perms) - min(perms)}.",
            "Tìm số lớn nhất và số nhỏ nhất trước.", "Find the greatest and the smallest first.",
            [("difference", "hiệu"), ("greatest / smallest", "lớn nhất / nhỏ nhất")], wrong=(max(perms) + min(perms), max(perms) - min(perms) + 9))

    # N4 số chữ số viết từ 1 đến n
    for n in [12, 15, 20, 25, 30, 45, 60, 99]:
        tot = sum(len(str(v)) for v in range(1, n + 1))
        diff = 2 if n <= 25 else 3
        add("number", diff, "digitcount", f"Bạn Vy viết liền các số từ 1 đến {n}. Hỏi Vy đã viết tất cả bao nhiêu chữ số?",
            f"Vy writes all the numbers from 1 to {n}. How many digits does she write in total?",
            tot, f"Từ 1 đến 9 có 9 số, mỗi số 1 chữ số: 9 chữ số. Từ 10 đến {n} có {n - 9} số, mỗi số 2 chữ số: {2 * (n - 9)} chữ số. Tổng: 9 + {2 * (n - 9)} = {tot}.",
            f"1–9: 9 digits. 10–{n}: {n - 9} numbers × 2 = {2 * (n - 9)}. Total {tot}.",
            "Tách thành số có một chữ số và số có hai chữ số.", "Split into 1-digit and 2-digit numbers.",
            [("digit", "chữ số"), ("in total", "tất cả")], wrong=(n, 2 * n))

    # N5 đếm số lần xuất hiện chữ số
    for n, d in [(20, 1), (30, 2), (40, 3), (50, 1), (35, 5), (45, 4)]:
        c = sum(str(v).count(str(d)) for v in range(1, n + 1))
        add("number", 3, "digitfreq", f"Viết các số từ 1 đến {n}. Hỏi chữ số {d} được viết bao nhiêu lần?",
            f"Write the numbers from 1 to {n}. How many times is the digit {d} written?",
            c, f"Đếm ở hàng đơn vị và hàng chục: các số chứa chữ số {d} là " + ", ".join(str(v) for v in range(1, n + 1) if str(d) in str(v)) + f". Số {d}{d} (nếu có) được tính 2 lần. Tổng: {c} lần.",
            f"Count in the ones place and the tens place separately. Total {c}.",
            "Đếm riêng hàng đơn vị, rồi hàng chục.", "Count the ones place, then the tens place.",
            [("times", "lần"), ("digit", "chữ số")], wrong=(c - 1, c + 1))

    # N6 tìm số theo dấu hiệu
    pool = []
    for s in range(3, 17):
        for d in range(1, 9):
            sol = [v for v in range(10, 100) if v // 10 + v % 10 == s and v // 10 - v % 10 == d]
            if len(sol) == 1: pool.append((s, d, sol[0]))
    for s, d, v in R.sample(pool, 5):
        add("number", 2, "clues", f"Tìm số có hai chữ số, biết tổng hai chữ số bằng {s} và chữ số hàng chục hơn chữ số hàng đơn vị {d}.",
            f"Find the 2-digit number whose digits add up to {s} and whose tens digit is {d} more than its ones digit.",
            v, f"Chữ số hàng chục: ({s} + {d}) : 2 = {v // 10}. Chữ số hàng đơn vị: {s} − {v // 10} = {v % 10}. Số cần tìm: {v}.",
            f"Tens digit ({s} + {d}) ÷ 2 = {v // 10}, ones digit {v % 10}. The number is {v}.",
            "Thử các cặp chữ số có tổng bằng {s}.".replace("{s}", str(s)), f"Try pairs of digits that add up to {s}.",
            [("tens digit", "chữ số hàng chục"), ("ones digit", "chữ số hàng đơn vị")], wrong=(int(str(v)[::-1]), v + 9))
    clue_sets = []
    for lo in range(40, 80, 10):
        for s in range(5, 16):
            sol = [v for v in range(10, 100) if v // 10 + v % 10 == s and v % 2 == 1 and v > lo and v // 10 > v % 10]
            if len(sol) == 1: clue_sets.append((lo, s, sol[0]))
    for lo, s, v in R.sample(clue_sets, min(4, len(clue_sets))):
        add("number", 3, "clues", f"Tìm số có hai chữ số thỏa mãn: là số lẻ, lớn hơn {lo}, tổng hai chữ số bằng {s}, và chữ số hàng chục lớn hơn chữ số hàng đơn vị.",
            f"Find the 2-digit number that is odd, greater than {lo}, has digits adding up to {s}, and has a tens digit greater than its ones digit.",
            v, f"Liệt kê các số có tổng chữ số bằng {s}, rồi loại dần theo từng điều kiện. Chỉ còn lại số {v}.",
            f"List numbers with digit sum {s}, then cross out by each clue. Only {v} is left.",
            "Liệt kê rồi gạch bỏ các số không thỏa mãn.", "List them, then cross out.",
            [("odd", "lẻ"), ("greater than", "lớn hơn")], wrong=(int(str(v)[::-1]), v - 9))

    # N7 số tròn chục, giá trị chữ số
    for _ in range(3):
        a = R.randint(1, 4) * 10; b = R.randint(6, 9) * 10
        add("number", 1, "round", f"Có bao nhiêu số tròn chục từ {a} đến {b}?", f"How many multiples of ten are there from {a} to {b}?",
            (b - a) // 10 + 1, f"Đó là: {', '.join(str(v) for v in range(a, b + 1, 10))}. Có {(b - a) // 10 + 1} số.",
            f"{', '.join(str(v) for v in range(a, b + 1, 10))}: {(b - a) // 10 + 1} numbers.",
            "Số tròn chục có chữ số tận cùng là 0.", "Multiples of ten end in 0.",
            [("multiple of ten", "số tròn chục")], wrong=((b - a) // 10,))
    for _ in range(4):
        t = R.randint(2, 9); o = R.randint(0, 9); extra = R.randint(1, 3)
        add("number", 1, "place", f"Số gồm {t} chục và {o} đơn vị cộng thêm {extra} chục nữa là số nào?",
            f"What number is {t} tens and {o} ones, plus {extra} more tens?",
            (t + extra) * 10 + o if t + extra <= 9 else (t + extra) * 10 + o,
            f"{t} chục {o} đơn vị là {10 * t + o}. Thêm {extra} chục ({10 * extra}): {10 * t + o} + {10 * extra} = {10 * t + o + 10 * extra}.",
            f"{10 * t + o} + {10 * extra} = {10 * t + o + 10 * extra}.", "1 chục = 10.", "1 ten = 10.",
            [("tens", "chục"), ("ones", "đơn vị")], wrong=(10 * t + o + extra,))
    fixed = [
        (1, "Số lớn nhất có hai chữ số khác nhau là số nào?", "What is the greatest 2-digit number with two different digits?", 98, "Hàng chục là 9, hàng đơn vị lớn nhất khác 9 là 8: 98.", "Tens 9, ones the largest digit that is not 9: 98.", (99,)),
        (2, "Số bé nhất có hai chữ số mà tổng hai chữ số bằng 10 là số nào?", "What is the smallest 2-digit number whose digits add up to 10?", 19, "Muốn số bé nhất thì hàng chục nhỏ nhất: hàng chục 1, hàng đơn vị 9. Số 19.", "Make the tens digit as small as possible: 19.", (91, 28)),
        (2, "Có bao nhiêu số có hai chữ số?", "How many 2-digit numbers are there?", 90, "Từ 10 đến 99: 99 − 10 + 1 = 90 số.", "From 10 to 99: 99 − 10 + 1 = 90.", (89, 99)),
        (2, "Có bao nhiêu số có hai chữ số mà hai chữ số giống nhau?", "How many 2-digit numbers have two identical digits?", 9, "11, 22, 33, 44, 55, 66, 77, 88, 99: có 9 số.", "11, 22, ..., 99: 9 numbers.", (10,)),
        (3, "Có bao nhiêu số có hai chữ số mà chữ số hàng chục lớn hơn chữ số hàng đơn vị?", "How many 2-digit numbers have a tens digit greater than the ones digit?", 45, "Hàng chục 1: 1 số (10); hàng chục 2: 2 số; ...; hàng chục 9: 9 số. Tổng 1 + 2 + ... + 9 = 45.", "Tens 1 gives 1 number, tens 2 gives 2, ..., tens 9 gives 9: 1 + 2 + ... + 9 = 45.", (36, 44)),
        (3, "Có bao nhiêu số có hai chữ số mà chữ số hàng đơn vị lớn hơn chữ số hàng chục?", "How many 2-digit numbers have a ones digit greater than the tens digit?", 36, "Hàng chục 1: 8 số (12 → 19); hàng chục 2: 7 số; ...; hàng chục 8: 1 số (89). Tổng 8 + 7 + ... + 1 = 36.", "Tens 1 gives 8, tens 2 gives 7, ..., tens 8 gives 1: 36.", (45, 35)),
    ]
    for d, qv, qe, a, ev, ee, w in fixed:
        add("number", d, "fixed", qv, qe, a, ev, ee, "Thử liệt kê một vài số để tìm quy luật.", "List a few to see the pattern.",
            [("digit", "chữ số"), ("2-digit number", "số có hai chữ số")], wrong=w)
    for _ in range(2):
        pass
    add("number", 2, "parityrule", "Cộng ba số lẻ với nhau thì được kết quả là số chẵn hay số lẻ?",
        "If you add three odd numbers, is the answer odd or even?", 0,
        "Lẻ + lẻ = chẵn; chẵn + lẻ = lẻ. Ví dụ 1 + 3 + 5 = 9 là số lẻ.", "Odd + odd = even; even + odd = odd. Example: 1 + 3 + 5 = 9 (odd).",
        "Thử với ba số lẻ nhỏ.", "Try three small odd numbers.", [("odd", "lẻ"), ("even", "chẵn")],
        choices=[("Số lẻ", "Odd"), ("Số chẵn", "Even"), ("Có thể chẵn hoặc lẻ", "It depends")])
    add("number", 2, "parityrule", "Cộng bốn số lẻ với nhau thì được kết quả là số chẵn hay số lẻ?",
        "If you add four odd numbers, is the answer odd or even?", 1,
        "Hai số lẻ cộng lại được số chẵn. Bốn số lẻ là hai cặp, mỗi cặp chẵn, nên tổng chẵn. Ví dụ 1 + 3 + 5 + 7 = 16.",
        "Two odds make an even; four odds are two pairs, so the sum is even. Example: 1 + 3 + 5 + 7 = 16.",
        "Ghép thành từng cặp.", "Make pairs.", [("odd", "lẻ"), ("even", "chẵn")],
        choices=[("Số lẻ", "Odd"), ("Số chẵn", "Even"), ("Có thể chẵn hoặc lẻ", "It depends")])


# ======================================================================== GEO
def gen_geo():
    def squares(r, c): return sum((r - i) * (c - i) for i in range(min(r, c)))
    for r, c, d in [(1, 3, 1), (1, 4, 1), (2, 2, 2), (2, 3, 2), (2, 4, 2), (3, 3, 3), (3, 4, 3), (2, 5, 3)]:
        n = squares(r, c)
        add("geo", d, "countsq", "Có tất cả bao nhiêu hình vuông trong hình dưới đây?", "How many squares are there in the figure below?",
            n, f"Hình vuông nhỏ (1 ô): {r * c}. " + " ".join(f"Hình vuông {k}×{k} ô: {(r - k + 1) * (c - k + 1)}." for k in range(2, min(r, c) + 1)) + f" Tổng: {n} hình vuông.",
            f"1×1 squares: {r * c}. " + " ".join(f"{k}×{k} squares: {(r - k + 1) * (c - k + 1)}." for k in range(2, min(r, c) + 1)) + f" Total {n}.",
            "Đừng quên các hình vuông to ghép từ nhiều ô.", "Don't forget the bigger squares made of several small ones.",
            [("square", "hình vuông"), ("figure", "hình vẽ")], wrong=(r * c, n + 1), figure=svg_grid(r, c))
    for n, d in [(2, 1), (3, 2), (4, 2), (5, 3), (6, 3)]:
        tot = n * (n + 1) // 2
        add("geo", d, "countrect", "Có tất cả bao nhiêu hình chữ nhật trong hình dưới đây? (Hình vuông cũng là hình chữ nhật.)",
            "How many rectangles are there in the figure below? (A square is also a rectangle.)",
            tot, f"Hình gồm {n} ô. Hình chữ nhật 1 ô: {n}; 2 ô: {n - 1}; ...; {n} ô: 1. Tổng: {' + '.join(str(n - k) for k in range(n))} = {tot}.",
            f"1 cell: {n}, 2 cells: {n - 1}, ..., {n} cells: 1. Total {tot}.",
            "Đếm theo số ô ghép lại: 1 ô, 2 ô, 3 ô...", "Count by size: 1 cell, 2 cells, 3 cells...",
            [("rectangle", "hình chữ nhật"), ("square", "hình vuông")], wrong=(n, tot - 1), figure=svg_grid(1, n))
    for k, d in [(1, 1), (2, 2), (3, 2), (4, 3), (5, 3)]:
        tot = (k + 2) * (k + 1) // 2
        add("geo", d, "counttri", "Có tất cả bao nhiêu hình tam giác trong hình dưới đây?", "How many triangles are there in the figure below?",
            tot, f"Cạnh đáy bị chia thành {k + 1} đoạn nhỏ. Mỗi tam giác ứng với một đoạn trên cạnh đáy (gồm 1 hoặc nhiều đoạn nhỏ liền nhau): {' + '.join(str(k + 1 - i) for i in range(k + 1))} = {tot}.",
            f"The base is split into {k + 1} parts. Each triangle matches a piece of the base: {' + '.join(str(k + 1 - i) for i in range(k + 1))} = {tot}.",
            "Mỗi hình tam giác có chung đỉnh trên cùng. Hãy đếm theo cạnh đáy.", "All triangles share the top corner. Count using the base.",
            [("triangle", "hình tam giác"), ("base", "cạnh đáy")], wrong=(k + 1, tot - 1), figure=svg_fan(k))
    for _ in range(3):
        a = R.randint(3, 9)
        add("geo", 1, "perim", f"Một hình vuông có cạnh dài {a} cm. Hỏi chu vi hình vuông đó là bao nhiêu xăng-ti-mét?",
            f"A square has sides of {a} cm. What is its perimeter in cm?",
            4 * a, f"Hình vuông có 4 cạnh bằng nhau: {a} × 4 = {4 * a} cm.", f"{a} × 4 = {4 * a} cm.",
            "Chu vi là tổng độ dài các cạnh.", "Perimeter = total length of all sides.",
            [("perimeter", "chu vi"), ("side", "cạnh")], wrong=(2 * a, a * a))
    for _ in range(3):
        l, w = R.randint(5, 12), R.randint(2, 4)
        add("geo", 1, "perim", f"Một hình chữ nhật có chiều dài {l} cm, chiều rộng {w} cm. Hỏi chu vi hình chữ nhật là bao nhiêu xăng-ti-mét?",
            f"A rectangle is {l} cm long and {w} cm wide. What is its perimeter in cm?",
            2 * (l + w), f"Chu vi = {l} + {w} + {l} + {w} = {2 * (l + w)} cm.", f"{l} + {w} + {l} + {w} = {2 * (l + w)} cm.",
            "Hình chữ nhật có 2 chiều dài và 2 chiều rộng.", "A rectangle has 2 lengths and 2 widths.",
            [("length", "chiều dài"), ("width", "chiều rộng")], wrong=(l + w,))
    for _ in range(3):
        a = R.randint(3, 9)
        add("geo", 2, "perim", f"Một hình vuông có chu vi {4 * a} cm. Hỏi cạnh của hình vuông dài bao nhiêu xăng-ti-mét?",
            f"A square has a perimeter of {4 * a} cm. How long is each side?",
            a, f"4 cạnh bằng nhau: {4 * a} : 4 = {a} cm.", f"{4 * a} ÷ 4 = {a} cm.", "Hình vuông có 4 cạnh bằng nhau.", "All 4 sides are equal.",
            [("perimeter", "chu vi"), ("side", "cạnh")], wrong=(2 * a,))
    for _ in range(3):
        l, w = R.randint(6, 12), R.randint(2, 5)
        add("geo", 3, "perim", f"Một hình chữ nhật có chu vi {2 * (l + w)} cm, chiều dài {l} cm. Hỏi chiều rộng là bao nhiêu xăng-ti-mét?",
            f"A rectangle has a perimeter of {2 * (l + w)} cm and a length of {l} cm. What is its width?",
            w, f"Một chiều dài cộng một chiều rộng bằng nửa chu vi: {2 * (l + w)} : 2 = {l + w} cm. Chiều rộng: {l + w} − {l} = {w} cm.",
            f"Half the perimeter is {l + w}; width = {l + w} − {l} = {w} cm.", "Nửa chu vi = dài + rộng.", "Half the perimeter = length + width.",
            [("width", "chiều rộng"), ("half", "một nửa")], wrong=(2 * (l + w) - l, l + w))
    for n, d in [(3, 2), (4, 2), (6, 2), (5, 3)]:
        add("geo", d, "matches", f"Dùng que diêm xếp {n} hình vuông thành một hàng ngang (hai hình vuông cạnh nhau dùng chung một que). Hỏi cần bao nhiêu que diêm?",
            f"Matchsticks make {n} squares in a row (neighbouring squares share a stick). How many matchsticks are needed?",
            3 * n + 1, f"Hình vuông đầu cần 4 que, mỗi hình vuông sau chỉ cần thêm 3 que: 4 + 3 × {n - 1} = {3 * n + 1} que.",
            f"First square 4 sticks, each next one 3 more: 4 + 3 × {n - 1} = {3 * n + 1}.",
            "Vẽ 2 hình rồi 3 hình để thấy quy luật.", "Draw 2 then 3 squares to see the pattern.",
            [("matchstick", "que diêm"), ("in a row", "thành một hàng")], wrong=(4 * n, 3 * n), figure=svg_grid(1, n, 40))
    for n, d in [(3, 2), (5, 3)]:
        add("geo", d, "matches", f"Dùng que diêm xếp {n} hình tam giác thành một hàng (hai tam giác cạnh nhau dùng chung một que). Hỏi cần bao nhiêu que diêm?",
            f"Matchsticks make {n} triangles in a row (neighbouring triangles share a stick). How many matchsticks are needed?",
            2 * n + 1, f"Tam giác đầu cần 3 que, mỗi tam giác sau cần thêm 2 que: 3 + 2 × {n - 1} = {2 * n + 1} que.",
            f"3 + 2 × {n - 1} = {2 * n + 1}.", "Mỗi tam giác mới dùng chung 1 que với tam giác trước.", "Each new triangle shares one stick.",
            [("triangle", "tam giác"), ("share", "dùng chung")], wrong=(3 * n,))
    for n in [3, 4]:
        add("geo", 3, "matches", f"Dùng que diêm xếp một hình chữ nhật gồm 2 hàng, mỗi hàng {n} ô vuông (các ô cạnh nhau dùng chung que). Hỏi cần bao nhiêu que diêm?",
            f"Matchsticks make a grid of 2 rows with {n} squares in each row (shared sides use one stick). How many matchsticks are needed?",
            5 * n + 2, f"Que nằm ngang: 3 hàng que × {n} = {3 * n}. Que đứng: 2 hàng × {n + 1} = {2 * (n + 1)}. Tổng: {5 * n + 2} que.",
            f"Horizontal {3 * n} + vertical {2 * (n + 1)} = {5 * n + 2}.", "Đếm riêng que nằm ngang và que đứng.", "Count horizontal and vertical sticks separately.",
            [("horizontal", "nằm ngang"), ("vertical", "thẳng đứng")], wrong=(8 * n, 6 * n + 1), figure=svg_grid(2, n, 40))
    for _ in range(3):
        a, b = R.randint(2, 5), R.randint(1, 4)
        add("geo", 1, "sides", f"Có {a} hình tam giác và {b} hình vuông. Hỏi tất cả có bao nhiêu cạnh?",
            f"There are {a} triangles and {b} squares. How many sides are there in total?",
            3 * a + 4 * b, f"Tam giác: {a} × 3 = {3 * a}. Hình vuông: {b} × 4 = {4 * b}. Tổng: {3 * a + 4 * b} cạnh.",
            f"{3 * a} + {4 * b} = {3 * a + 4 * b}.", "Tam giác có 3 cạnh, hình vuông có 4 cạnh.", "A triangle has 3 sides, a square has 4.",
            [("side", "cạnh"), ("corner", "góc, đỉnh")], wrong=(4 * (a + b), 3 * (a + b)))
    for n, k in [(3, 1), (4, 1), (4, 2), (5, 2)]:
        tot = sum(1 + k * i for i in range(n))
        add("geo", 2 if k == 1 else 3, "cubes", f"Bé xếp các khối lập phương thành một tháp {n} tầng. Tầng trên cùng có 1 khối, mỗi tầng bên dưới có nhiều hơn tầng ngay trên nó {k} khối. Hỏi cả tháp có bao nhiêu khối?",
            f"A tower has {n} layers of cubes. The top layer has 1 cube, and each layer has {k} more cubes than the layer above it. How many cubes are there?",
            tot, f"Các tầng: {', '.join(str(1 + k * i) for i in range(n))}. Tổng: {' + '.join(str(1 + k * i) for i in range(n))} = {tot} khối.",
            f"Layers: {', '.join(str(1 + k * i) for i in range(n))}. Total {tot}.", "Viết số khối của từng tầng rồi cộng.", "Write each layer, then add.",
            [("cube", "khối lập phương"), ("layer", "tầng")], wrong=(1 + k * (n - 1), tot + 1))
    add("geo", 3, "cubes", "Bé xếp tháp khối lập phương 3 tầng: tầng trên cùng 1 khối, tầng giữa là hình vuông 2 × 2 khối, tầng dưới cùng là hình vuông 3 × 3 khối. Hỏi tháp có bao nhiêu khối?",
        "A tower has 3 layers: the top is 1 cube, the middle is a 2 × 2 square of cubes, the bottom is a 3 × 3 square. How many cubes are there?",
        14, "1 + 4 + 9 = 14 khối.", "1 + 4 + 9 = 14.", "2 × 2 = 4, 3 × 3 = 9.", "2 × 2 = 4, 3 × 3 = 9.", [("cube", "khối lập phương")], wrong=(6, 13))
    for k, s in [(2, 3), (3, 2), (3, 4), (4, 3)]:
        add("geo", 2 if k <= 3 and s <= 3 else 3, "shapeperim", f"Ghép {k} hình vuông, mỗi hình có cạnh {s} cm, thành một hàng như hình dưới. Hỏi chu vi của hình mới là bao nhiêu xăng-ti-mét?",
            f"{k} squares with sides of {s} cm are joined in a row as shown. What is the perimeter of the new shape?",
            2 * (k * s + s), f"Hình mới là hình chữ nhật dài {k} × {s} = {k * s} cm, rộng {s} cm. Chu vi: ({k * s} + {s}) × 2 = {2 * (k * s + s)} cm.",
            f"It is a rectangle {k * s} cm by {s} cm. Perimeter ({k * s} + {s}) × 2 = {2 * (k * s + s)} cm.",
            "Các cạnh ghép vào bên trong không tính vào chu vi.", "Inside edges are not part of the perimeter.",
            [("perimeter", "chu vi"), ("join", "ghép")], wrong=(4 * s * k,), figure=svg_grid(1, k, 45))
    for n, d in [(3, 1), (5, 2), (7, 2)]:
        add("geo", d, "cutpaper", f"Có 1 tờ giấy. Mỗi lần, bé cắt một mảnh giấy thành 2 mảnh. Sau {n} lần cắt, bé có bao nhiêu mảnh giấy?",
            f"There is 1 sheet of paper. Each time, you cut one piece into 2. After {n} cuts, how many pieces are there?",
            n + 1, f"Mỗi lần cắt thêm được 1 mảnh: 1 + {n} = {n + 1} mảnh.", f"Each cut adds 1 piece: 1 + {n} = {n + 1}.",
            "Thử với 1 lần cắt, 2 lần cắt.", "Try 1 cut, then 2 cuts.", [("cut", "cắt"), ("piece", "mảnh")], wrong=(2 * n, n))


# ======================================================================= COMB
def gen_comb():
    for _ in range(4):
        a, b = R.randint(2, 4), R.randint(2, 4)
        add("comb", 1, "outfit", f"Bé có {a} chiếc áo và {b} chiếc váy khác nhau. Mỗi lần bé mặc 1 áo và 1 váy. Hỏi bé có bao nhiêu cách chọn trang phục?",
            f"A girl has {a} different tops and {b} different skirts. She wears 1 top and 1 skirt. How many different outfits can she make?",
            a * b, f"Mỗi chiếc áo đi được với {b} chiếc váy: {a} × {b} = {a * b} cách.", f"Each top goes with {b} skirts: {a} × {b} = {a * b}.",
            "Vẽ mỗi áo nối với từng váy.", "Draw lines from each top to each skirt.",
            [("outfit", "bộ trang phục"), ("skirt", "chân váy"), ("top", "áo")], wrong=(a + b,))
    for _ in range(4):
        a, b, c = R.randint(2, 3), R.randint(2, 3), R.randint(2, 3)
        add("comb", 2, "outfit", f"Búp bê có {a} chiếc mũ, {b} chiếc váy và {c} đôi giày. Mỗi bộ trang phục gồm 1 mũ, 1 váy và 1 đôi giày. Hỏi có bao nhiêu bộ trang phục khác nhau?",
            f"A doll has {a} hats, {b} dresses and {c} pairs of shoes. An outfit is 1 hat, 1 dress and 1 pair of shoes. How many different outfits are there?",
            a * b * c, f"Chọn mũ và váy: {a} × {b} = {a * b} cách. Mỗi cách đi với {c} đôi giày: {a * b} × {c} = {a * b * c}.",
            f"{a} × {b} × {c} = {a * b * c}.", "Chọn mũ và váy trước, rồi chọn giày.", "Choose hat and dress first, then shoes.",
            [("hat", "mũ"), ("dress", "váy"), ("shoes", "giày")], wrong=(a + b + c, a * b + c))
    for n, d in [(3, 1), (4, 2), (5, 2), (6, 2), (7, 3), (8, 3)]:
        h = n * (n - 1) // 2
        add("comb", d, "handshake", f"Có {n} bạn gặp nhau, mỗi bạn bắt tay mỗi bạn khác đúng một lần. Hỏi có tất cả bao nhiêu cái bắt tay?",
            f"{n} friends meet. Each one shakes hands with every other friend exactly once. How many handshakes are there?",
            h, f"Bạn thứ nhất bắt tay {n - 1} bạn, bạn thứ hai bắt thêm {n - 2} bạn, ... Tổng: {' + '.join(str(n - 1 - i) for i in range(n - 1))} = {h}.",
            f"{' + '.join(str(n - 1 - i) for i in range(n - 1))} = {h}.",
            "Cẩn thận đừng đếm một cái bắt tay hai lần.", "Don't count the same handshake twice.",
            [("shake hands", "bắt tay"), ("exactly once", "đúng một lần")], wrong=(n * (n - 1), n))
    for n, d in [(4, 2), (5, 3), (6, 3)]:
        h = n * (n - 1) // 2
        add("comb", d, "tournament", f"Có {n} đội bóng thi đấu, mỗi đội gặp mỗi đội khác đúng một trận. Hỏi có tất cả bao nhiêu trận đấu?",
            f"{n} teams play in a tournament. Each team plays every other team exactly once. How many matches are played?",
            h, f"Giống bài bắt tay: {' + '.join(str(n - 1 - i) for i in range(n - 1))} = {h} trận.", f"Like handshakes: {h} matches.",
            "Mỗi trận có 2 đội.", "Each match has 2 teams.", [("team", "đội"), ("match", "trận đấu")], wrong=(n * (n - 1), 2 * n))
    for _ in range(3):
        ds = R.sample(range(1, 10), 3)
        add("comb", 2, "makenum", f"Từ ba chữ số {', '.join(map(str, ds))}, lập được bao nhiêu số có hai chữ số khác nhau?",
            f"Using the digits {', '.join(map(str, ds))}, how many 2-digit numbers with different digits can you make?",
            6, f"Hàng chục có 3 cách chọn, hàng đơn vị còn 2 cách: 3 × 2 = 6 số. Đó là " + ", ".join(str(10 * a + b) for a, b in itertools.permutations(ds, 2)) + ".",
            "3 choices for tens × 2 for ones = 6.", "Chọn chữ số hàng chục trước.", "Choose the tens digit first.",
            [("digit", "chữ số"), ("different", "khác nhau")], wrong=(9, 3))
    for _ in range(3):
        ds = [0] + R.sample(range(1, 10), 3)
        cnt = sum(1 for a, b in itertools.permutations(ds, 2) if a != 0)
        add("comb", 3, "makenum", f"Từ bốn chữ số {', '.join(map(str, sorted(ds)))}, lập được bao nhiêu số có hai chữ số khác nhau?",
            f"Using the digits {', '.join(map(str, sorted(ds)))}, how many 2-digit numbers with different digits can you make?",
            cnt, f"Hàng chục không được là 0, nên có 3 cách. Hàng đơn vị còn 3 chữ số (kể cả 0): 3 × 3 = {cnt} số.",
            f"Tens: 3 choices (not 0). Ones: 3 remaining. 3 × 3 = {cnt}.", "Chữ số 0 không đứng ở hàng chục.", "0 cannot be in the tens place.",
            [("zero", "số 0"), ("tens place", "hàng chục")], wrong=(12, 16))
    for _ in range(2):
        ds = R.sample(range(1, 10), 3)
        add("comb", 3, "makenum", f"Từ ba chữ số {', '.join(map(str, ds))}, lập được bao nhiêu số có hai chữ số (các chữ số có thể lặp lại)?",
            f"Using the digits {', '.join(map(str, ds))}, how many 2-digit numbers can you make if digits may repeat?",
            9, "Hàng chục 3 cách, hàng đơn vị cũng 3 cách: 3 × 3 = 9 số.", "3 × 3 = 9.", "Được dùng lại chữ số đã chọn.", "Digits can be used again.",
            [("repeat", "lặp lại")], wrong=(6, 3))
    for _ in range(4):
        a, b = R.randint(2, 4), R.randint(2, 4)
        add("comb", 1, "routes", f"Từ nhà đến trường có {a} con đường, từ trường đến công viên có {b} con đường. Hỏi có bao nhiêu cách đi từ nhà đến công viên mà phải qua trường?",
            f"There are {a} roads from home to school and {b} roads from school to the park. How many ways are there to go from home to the park through the school?",
            a * b, f"Mỗi đường đến trường đi tiếp được {b} đường: {a} × {b} = {a * b} cách.", f"{a} × {b} = {a * b}.",
            "Vẽ sơ đồ các con đường.", "Draw a map of the roads.", [("road", "con đường"), ("through", "đi qua")], wrong=(a + b,))
    for _ in range(3):
        a, b, c = R.randint(2, 3), R.randint(2, 3), R.randint(1, 3)
        add("comb", 3, "routes", f"Từ A đến B có {a} con đường, từ B đến C có {b} con đường. Ngoài ra còn có {c} con đường đi thẳng từ A đến C không qua B. Hỏi có bao nhiêu cách đi từ A đến C?",
            f"There are {a} roads from A to B and {b} roads from B to C. There are also {c} direct roads from A to C. How many ways are there to go from A to C?",
            a * b + c, f"Đi qua B: {a} × {b} = {a * b} cách. Đi thẳng: {c} cách. Tổng: {a * b + c} cách.", f"Via B: {a * b}; direct: {c}. Total {a * b + c}.",
            "Chia thành hai trường hợp: qua B và không qua B.", "Two cases: through B or direct.", [("direct", "đi thẳng")], wrong=(a + b + c, a * b))
    for _ in range(3):
        r, g = R.randint(4, 9), R.randint(4, 9)
        add("comb", 2, "pigeon", f"Trong hộp có {r} chiếc tất đỏ và {g} chiếc tất xanh. Bé nhắm mắt lấy tất. Hỏi phải lấy ít nhất bao nhiêu chiếc để chắc chắn có 2 chiếc cùng màu?",
            f"A box has {r} red socks and {g} blue socks. Without looking, what is the smallest number of socks you must take to be sure of getting 2 of the same colour?",
            3, "Nếu xui nhất, 2 chiếc đầu khác màu nhau. Chiếc thứ 3 chắc chắn trùng màu với một trong hai chiếc: cần 3 chiếc.",
            "Worst case: first 2 are different colours. The 3rd must match: 3.", "Hãy nghĩ đến trường hợp xui nhất.", "Think about the unluckiest case.",
            [("at least", "ít nhất"), ("be sure", "chắc chắn")], wrong=(2, r + 1, g + 1))
    for _ in range(3):
        r, g, y = R.randint(3, 6), R.randint(3, 6), R.randint(2, 5)
        add("comb", 3, "pigeon", f"Trong túi có {r} viên kẹo dâu, {g} viên kẹo táo và {y} viên kẹo cam. Không nhìn vào túi, phải lấy ít nhất bao nhiêu viên để chắc chắn có 2 viên kẹo dâu?",
            f"A bag has {r} strawberry, {g} apple and {y} orange sweets. Without looking, what is the smallest number you must take to be sure of getting 2 strawberry sweets?",
            g + y + 2, f"Xui nhất là lấy hết {g} viên táo và {y} viên cam trước ({g + y} viên), sau đó lấy thêm 2 viên chắc chắn là dâu: {g + y} + 2 = {g + y + 2} viên.",
            f"Worst case: all {g + y} non-strawberry first, then 2 more: {g + y + 2}.", "Trường hợp xui nhất là lấy hết loại khác trước.", "Worst case: take all the other kinds first.",
            [("strawberry", "dâu tây"), ("at least", "ít nhất")], wrong=(3, g + y + 1, 4))
    add("comb", 2, "arrange", "Ba bạn An, Bình, Chi đứng thành một hàng ngang để chụp ảnh. Hỏi có bao nhiêu cách xếp?",
        "An, Binh and Chi stand in a row for a photo. In how many different ways can they stand?",
        6, "Vị trí đầu có 3 cách chọn, vị trí giữa còn 2, vị trí cuối còn 1: 3 × 2 × 1 = 6 cách.", "3 × 2 × 1 = 6.",
        "Liệt kê: ABC, ACB, ...", "List them: ABC, ACB, ...", [("row", "hàng"), ("way", "cách")], wrong=(3, 9))
    add("comb", 3, "arrange", "Ba bạn An, Bình, Chi đứng thành một hàng ngang. Hỏi có bao nhiêu cách xếp sao cho An luôn đứng ở giữa?",
        "An, Binh and Chi stand in a row. In how many ways can they stand if An must be in the middle?",
        2, "An đứng giữa, hai bạn còn lại đổi chỗ: Bình – An – Chi hoặc Chi – An – Bình. Có 2 cách.", "Binh-An-Chi or Chi-An-Binh: 2 ways.",
        "Đặt An vào giữa trước.", "Put An in the middle first.", [("middle", "ở giữa")], wrong=(6, 3))
    add("comb", 3, "arrange", "Bốn bạn xếp thành một hàng ngang. Hỏi có bao nhiêu cách xếp?",
        "Four children stand in a row. In how many different ways can they stand?",
        24, "Vị trí 1 có 4 cách, vị trí 2 còn 3, vị trí 3 còn 2, vị trí 4 còn 1: 4 × 3 × 2 × 1 = 24 cách.", "4 × 3 × 2 × 1 = 24.",
        "Chọn lần lượt từng vị trí.", "Fill one position at a time.", [("row", "hàng"), ("way", "cách")], wrong=(16, 12))
    for n, d in [(4, 1), (5, 2), (6, 2)]:
        h = n * (n - 1) // 2
        add("comb", d, "choose2", f"Cửa hàng có {n} loại kem khác nhau. Bé được chọn 2 loại khác nhau. Hỏi bé có bao nhiêu cách chọn?",
            f"A shop has {n} different ice-cream flavours. You may pick 2 different flavours. How many ways can you choose?",
            h, f"Liệt kê theo cặp, mỗi cặp chỉ tính một lần: {' + '.join(str(n - 1 - i) for i in range(n - 1))} = {h} cách.",
            f"{' + '.join(str(n - 1 - i) for i in range(n - 1))} = {h}.", "Chọn dâu – vani cũng giống vani – dâu.", "Strawberry–vanilla is the same as vanilla–strawberry.",
            [("flavour", "vị"), ("choose", "chọn")], wrong=(n * (n - 1), 2 * n))
    for r, c, d in [(1, 2, 2), (1, 3, 2), (2, 2, 3), (2, 3, 3)]:
        tot = math.comb(r + c, r)
        add("comb", d, "gridpath", "Một chú kiến đi từ A đến B theo các cạnh của ô vuông, mỗi bước chỉ được đi sang phải hoặc đi lên. Hỏi có bao nhiêu đường đi khác nhau?",
            "An ant walks from A to B along the grid lines, only moving right or up. How many different paths are there?",
            tot, f"Ghi số cách đi đến từng điểm: mỗi điểm bằng tổng số cách của điểm bên trái và điểm bên dưới. Đến B có {tot} cách.",
            f"Write the number of ways at each point: each is the sum of the point to the left and the point below. B gets {tot}.",
            "Ghi số đường đi vào từng điểm, bắt đầu từ A.", "Write the number of ways at each corner, starting from A.",
            [("path", "đường đi"), ("right / up", "sang phải / đi lên")], wrong=(r + c, tot + 1), figure=svg_path_grid(r, c))
    for k, d in [(6, 2), (8, 2), (9, 3), (12, 3)]:
        cnt = sum(1 for a in range(1, k) for b in range(a, k) if a + b == k)
        add("comb", d, "split", f"Có bao nhiêu cách tách {k} viên kẹo thành 2 phần, mỗi phần có ít nhất 1 viên? (Tách {k - 1} và 1 cũng giống tách 1 và {k - 1}.)",
            f"How many ways can {k} sweets be split into 2 groups with at least 1 sweet each? ({k - 1} and 1 is the same as 1 and {k - 1}.)",
            cnt, "Liệt kê: " + ", ".join(f"{a} + {k - a}" for a in range(1, k // 2 + 1)) + f". Có {cnt} cách.",
            "List: " + ", ".join(f"{a} + {k - a}" for a in range(1, k // 2 + 1)) + f". {cnt} ways.",
            "Bắt đầu từ phần nhỏ nhất là 1 viên.", "Start with 1 sweet in the smaller group.", [("split", "tách, chia"), ("at least", "ít nhất")], wrong=(k - 1, cnt + 1))
    ways10 = sum(1 for a in range(11) for b in range(6) for c in range(3) if a + 2 * b + 5 * c == 10)
    add("comb", 3, "coins", "Có bao nhiêu cách đổi tờ 10 nghìn đồng thành các tờ 1 nghìn, 2 nghìn và 5 nghìn đồng? (Không bắt buộc phải có đủ cả ba loại.)",
        "How many ways can you change a 10 thousand dong note into 1, 2 and 5 thousand dong notes? (You don't have to use all three kinds.)",
        ways10, "Dùng 2 tờ 5 nghìn: 1 cách. Dùng 1 tờ 5 nghìn: 5 nghìn còn lại đổi bằng tờ 2 và 1 nghìn: 3 cách (0, 1, 2 tờ 2 nghìn). Không dùng 5 nghìn: 10 nghìn đổi bằng 2 và 1 nghìn: 6 cách (0 → 5 tờ 2 nghìn). Tổng: 1 + 3 + 6 = 10 cách.",
        "Two 5s: 1 way. One 5: 3 ways. No 5s: 6 ways. Total 10.", "Chia trường hợp theo số tờ 5 nghìn.", "Split into cases by the number of 5s.",
        [("change money", "đổi tiền"), ("note", "tờ tiền")], wrong=(6, 8))


gen_logic(); gen_arith(); gen_number(); gen_geo(); gen_comb()

# loại câu trùng, gán id
CAP = 55
out = []
for t in TOPICS:
    seen = set(); uniq = []
    for q in POOL[t]:
        key = q["question_vi"] + (q.get("figure_svg") or "")
        if key not in seen:
            seen.add(key); uniq.append(q)
    if len(uniq) > CAP:  # cắt bớt nhưng giữ đều các dạng bài
        groups = {}
        for q in uniq: groups.setdefault((q["form"], q["difficulty"]), []).append(q)
        keep = []
        while len(keep) < CAP:
            for g in list(groups.values()):
                if g and len(keep) < CAP: keep.append(g.pop(0))
        uniq = [q for q in uniq if q in keep]
    uniq.sort(key=lambda q: q["difficulty"])
    for k, q in enumerate(uniq, 1):
        q["id"] = f"{t}-{k:03d}"
        out.append(q)

meta = {"name": "TIMO lớp 2 - ngân hàng câu hỏi gốc", "grade": 2, "version": 1,
        "topics": {k: {"vi": v[0], "en": v[1]} for k, v in TOPICS.items()},
        "difficulty": {"1": "Dễ / Easy", "2": "Vừa / Medium", "3": "Khó / Hard"},
        "count": len(out)}
json.dump({"meta": meta, "questions": out}, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "questions.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
from collections import Counter
print(len(out), Counter(q["topic"] for q in out), Counter((q["topic"], q["difficulty"]) for q in out))
