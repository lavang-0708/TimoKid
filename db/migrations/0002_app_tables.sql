-- TimoKid: bảng phía server cho các bảng riêng của app (bản 0.3, T3-04).
-- Chạy SAU 0001_init.sql, trên cùng database `timokid`. Thiết kế: docs/SYNC.md.
--
-- Thêm 3 bảng khớp bảng Drift cùng tên trong app (schema v4/v5):
--   inventory       đồ bé đang có (có sửa)
--   pets            pet của bé (có sửa: xp, active...)
--   arena_attempts  bài thi Đấu trường đã nộp (chỉ thêm)
-- Quy ước giống 0001: id do app sinh (UUID), RLS qua is_my_child(child_id),
-- bảng có sửa có updated_at + trigger keep_newest + trigger chặn đổi
-- child_id, bảng chỉ thêm chỉ cấp SELECT và INSERT và có received_at.
--
-- Các trạng thái khác của app (nhiệm vụ, tháp, ngoại hình, bố cục phòng...)
-- không có bảng riêng: app lưu chúng trong `settings` nên đã đồng bộ qua
-- bảng `settings` của 0001.
--
-- Sau khi chạy file này, đổi `syncExtraTablesEnabled` thành true trong
-- app/lib/core/sync/sync_config.dart.

begin;

-- ------------------------------------------------------------ có sửa

create table public.inventory (
  id uuid primary key,
  child_id uuid not null references public.children (id) on delete cascade,
  item_id text not null check (char_length(item_id) between 1 and 80),
  acquired_at timestamptz not null,
  -- shop (mua), starter (bộ đồ chọn ở mở đầu), grandfather (máy cài trước
  -- bản có cửa hàng), gift (quà từ thư của bố).
  source text not null check (char_length(source) between 1 and 20),
  created_at timestamptz not null,
  updated_at timestamptz not null,
  unique (child_id, item_id)
);
create index inventory_child_idx on public.inventory (child_id);

create table public.pets (
  id uuid primary key,
  child_id uuid not null references public.children (id) on delete cascade,
  species text not null check (species in ('dog', 'cat', 'rabbit', 'squirrel', 'capybara', 'dragon')),
  xp integer not null default 0 check (xp >= 0),
  stage_seen text not null default 'egg' check (stage_seen in ('egg', 'newborn', 'teen', 'adult')),
  hatched boolean not null default false,
  -- Trong app mỗi bé chỉ một pet active (chỉ mục unique từng phần). Server
  -- không lặp ràng buộc này: upsert từng dòng trong một lô có thể đổi
  -- active giữa hai pet và tạm vi phạm. app là nơi giữ luật đó.
  active boolean not null default false,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  unique (child_id, species)
);
create index pets_child_idx on public.pets (child_id);

-- ------------------------------------------------------------ chỉ thêm

create table public.arena_attempts (
  id uuid primary key,
  child_id uuid not null references public.children (id) on delete cascade,
  date date not null,
  mode text not null default 'heat' check (mode in ('heat', 'final')),
  correct_count smallint not null check (correct_count >= 0),
  score integer not null check (score >= 0),
  medal text not null check (medal in ('gold', 'silver', 'bronze', 'participant')),
  duration_sec integer not null check (duration_sec >= 0),
  gems_awarded integer not null default 0 check (gems_awarded >= 0),
  created_at timestamptz not null,
  received_at timestamptz not null default now()
);
create index arena_child_time_idx on public.arena_attempts (child_id, created_at);

-- ------------------------------------------------------------ triggers
-- keep_newest và forbid_child_change đã có từ 0001.

create trigger inventory_keep_newest before update on public.inventory
  for each row execute function public.keep_newest();
create trigger pets_keep_newest before update on public.pets
  for each row execute function public.keep_newest();

create trigger inventory_child_fixed before update on public.inventory
  for each row execute function public.forbid_child_change();
create trigger pets_child_fixed before update on public.pets
  for each row execute function public.forbid_child_change();

-- ------------------------------------------------------------ RLS

alter table public.inventory enable row level security;
alter table public.pets enable row level security;
alter table public.arena_attempts enable row level security;

create policy inventory_own on public.inventory for all to authenticated
  using (public.is_my_child(child_id)) with check (public.is_my_child(child_id));
create policy pets_own on public.pets for all to authenticated
  using (public.is_my_child(child_id)) with check (public.is_my_child(child_id));

create policy arena_select on public.arena_attempts for select to authenticated
  using (public.is_my_child(child_id));
create policy arena_insert on public.arena_attempts for insert to authenticated
  with check (public.is_my_child(child_id));

-- ------------------------------------------------------------ quyền

revoke all on public.inventory, public.pets, public.arena_attempts
  from anonymous, authenticated;
grant select, insert, update on public.inventory to authenticated;
grant select, insert, update on public.pets to authenticated;
grant select, insert on public.arena_attempts to authenticated;

commit;
