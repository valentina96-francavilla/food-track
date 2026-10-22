import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://foodtrack.valeyastudio.it",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

function respond(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return respond(405, { error: "Metodo non consentito." });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SECRET_KEY");
  if (!supabaseUrl || !serviceKey) return respond(500, { error: "Configurazione server incompleta." });

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
  if (!token) return respond(401, { error: "Accesso richiesto." });

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
  });
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData.user) return respond(401, { error: "Sessione non valida." });

  const { data: adminMembership, error: membershipCheckError } = await admin
    .from("memberships")
    .select("organization_id, organizations!inner(kind)")
    .eq("user_id", userData.user.id)
    .eq("role", "admin")
    .eq("organizations.kind", "platform")
    .limit(1)
    .maybeSingle();

  if (membershipCheckError || !adminMembership) {
    return respond(403, { error: "Solo un amministratore della piattaforma può invitare utenti." });
  }

  let body: { type?: string; name?: string; email?: string; contact?: string; city?: string; supplier?: string };
  try { body = await req.json(); } catch { return respond(400, { error: "Richiesta non valida." }); }

  const type = body.type;
  const name = String(body.name ?? "").trim();
  const email = String(body.email ?? "").trim().toLowerCase();
  const supplierName = String(body.supplier ?? "").trim();

  if (!["supplier", "customer"].includes(type ?? "")) return respond(400, { error: "Tipo account non valido." });
  if (name.length < 2 || name.length > 160) return respond(400, { error: "Inserisci un nome attività valido." });
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return respond(400, { error: "Inserisci un indirizzo email valido." });

  let supplierOrganizationId: string | null = null;
  if (type === "customer") {
    if (!supplierName) return respond(400, { error: "Seleziona un fornitore." });
    const { data: supplier, error: supplierError } = await admin
      .from("organizations").select("id").eq("kind", "supplier").eq("name", supplierName).maybeSingle();
    if (supplierError || !supplier) {
      return respond(400, { error: "Il fornitore selezionato non ha ancora un account FoodTrack. Crea prima il fornitore e riprova." });
    }
    supplierOrganizationId = supplier.id;
  }

  const kind = type === "supplier" ? "supplier" : "customer";
  const role = kind;
  const { data: organization, error: orgError } = await admin
    .from("organizations")
    .insert({ name, kind, email })
    .select("id")
    .single();
  if (orgError || !organization) {
    return respond(400, { error: orgError?.code === "23505" ? "Esiste già un'attività con questi dati." : (orgError?.message ?? "Impossibile creare l'attività.") });
  }

  const { data: invited, error: inviteError } = await admin.auth.admin.inviteUserByEmail(email, {
    redirectTo: "https://foodtrack.valeyastudio.it/",
    data: { organization_name: name, account_type: kind, contact_name: String(body.contact ?? "").trim() },
  });
  if (inviteError || !invited.user) {
    await admin.from("organizations").delete().eq("id", organization.id);
    return respond(400, { error: inviteError?.message ?? "Non è stato possibile inviare l'invito." });
  }

  const { error: insertMembershipError } = await admin.from("memberships").insert({
    organization_id: organization.id,
    user_id: invited.user.id,
    role,
  });

  if (insertMembershipError) {
    await admin.auth.admin.deleteUser(invited.user.id);
    await admin.from("organizations").delete().eq("id", organization.id);
    return respond(500, { error: "Invito generato ma non è stato possibile assegnare il ruolo. L'operazione è stata annullata; controlla la configurazione del database." });
  }

  if (type === "customer" && supplierOrganizationId) {
    const { error: linkError } = await admin.from("customer_suppliers").insert({
      customer_organization_id: organization.id,
      supplier_organization_id: supplierOrganizationId,
      active: true,
    });
    if (linkError) {
      await admin.from("memberships").delete().eq("organization_id", organization.id);
      await admin.auth.admin.deleteUser(invited.user.id);
      await admin.from("organizations").delete().eq("id", organization.id);
      return respond(500, { error: "Non è stato possibile collegare il gastronomo al fornitore. L'operazione è stata annullata." });
    }
  }

  return respond(200, {
    ok: true,
    organization_id: organization.id,
    email,
    type,
    message: "Account creato e invito inviato.",
  });
});