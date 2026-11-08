-- Convierte en administrador al PRIMER usuario creado (el tuyo). Ejecutar una sola vez, después de crear tu usuario.
insert into public.admins(user_id) select id from auth.users order by created_at limit 1 on conflict do nothing;
