// LAMA username + password sign-in.
// Deploy with Supabase CLI: supabase functions deploy username-login
// Required server-side secrets: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY.
// Never put the service-role key in the Android app.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return Response.json({ error: "Method not allowed" }, { status: 405, headers: corsHeaders });

  try {
    const { username, password } = await req.json();
    const clean = String(username ?? "").trim().replace(/^@/, "").toLowerCase();
    if (!/^[a-z0-9_]{1,35}$/.test(clean) || typeof password !== "string" || password.length < 1) {
      return Response.json({ error: "Invalid username or password." }, { status: 400, headers: corsHeaders });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !anonKey || !serviceKey) {
      console.error("username-login is missing required environment variables");
      return Response.json({ error: "Sign-in service is not configured." }, { status: 500, headers: corsHeaders });
    }

    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: profile, error: profileError } = await admin
      .from("profiles")
      .select("id")
      .eq("username", clean)
      .maybeSingle();

    if (profileError || !profile) {
      return Response.json({ error: "Invalid username or password." }, { status: 401, headers: corsHeaders });
    }

    const { data: userData, error: userError } = await admin.auth.admin.getUserById(profile.id);
    const email = userData.user?.email;
    if (userError || !email) {
      return Response.json({ error: "Invalid username or password." }, { status: 401, headers: corsHeaders });
    }

    // Ask Supabase Auth to verify the password. Credentials and resulting session
    // are handled server-side; the account email is never returned to the client.
    const tokenResponse = await fetch(`${supabaseUrl}/auth/v1/token?grant_type=password`, {
      method: "POST",
      headers: { "Content-Type": "application/json", apikey: anonKey },
      body: JSON.stringify({ email, password }),
    });
    const session = await tokenResponse.json();
    if (!tokenResponse.ok || !session.access_token || !session.refresh_token) {
      return Response.json({ error: "Invalid username or password." }, { status: 401, headers: corsHeaders });
    }

    return Response.json({
      access_token: session.access_token,
      refresh_token: session.refresh_token,
    }, { status: 200, headers: corsHeaders });
  } catch (error) {
    console.error("username-login error", error);
    return Response.json({ error: "Unable to sign in right now." }, { status: 500, headers: corsHeaders });
  }
});
