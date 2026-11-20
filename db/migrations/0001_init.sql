-- TimoKid: schema Postgres cho đồng bộ (bản 0.3), Neon project `timokid`,
-- database `timokid`. Thiết kế: docs/SYNC.md.
--
-- Nguyên tắc:
-- - Một tài khoản Neon Auth = một gia đình (phụ huynh). App của bé và web
--   admin đăng nhập cùng tài khoản đó.
-- - Mọi bảng bật RLS. Quyền dựa trên auth.user_id() (claim `sub` của JWT
--   Neon Auth) -> families.owner_user_id -> children.family_id.
-- - id của các dòng do app sinh (UUID) để gửi lại không tạo dòng trùng.
-- - attempts và wallet_ledger chỉ thêm: role authenticated không có quyền
--   UPDATE/DELETE trên hai bảng này.
-- - Role anonymous không có quyền gì.

begin;

create extension if not exists pgcrypto;

-- ------------------------------------------------------------ gia đình

create table public.families (
  id uuid primary key default gen_random_uuid(),
  owner_user_id text not null unique default auth.user_id(),
  display_name text not null default '' check (char_length(display_name) <= 80),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Gia đình của người đang đăng nhập (null nếu chưa có).
-- SECURITY DEFINER để policy của các bảng khác gọi được mà không vướng
-- RLS của chính bảng families (tránh đệ quy).
create function public.current_family_id() returns uuid
language sql stable security definer set search_path = public as $$
  select id from public.families where owner_user_id = auth.user_id()
$$;

-- Lấy hoặc tạo gia đình cho tài khoản đang đăng nhập. App và web admin
-- gọi hàm này ngay sau khi đăng nhập.
create function public.ensure_family(p_display_name text default '')
returns public.families
language plpgsql security definer set search_path = public as $$
declare
  fam public.families;
  uid text := auth.user_id();
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;
  insert into public.families (owner_user_id, display_name)
  values (uid, left(coalesce(p_display_name, ''), 80))
  on conflict (owner_user_id) do nothing;
  select * into fam from public.families where owner_user_id = uid;
  return fam;
end;
$$;

-- ------------------------------------------------------------ hồ sơ bé

create table public.children (
  id uuid primary key,
  family_id uuid not null references public.families (id) on delete cascade
    default public.current_family_id(),
  name text not null check (char_length(name) between 1 and 40),
  grade smallint not null default 2 check (grade between 1 and 5),
  -- Lần đồng bộ thành công gần nhất của máy bé (web admin hiện mốc này).
  last_synced_at timestamptz,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz
);
create index children_family_idx on public.children (family_id);

-- Bé có thuộc gia đình của người đang đăng nhập không.
create function public.is_my_child(p_child_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.children c
    where c.id = p_child_id and c.family_id = public.current_family_id()
  )
$$;


-- ------------------------------------------------------------ chỉ thêm

create table public.attempts (
  id uuid primary key,
  child_id uuid not null references public.children (id) on delete cascade,
  form_id text not null,
  strand text not null check (strand in ('logic', 'arith', 'number', 'geo', 'comb')),
  level smallint not null check (level between 1 and 3),
  rung smallint not null check (rung between 1 and 6),
  answer_type text not null check (answer_type in ('choice', 'number')),
  correct_first_try boolean not null,
  attempts_count smallint not null check (attempts_count between 1 and 2),
  duration_ms integer not null check (duration_ms >= 0),
  is_review boolean not null default false,
  daily_set_id uuid,
  stage smallint check (stage between 1 and 5),
  question_seed bigint,
  created_at timestamptz not null,
  received_at timestamptz not null default now()
);
create index attempts_child_time_idx on public.attempts (child_id, created_at);

create table public.wallet_ledger (
  id uuid primary key,
  child_id uuid not null references public.children (id) on delete cascade,
  currency text not null check (currency in ('xu', 'gem')),
  amount integer not null,
  reason text not null check (char_length(reason) <= 40),
  ref_id text,
  created_at timestamptz not null,
  received_at timestamptz not null default now()
);
create index wallet_child_time_idx on public.wallet_ledger (child_id, created_at);

-- ------------------------------------------------------------ có sửa
-- Các bảng dưới đây app ghi đè theo id (upsert). Xung đột: dòng có
-- updated_at mới hơn thắng (trigger keep_newest bên dưới).

create table public.skill_progress (
  id uuid primary key,
  child_id uuid not null references public.children (id) on delete cascade,
  scope text not null check (scope in ('strand', 'form')),
  key text not null,
  rung smallint check (rung between 1 and 6),
  mastered boolean not null default false,
  mastered_at timestamptz,
  window_started_at timestamptz,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  unique (child_id, scope, key)
);

create table public.review_queue (
  id uuid primary key,
  child_id uuid not null references public.children (id) on delete cascade,
  form_id text not null,
  rung smallint not null check (rung between 1 and 6),
  due_date timestamptz not null,
  correct_streak smallint not null default 0 check (correct_streak between 0 and 3),
  -- App xóa mục khi đúng đủ 3 lần; trên server đánh dấu xóa để máy khác
  -- và web admin biết, không xóa cứng.
  deleted_at timestamptz,
  created_at timestamptz not null,
  updated_at timestamptz not null
);
create index review_child_idx on public.review_queue (child_id);

create table public.daily_sets (
  id uuid primary key,
  child_id uuid not null references public.children (id) on delete cascade,
  date date not null,
  questions jsonb not null,
  stage_status jsonb not null,
  completed boolean not null default false,
  completed_at timestamptz,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  unique (child_id, date)
);

-- Cài đặt: child_id null = cài đặt chung của gia đình. Web admin ghi
-- (mức thưởng, khóa kiểu trả lời...), app ghi (hồ sơ nhân vật...).
create table public.settings (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade
    default public.current_family_id(),
  child_id uuid references public.children (id) on delete cascade,
  key text not null check (char_length(key) <= 60),
  value jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index settings_scope_key_idx
  on public.settings (family_id, coalesce(child_id, '00000000-0000-0000-0000-000000000000'::uuid), key);

-- ------------------------------------------------------------ thư và quà

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade
    default public.current_family_id(),
  child_id uuid not null references public.children (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 300),
  gift_xu integer not null default 0 check (gift_xu between 0 and 1000),
  gift_gem integer not null default 0 check (gift_gem between 0 and 100),
  gift_item_id text,
  opened_at timestamptz,
  claimed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index messages_child_idx on public.messages (child_id, created_at);

-- App gọi khi bé mở quà. Chỉ lần gọi đầu trả quà (claimed = true); gọi lại
-- (kể cả do đồng bộ lại) trả claimed = false nên quà không cộng hai lần.
-- App ghi dòng wallet_ledger với ref_id = id thư để chặn trùng phía máy.
create function public.claim_message(p_message_id uuid)
returns table (claimed boolean, gift_xu integer, gift_gem integer, gift_item_id text)
language plpgsql security definer set search_path = public as $$
declare
  m public.messages;
begin
  select * into m from public.messages
  where id = p_message_id and family_id = public.current_family_id()
  for update;
  if not found then
    raise exception 'message not found';
  end if;
  if m.claimed_at is not null then
    return query select false, 0, 0, null::text;
    return;
  end if;
  update public.messages
     set claimed_at = now(), opened_at = coalesce(opened_at, now()), updated_at = now()
   where id = m.id;
  return query select true, m.gift_xu, m.gift_gem, m.gift_item_id;
end;
$$;

-- ------------------------------------------------------------ triggers

-- Bảng có sửa: không cho dòng cũ hơn ghi đè dòng mới hơn (gửi lại lô cũ,
-- hai máy cùng sửa).
create function public.keep_newest() returns trigger
language plpgsql as $$
begin
  if new.updated_at < old.updated_at then
    return old;
  end if;
  return new;
end;
$$;

create trigger skill_progress_keep_newest before update on public.skill_progress
  for each row execute function public.keep_newest();
create trigger review_queue_keep_newest before update on public.review_queue
  for each row execute function public.keep_newest();
create trigger daily_sets_keep_newest before update on public.daily_sets
  for each row execute function public.keep_newest();
create trigger children_keep_newest before update on public.children
  for each row execute function public.keep_newest();
create trigger settings_keep_newest before update on public.settings
  for each row execute function public.keep_newest();

-- Không cho chuyển bé hoặc dòng sang gia đình khác bằng UPDATE.
create function public.forbid_family_change() returns trigger
language plpgsql as $$
begin
  if new.family_id is distinct from old.family_id then
    raise exception 'family_id is immutable';
  end if;
  return new;
end;
$$;
create trigger children_family_fixed before update on public.children
  for each row execute function public.forbid_family_change();
create trigger settings_family_fixed before update on public.settings
  for each row execute function public.forbid_family_change();
create trigger messages_family_fixed before update on public.messages
  for each row execute function public.forbid_family_change();

-- Không cho chuyển dòng sang bé khác bằng UPDATE.
create function public.forbid_child_change() returns trigger
language plpgsql as $$
begin
  if new.child_id is distinct from old.child_id then
    raise exception 'child_id is immutable';
  end if;
  return new;
end;
$$;
create trigger skill_progress_child_fixed before update on public.skill_progress
  for each row execute function public.forbid_child_change();
create trigger review_queue_child_fixed before update on public.review_queue
  for each row execute function public.forbid_child_change();
create trigger daily_sets_child_fixed before update on public.daily_sets
  for each row execute function public.forbid_child_change();
create trigger messages_child_fixed before update on public.messages
  for each row execute function public.forbid_child_change();

-- ------------------------------------------------------------ RLS

alter table public.families enable row level security;
alter table public.children enable row level security;
alter table public.attempts enable row level security;
alter table public.wallet_ledger enable row level security;
alter table public.skill_progress enable row level security;
alter table public.review_queue enable row level security;
alter table public.daily_sets enable row level security;
alter table public.settings enable row level security;
alter table public.messages enable row level security;

create policy families_own on public.families for all to authenticated
  using (owner_user_id = auth.user_id())
  with check (owner_user_id = auth.user_id());

create policy children_own on public.children for all to authenticated
  using (family_id = public.current_family_id())
  with check (family_id = public.current_family_id());

create policy attempts_select on public.attempts for select to authenticated
  using (public.is_my_child(child_id));
create policy attempts_insert on public.attempts for insert to authenticated
  with check (public.is_my_child(child_id));

create policy wallet_select on public.wallet_ledger for select to authenticated
  using (public.is_my_child(child_id));
create policy wallet_insert on public.wallet_ledger for insert to authenticated
  with check (public.is_my_child(child_id));

create policy skill_own on public.skill_progress for all to authenticated
  using (public.is_my_child(child_id)) with check (public.is_my_child(child_id));
create policy review_own on public.review_queue for all to authenticated
  using (public.is_my_child(child_id)) with check (public.is_my_child(child_id));
create policy daily_own on public.daily_sets for all to authenticated
  using (public.is_my_child(child_id)) with check (public.is_my_child(child_id));

create policy settings_own on public.settings for all to authenticated
  using (family_id = public.current_family_id())
  with check (
    family_id = public.current_family_id()
    and (child_id is null or public.is_my_child(child_id))
  );

create policy messages_own on public.messages for all to authenticated
  using (family_id = public.current_family_id())
  with check (family_id = public.current_family_id() and public.is_my_child(child_id));

-- ------------------------------------------------------------ quyền

revoke all on all tables in schema public from anonymous, authenticated;
revoke all on all functions in schema public from public, anonymous;
grant usage on schema public to authenticated;
-- Policy của families gọi thẳng auth.user_id() với quyền người gọi.
grant usage on schema auth to authenticated;
grant execute on function auth.user_id() to authenticated;

grant select, update on public.families to authenticated;
grant select, insert, update on public.children to authenticated;
grant select, insert on public.attempts to authenticated;
grant select, insert on public.wallet_ledger to authenticated;
grant select, insert, update on public.skill_progress to authenticated;
grant select, insert, update on public.review_queue to authenticated;
grant select, insert, update on public.daily_sets to authenticated;
grant select, insert, update, delete on public.settings to authenticated;
grant select, insert, update, delete on public.messages to authenticated;

grant execute on function public.ensure_family(text) to authenticated;
grant execute on function public.claim_message(uuid) to authenticated;
grant execute on function public.current_family_id() to authenticated;
grant execute on function public.is_my_child(uuid) to authenticated;

-- ------------------------------------------------------------ thống kê
-- View cho web admin, chạy với quyền người gọi để RLS vẫn áp dụng.

create view public.child_daily_stats with (security_invoker = true) as
select
  a.child_id,
  (a.created_at at time zone 'Asia/Ho_Chi_Minh')::date as day,
  a.strand,
  count(*) as questions,
  count(*) filter (where a.correct_first_try) as correct_first_try,
  sum(a.duration_ms) as duration_ms
from public.attempts a
group by 1, 2, 3;

create view public.child_balances with (security_invoker = true) as
select child_id,
       coalesce(sum(amount) filter (where currency = 'xu'), 0) as xu,
       coalesce(sum(amount) filter (where currency = 'gem'), 0) as gem
from public.wallet_ledger
group by child_id;

grant select on public.child_daily_stats, public.child_balances to authenticated;

commit;
