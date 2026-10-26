-- The admin-check helper is only needed by authenticated policies, never anonymous callers.
revoke execute on function public.is_foodtrack_platform_admin() from public, anon;
grant execute on function public.is_foodtrack_platform_admin() to authenticated;
