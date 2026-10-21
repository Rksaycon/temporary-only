import { createClient } from "@supabase/supabase-js";

// This points the web admin panel at the SAME Supabase project used by the
// "may_laud" Flutter mobile app, so data created here (announcements,
// citizen report status, document request status, hotlines, etc.) is the
// exact same data residents see in the mobile app — no separate sync step.
//
// Falls back to the known project values if the .env file didn't make it
// into the folder (this can happen with some Windows zip extractors that
// mishandle dotfiles) so the app still connects instead of failing silently.
//
// FIX — this pointed at an abandoned Supabase project
// (qwkdkcycwvvdcqmaxodw) with an incompatible schema left over from
// early setup. The Flutter mobile app moved to a fresh project
// (enojnhijfabncaeoyctt, "Mylaud") once that became clear — this admin
// panel was never updated to match, so it would have silently managed a
// completely different database than the one residents actually use.
const FALLBACK_URL = "https://enojnhijfabncaeoyctt.supabase.co";
const FALLBACK_ANON_KEY =
  "sb_publishable_CycaIfVSoGPshOrlbleTKQ_OUd1oqEe";

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || FALLBACK_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || FALLBACK_ANON_KEY;

if (!import.meta.env.VITE_SUPABASE_URL || !import.meta.env.VITE_SUPABASE_ANON_KEY) {
  console.warn(
    "VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY not found in .env — using the built-in " +
      "fallback project credentials instead. Create a .env file (see .env.example) to " +
      "point this at a different Supabase project."
  );
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
