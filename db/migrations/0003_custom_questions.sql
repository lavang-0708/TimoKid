-- TimoKid: câu hỏi tự soạn từ web admin (bản 0.5, T5-03).
-- Chạy SAU 0001_init.sql và 0002_app_tables.sql, trên database `timokid`.
-- CHƯA chạy trên Neon: chủ dự án chạy rồi mới đổi cờ
-- `customQuestionsEnabled` thành true trong app/lib/core/sync/sync_config.dart.
--
-- Bảng `custom_questions`: đề do bố/mẹ soạn (từng câu hoặc nhập CSV ở web
-- admin), app tải về và trộn vào đề ngày (tối đa 1 câu mỗi chặng).
--   child_id null = áp dụng cho mọi bé của gia đình; có giá trị = chỉ bé đó.
--   strand    = mảng của chặng (logic, arith, number, geo, comb).
--   rung      = bậc 1-6; app chỉ dùng câu đúng bậc hiện tại của bé ở mảng đó.
--   grade     = lớp ghi chú (1-12), chỉ để bố/mẹ phân loại.
--   answer    = câu điền số: số nguyên không âm tối đa 6 chữ số (bàn phím của
--               bé chỉ có chữ số); câu trắc nghiệm: đúng một chuỗi trong choices.
--   choices   = null (điền số) hoặc mảng jsonb 2-6 chuỗi.
--   active    = tắt câu thay vì xóa (không cấp quyền DELETE).
-- Quy ước giống 0001: RLS theo family_id = current_family_id(), trigger
-- keep_newest (dòng cũ không ghi đè dòng mới), family_id không đổi được.

begin;

create table public.custom_questions (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade
    default public.current_family_id(),
  child_id uuid references public.children (id) on delete cascade,
  strand text not null check (strand in ('logic', 'arith', 'number', 'geo', 'comb')),
  rung smallint not null check (rung between 1 and 6),
  grade smallint not null default 2 check (grade between 1 and 12),
  text_vi text not null check (char_length(text_vi) between 1 and 600),
  text_en text check (text_en is null or char_length(text_en) <= 600),
  answer text not null check (char_length(answer) between 1 and 100),
  choices jsonb,
  explanation_vi text not null default '' check (char_length(explanation_vi) <= 600),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Trắc nghiệm: 2-6 chuỗi, đáp án là một trong số đó. Điền số: số nguyên
  -- không âm, tối đa 6 chữ số.
  constraint custom_questions_answer_ok check (
    (choices is null and answer ~ '^[0-9]{1,6}$')
    or (
      choices is not null
      and jsonb_typeof(choices) = 'array'
      and jsonb_array_length(choices) between 2 and 6
      and choices ? answer
    )
  )
);
create index custom_questions_family_updated_idx
  on public.custom_questions (family_id, updated_at);
create index custom_questions_pick_idx
  on public.custom_questions (family_id, active, strand, rung);

-- Sửa mà không tự đặt updated_at thì lấy giờ máy chủ, để app tải lại dòng
-- đã sửa theo mốc updated_at. Tên bắt đầu bằng "a" để chạy trước keep_newest.
create function public.custom_questions_touch() returns trigger
language plpgsql as $$
begin
  if new.updated_at is not distinct from old.updated_at then
    new.updated_at := now();
  end if;
  return new;
end;
$$;
create trigger custom_questions_a_touch before update on public.custom_questions
  for each row execute function public.custom_questions_touch();
create trigger custom_questions_keep_newest before update on public.custom_questions
  for each row execute function public.keep_newest();
create trigger custom_questions_family_fixed before update on public.custom_questions
  for each row execute function public.forbid_family_change();

alter table public.custom_questions enable row level security;

create policy custom_questions_own on public.custom_questions for all to authenticated
  using (family_id = public.current_family_id())
  with check (
    family_id = public.current_family_id()
    and (child_id is null or public.is_my_child(child_id))
  );

revoke all on public.custom_questions from anonymous, authenticated;
grant select, insert, update on public.custom_questions to authenticated;

commit;
