-- PORTFOLIO DG. KEVIN CURA — tablas, seguridad y almacenamiento
create table if not exists public.admins(user_id uuid primary key references auth.users(id) on delete cascade);
create or replace function public.is_admin() returns boolean language sql security definer stable set search_path=public as
$$ select exists(select 1 from public.admins where user_id=auth.uid()) $$;

create table if not exists public.categories(id uuid primary key default gen_random_uuid(),name text not null,position int not null default 0,created_at timestamptz default now());
create table if not exists public.projects(id uuid primary key default gen_random_uuid(),title text not null default 'Sin título',description text default '',work_type text default '',role text default '',year int,published boolean not null default false,position int not null default 0,cover_path text,cover_ratio numeric,created_at timestamptz default now(),updated_at timestamptz default now());
create table if not exists public.project_media(id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id) on delete cascade,kind text not null check(kind in('image','video','embed')),path text,url text,ratio numeric,position int not null default 0,created_at timestamptz default now());
create table if not exists public.project_categories(project_id uuid references public.projects(id) on delete cascade,category_id uuid references public.categories(id) on delete cascade,primary key(project_id,category_id));
create table if not exists public.profile(id int primary key default 1 check(id=1),bio text default '',trajectory text default '',skills text default '',email text default '',whatsapp text default '',linkedin text default '',links jsonb not null default '[]',photo_path text,cv_path text);
insert into public.profile(id) values(1) on conflict do nothing;
insert into public.categories(name,position) select n,i from unnest(array['DIGITAL','IMPRESO','COMERCIAL','SOCIAL','PRODUCTO','SERVICIOS','VIDEOS','OTROS']) with ordinality as t(n,i) where not exists(select 1 from public.categories);

alter table public.admins enable row level security;
alter table public.categories enable row level security;
alter table public.projects enable row level security;
alter table public.project_media enable row level security;
alter table public.project_categories enable row level security;
alter table public.profile enable row level security;

-- Visitantes: solo leer lo publicado
create policy admins_self on public.admins for select using(user_id=auth.uid());
create policy cat_read on public.categories for select using(true);
create policy proj_read on public.projects for select using(published or public.is_admin());
create policy media_read on public.project_media for select using(public.is_admin() or exists(select 1 from public.projects p where p.id=project_id and p.published));
create policy pc_read on public.project_categories for select using(public.is_admin() or exists(select 1 from public.projects p where p.id=project_id and p.published));
create policy profile_read on public.profile for select using(true);
-- Solo el administrador: crear, editar y borrar
create policy cat_write on public.categories for all using(public.is_admin()) with check(public.is_admin());
create policy proj_write on public.projects for all using(public.is_admin()) with check(public.is_admin());
create policy media_write on public.project_media for all using(public.is_admin()) with check(public.is_admin());
create policy pc_write on public.project_categories for all using(public.is_admin()) with check(public.is_admin());
create policy profile_write on public.profile for update using(public.is_admin()) with check(public.is_admin());

-- Archivos (imágenes, videos, CV): lectura pública, escritura solo del administrador
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('portfolio','portfolio',true,52428800,array['image/jpeg','image/png','image/webp','video/mp4','video/webm','video/quicktime','application/pdf'])
on conflict(id) do update set public=true,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
create policy portfolio_admin_write on storage.objects for all to authenticated using(bucket_id='portfolio' and public.is_admin()) with check(bucket_id='portfolio' and public.is_admin());
