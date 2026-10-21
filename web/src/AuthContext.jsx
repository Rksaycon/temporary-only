import { createContext, useContext, useEffect, useState } from "react";
import { supabase } from "./supabaseClient";

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [session, setSession] = useState(null);
  const [profile, setProfile] = useState(null);
  const [loading, setLoading] = useState(true);

  const loadProfile = async (userId, email) => {
    try {
      const { data, error } = await supabase
        .from("profiles")
        .select("*")
        .eq("id", userId)
        .single();
      if (error) throw error;

      // Enforce web-admin-only access: if this profile's role isn't
      // 'admin' (e.g. it's a resident account from the mobile app), don't
      // let them into the dashboard — sign them straight back out.
      if (data?.role && data.role !== "admin") {
        await rejectNonAdmin();
        return;
      }

      setProfile({ ...data, email: data?.email || email });
    } catch {
      // profiles row may not exist yet (e.g. brand new account) — fall back
      // to whatever we know from the auth session itself.
      setProfile({ id: userId, email, name: email });
    }
  };

  // Called any time we discover the signed-in account isn't an admin
  // account (e.g. a resident's mobile-app account). Kicks them out
  // immediately rather than leaving them on an admin page.
  const rejectNonAdmin = async () => {
    await supabase.auth.signOut();
    setSession(null);
    setProfile(null);
  };

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      if (session?.user) {
        loadProfile(session.user.id, session.user.email);
      }
      setLoading(false);
    });

    const { data: listener } = supabase.auth.onAuthStateChange(
      (_event, newSession) => {
        setSession(newSession);
        if (newSession?.user) {
          loadProfile(newSession.user.id, newSession.user.email);
        } else {
          setProfile(null);
        }
      }
    );

    return () => listener.subscription.unsubscribe();
  }, []);

  const signIn = async (email, password) => {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });
    if (error) throw error;

    // Enforce web-admin-only access right away, before returning success,
    // so a resident's mobile-app account can't get into the dashboard even
    // for a moment.
    const userId = data.user?.id;
    if (userId) {
      const { data: profileRow } = await supabase
        .from("profiles")
        .select("role")
        .eq("id", userId)
        .single();

      if (profileRow?.role && profileRow.role !== "admin") {
        await supabase.auth.signOut();
        throw new Error(
          "This account doesn't have admin access. Please use the Maylaud mobile app instead."
        );
      }
    }

    return data;
  };

  // Creates a real Supabase auth user AND a row in the same `profiles`
  // table the mobile app reads/writes, so this account is a first-class
  // citizen of the same backend (not a separate "web-only" login).
  //
  // NOTE: `profiles` only has SELECT/UPDATE policies, no INSERT policy —
  // rows are created by a database trigger on auth.users, not by the
  // client. So we pass name/phone as auth metadata (the trigger reads
  // this) instead of trying to insert/upsert a profiles row ourselves,
  // which would fail RLS.
  const signUp = async ({ name, email, phone, password }) => {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: { data: { name, phone } },
    });
    if (error) throw error;

    // NOTE — this intentionally auto-promotes every web signup to admin.
    // We had removed that (see git history) because it meant anyone who
    // found this page got instant admin access with no invite/approval —
    // that's still true here. It was restored because the project spec
    // explicitly calls for "Web Registration → Admin Role" as a platform
    // rule (mobile stays 'resident' by default — see register() in the
    // mobile app, which never touches role). If this ever needs to be
    // locked back down, reintroduce the manual-promotion step this
    // replaced (see supabase/promote_admin.sql in the may_laud repo) or
    // gate it behind an allowlist/invite check instead of removing this
    // update outright.
    if (data.session && data.user?.id) {
      const { error: verifyError } = await supabase
        .from("profiles")
        .update({ role: "admin", is_verified: true })
        .eq("id", data.user.id);
      if (verifyError) console.warn("Could not mark profile verified:", verifyError.message);
    }

    return data;
  };

  // Matches the mobile app's registration_otp_screen.dart exactly: a 6-digit
  // code sent to the user's email, verified via type "signup".
  const verifySignupOtp = async (email, token) => {
    const { data, error } = await supabase.auth.verifyOtp({
      email,
      token,
      type: "signup",
    });
    if (error) throw error;
    return data;
  };

  // After OTP verification the user is confirmed and has a real session, so
  // auth.uid() now resolves and the existing "Users update own profile"
  // policy allows this. The row itself already exists (created by the
  // auth.users trigger) — we UPDATE it, not upsert/insert, since there's no
  // insert policy on profiles for the client to use. Successfully verifying
  // the OTP is exactly what `is_verified` exists to track, so flip it here.
  //
  // NOTE — sets role: "admin" here too, same reasoning as signUp() above:
  // this is the OTP-confirmed path, so it's the one that actually runs
  // for most web signups (signUp() only hits the role update itself when
  // email confirmation is off and a session already exists).
  const completeSignupProfile = async ({ userId, name, phone }) => {
    try {
      const { error } = await supabase
        .from("profiles")
        .update({ name, phone, role: "admin", is_verified: true })
        .eq("id", userId);
      if (error) console.warn("Profile update after OTP failed:", error.message);
    } catch (err) {
      console.warn("Profile update after OTP failed:", err.message);
    }
  };

  const resendSignupOtp = async (email) => {
    const { error } = await supabase.auth.resend({ type: "signup", email });
    if (error) throw error;
  };

  // Same pattern, for password-reset codes (type "recovery"), mirroring
  // forgot_password_otp_screen.dart on mobile.
  const requestPasswordReset = async (email) => {
    const { error } = await supabase.auth.resetPasswordForEmail(email);
    if (error) throw error;
  };

  const verifyRecoveryOtp = async (email, token) => {
    const { data, error } = await supabase.auth.verifyOtp({
      email,
      token,
      type: "recovery",
    });
    if (error) throw error;
    return data;
  };

  const signOut = () => supabase.auth.signOut();

  return (
    <AuthContext.Provider
      value={{
        session,
        user: session?.user || null,
        profile,
        loading,
        isAuthenticated: !!session,
        signIn,
        signUp,
        signOut,
        verifySignupOtp,
        resendSignupOtp,
        completeSignupProfile,
        requestPasswordReset,
        verifyRecoveryOtp,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => useContext(AuthContext);
