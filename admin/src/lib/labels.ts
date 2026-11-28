export const STRANDS = ['logic', 'arith', 'number', 'geo', 'comb'] as const;
export type Strand = (typeof STRANDS)[number];

export const STRAND_NAMES: Record<Strand, string> = {
  logic: 'Tư duy lôgic',
  arith: 'Số học',
  number: 'Lý thuyết số',
  geo: 'Hình học',
  comb: 'Tổ hợp',
};

export const STRAND_COLORS: Record<Strand, string> = {
  logic: '#b79cf2',
  arith: '#f59ac0',
  number: '#7fd6b4',
  geo: '#8fc4f5',
  comb: '#f7c06b',
};

// Tên dạng bài tiếng Việt. Mã không có trong bảng thì hiện nguyên mã.
// labels.test.ts đối chiếu bảng này với mã nguồn Dart của app (90 dạng).
export const FORM_LABELS: Record<string, string> = {
  'logic.age': 'Tuổi',
  'logic.backward': 'Tính ngược',
  'logic.balance': 'Cân thăng bằng',
  'logic.compare': 'So sánh, xếp hạng',
  'logic.cut': 'Cắt đoạn',
  'logic.equalize': 'Chia cho bằng nhau',
  'logic.legs': 'Đếm chân',
  'logic.queue': 'Xếp hàng',
  'logic.stairs': 'Leo cầu thang',
  'logic.trees': 'Trồng cây',
  'logic.weekday': 'Thứ trong tuần',
  'logic.classsize': 'Sĩ số lớp',
  'logic.seqgrow': 'Dãy số tăng dần đều',
  'logic.interleave': 'Hai dãy số xen kẽ',
  'logic.cyclepattern': 'Hình lặp theo chu kỳ',
  'logic.laps': 'Chạy vòng và nghỉ',
  'logic.clock': 'Xem giờ đồng hồ',
  'logic.calendar': 'Ngày tháng trên lịch',
  'logic.table': 'Bảng quy luật',
  'arith.blank': 'Điền số vào chỗ trống',
  'arith.money': 'Tiền và đổi tiền',
  'arith.multiply': 'Bảng nhân',
  'arith.pattern': 'Quy luật dãy số',
  'arith.quick': 'Tính nhanh',
  'arith.symbols': 'Điền dấu',
  'arith.word': 'Toán có lời văn',
  'arith.sametotal': 'Tổng, hiệu thay đổi',
  'arith.missingdigits': 'Phép cộng bị che chữ số',
  'arith.altsum': 'Cộng trừ xen kẽ',
  'arith.runsum': 'Tổng dãy cách đều',
  'arith.cryptarith': 'Phép tính chữ số ẩn',
  'arith.arrowchain': 'Chuỗi mũi tên',
  'arith.flowerx': 'Phép tính bông hoa',
  'arith.factorout': 'Đặt thừa số chung',
  'arith.pairsum': 'Ghép cặp',
  'number.cards': 'Ghép thẻ số',
  'number.clues': 'Đoán số theo gợi ý',
  'number.digitcount': 'Đếm số chữ số',
  'number.digitfreq': 'Đếm số lần chữ số xuất hiện',
  'number.digitsum': 'Tổng các chữ số',
  'number.fixed': 'Số cố định',
  'number.parity': 'Chẵn lẻ',
  'number.parityrule': 'Quy tắc chẵn lẻ',
  'number.place': 'Hàng của chữ số',
  'number.round': 'Làm tròn số',
  'number.digitcond': 'Đếm số theo điều kiện chữ số',
  'number.parityops': 'Chẵn lẻ của phép tính',
  'number.countsteps': 'Đếm bước',
  'number.between': 'Đếm số nằm giữa',
  'number.giveequal': 'Cho đi để bằng nhau',
  'number.kth': 'Số thứ k',
  'number.pages': 'Đánh số trang',
  'number.multiples': 'Số chia hết',
  'geo.countrect': 'Đếm hình chữ nhật',
  'geo.countsq': 'Đếm hình vuông',
  'geo.counttri': 'Đếm hình tam giác',
  'geo.cubes': 'Khối lập phương',
  'geo.cutpaper': 'Cắt giấy',
  'geo.matches': 'Xếp que diêm',
  'geo.perim': 'Chu vi',
  'geo.shapeperim': 'Chu vi hình ghép',
  'geo.sides': 'Đếm cạnh',
  'geo.pointsegs': 'Điểm và đoạn thẳng',
  'geo.shapeparts': 'Chia hình thành các phần',
  'geo.fence': 'Cắm cọc quanh vườn',
  'geo.segline': 'Đoạn thẳng trên một đường',
  'geo.units': 'Đổi đơn vị độ dài',
  'geo.cutsquares': 'Cắt hình vuông từ giấy',
  'geo.cubefaces': 'Đếm mặt khối lập phương',
  'geo.perimchange': 'Chu vi thay đổi',
  'geo.pyramid': 'Hình chóp',
  'geo.prism': 'Hình lăng trụ',
  'comb.arrange': 'Xếp chỗ',
  'comb.choose2': 'Chọn 2 trong nhóm',
  'comb.coins': 'Ghép đồng xu',
  'comb.gridpath': 'Đường đi trên lưới',
  'comb.handshake': 'Bắt tay',
  'comb.makenum': 'Lập số',
  'comb.outfit': 'Phối đồ',
  'comb.pigeon': 'Nguyên lý chuồng bồ câu',
  'comb.routes': 'Đếm đường đi',
  'comb.split': 'Chia nhóm',
  'comb.tournament': 'Thi đấu vòng tròn',
  'comb.freebie': 'Mua tặng kèm',
  'comb.pick2': 'Chọn 2 bạn trong nhóm',
  'comb.makenumparity': 'Lập số chẵn lẻ',
  'comb.minsum2': 'Tổng nhỏ nhất của hai số',
  'comb.vases': 'Cắm hoa vào lọ',
  'comb.dice': 'Gieo hai xúc xắc',
  'comb.flag': 'Tô màu cờ',
};

export function formLabel(formId: string): string {
  return FORM_LABELS[formId] ?? formId;
}

export function strandOfForm(formId: string): Strand | null {
  const s = formId.split('.')[0];
  return (STRANDS as readonly string[]).includes(s) ? (s as Strand) : null;
}

export const ANSWER_TYPE_NAMES = {
  choice: 'Trắc nghiệm',
  number: 'Nhập số',
} as const;

// Khóa thưởng trong settings.rewards (khớp defaultRewardsJson trong
// app/lib/core/database/app_database.dart).
export const REWARD_FIELDS: { key: string; label: string; unit: string; def: number }[] = [
  { key: 'easy', label: 'Đúng ngay lần đầu, mức Dễ (bậc 1-2)', unit: 'xu', def: 2 },
  { key: 'medium', label: 'Đúng ngay lần đầu, mức Vừa (bậc 3-4)', unit: 'xu', def: 3 },
  { key: 'hard', label: 'Đúng ngay lần đầu, mức Khó (bậc 5-6)', unit: 'xu', def: 5 },
  { key: 'stage_complete', label: 'Xong một chặng', unit: 'xu', def: 5 },
  { key: 'daily_complete_xu', label: 'Xong đề ngày', unit: 'xu', def: 20 },
  { key: 'daily_complete_gem', label: 'Xong đề ngày', unit: 'kim cương', def: 1 },
  { key: 'mastery_gem', label: 'Thành thạo một dạng mới', unit: 'kim cương', def: 2 },
];

// Tên nhân vật và pet, mirror từ app (app/lib/features/character/kid_assets.dart,
// onboarding_config.dart, room/pet_growth.dart).
export const OUTFIT_NAMES: Record<'girl' | 'boy', [string, string, string]> = {
  girl: ['Váy hồng', 'Váy tím', 'Váy hồng tạp dề'],
  boy: ['Áo xanh, quần short', 'Áo hoodie xanh lá', 'Áo đỏ, quần jean'],
};

export const HEAD_ACCESSORY_NAMES: Record<'girl' | 'boy', { hat: string; bow: string }> = {
  girl: { hat: 'Mũ beret', bow: 'Nơ cài tóc' },
  boy: { hat: 'Mũ lưỡi trai', bow: 'Kẹp tóc ngôi sao' },
};

export const GENDER_NAMES = { girl: 'Bé gái', boy: 'Bé trai' } as const;

export const PET_SPECIES_NAMES = {
  dog: 'Chó Tinh Anh',
  cat: 'Mèo Mũm Mĩm',
  rabbit: 'Thỏ Bánh Bao',
  squirrel: 'Sóc',
  capybara: 'Capybara',
  dragon: 'Rồng con',
} as const;

/** Tên loài pet theo mã; mã lạ thì trả lại chính mã. */
export function petSpeciesName(code: string): string {
  return (PET_SPECIES_NAMES as Record<string, string>)[code] ?? code;
}

export const MEDAL_NAMES = {
  gold: 'Vàng',
  silver: 'Bạc',
  bronze: 'Đồng',
  participant: 'Tham gia',
} as const;

export const PET_STAGE_NAMES = {
  egg: 'trứng',
  newborn: 'mới nở',
  teen: 'tuổi nhỡ',
  adult: 'trưởng thành',
} as const;

/** Mã mọi dạng bài của app (labels.test.ts bảo đảm khớp mã nguồn Dart). */
export const ALL_FORM_IDS: readonly string[] = Object.keys(FORM_LABELS);
