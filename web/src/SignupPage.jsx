import { useState, useRef, useEffect } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useAuth } from "./AuthContext";

const RESEND_COOLDOWN = 30; // seconds — mirrors the mobile app's OTP screen

const SignupPage = () => {
  const [step, setStep] = useState("form"); // "form" | "otp"
  const [formData, setFormData] = useState({
    fullName: "",
    email: "",
    phone: "",
    position: "",
    password: "",
    confirmPassword: "",
  });
  const [agreeTerms, setAgreeTerms] = useState(false);
  const [error, setError] = useState("");
  const [info, setInfo] = useState("");
  const [loading, setLoading] = useState(false);

  // --- OTP step state ---
  const [otpDigits, setOtpDigits] = useState(Array(6).fill(""));
  const [resendCooldown, setResendCooldown] = useState(0);
  const otpRefs = useRef([]);

  const { signUp, verifySignupOtp, resendSignupOtp, completeSignupProfile } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    if (resendCooldown <= 0) return;
    const timer = setInterval(() => setResendCooldown((c) => c - 1), 1000);
    return () => clearInterval(timer);
  }, [resendCooldown]);

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
  };

  const handleSignup = async (e) => {
    e.preventDefault();
    setError("");
    setInfo("");

    if (formData.password.length < 8) {
      setError("Password must be at least 8 characters.");
      return;
    }
    if (formData.password !== formData.confirmPassword) {
      setError("Passwords do not match!");
      return;
    }
    if (!agreeTerms) {
      setError("You must agree to the terms and conditions");
      return;
    }

    setLoading(true);
    try {
      const { session } = await signUp({
        name: formData.fullName,
        email: formData.email,
        phone: formData.phone,
        password: formData.password,
      });

      if (session) {
        // Email confirmation is off in this Supabase project — session is
        // issued immediately, no OTP needed.
        navigate("/dashboard");
      } else {
        // Same as the mobile app: account is created but unconfirmed, and a
        // 6-digit code was just emailed. Move to the OTP step.
        setStep("otp");
        setResendCooldown(RESEND_COOLDOWN);
      }
    } catch (err) {
      setError(err.message || "Unable to create account. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  const handleOtpChange = (index, value) => {
    if (value && !/^\d$/.test(value)) return; // digits only
    const next = [...otpDigits];
    next[index] = value;
    setOtpDigits(next);
    if (value && index < 5) {
      otpRefs.current[index + 1]?.focus();
    }
  };

  const handleOtpKeyDown = (index, e) => {
    if (e.key === "Backspace" && !otpDigits[index] && index > 0) {
      otpRefs.current[index - 1]?.focus();
    }
  };

  const handleOtpPaste = (e) => {
    const pasted = e.clipboardData.getData("text").replace(/\D/g, "").slice(0, 6);
    if (!pasted) return;
    e.preventDefault();
    const next = Array(6).fill("");
    for (let i = 0; i < pasted.length; i++) next[i] = pasted[i];
    setOtpDigits(next);
    otpRefs.current[Math.min(pasted.length, 5)]?.focus();
  };

  const handleVerifyOtp = async (e) => {
    e.preventDefault();
    const code = otpDigits.join("");
    if (code.length < 6) {
      setError("Please enter the complete 6-digit code.");
      return;
    }

    setError("");
    setLoading(true);
    try {
      const result = await verifySignupOtp(formData.email, code);
      // Session is now active — fill in the profile fields that couldn't be
      // saved before confirmation (same as completeRegistration() on mobile).
      const userId = result?.user?.id || result?.session?.user?.id;
      if (userId) {
        await completeSignupProfile({
          userId,
          name: formData.fullName,
          phone: formData.phone,
        });
      }
      // completeSignupProfile() just set role: "admin" on this account
      // (see AuthContext.jsx), so it's safe to go straight in — no
      // approval step needed.
      navigate("/dashboard");
    } catch (err) {
      setError(err.message || "Invalid or expired code. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  const handleResend = async () => {
    if (resendCooldown > 0) return;
    setError("");
    try {
      await resendSignupOtp(formData.email);
      setInfo("A new code has been sent to your email.");
      setResendCooldown(RESEND_COOLDOWN);
    } catch (err) {
      setError(err.message || "Failed to resend code. Please try again.");
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-50 to-purple-100 p-4">
      <div className="max-w-2xl w-full bg-white rounded-2xl shadow-xl overflow-hidden">
        <div className="md:flex">
          <div className="md:w-1/2 bg-header-gradient p-8 text-white">
            <div className="h-full flex flex-col justify-center">
              <div className="mb-8">
                <div className="w-16 h-16 bg-white/20 rounded-xl flex items-center justify-center mb-4">
                  <span className="text-white font-bold text-2xl">M</span>
                </div>
                <h2 className="text-3xl font-bold">Join Maylaud Admin</h2>
                <p className="mt-2 opacity-90">
                  Manage your LGU's digital services efficiently
                </p>
              </div>

              <div className="space-y-4">
                <div className="flex items-center">
                  <div className="w-8 h-8 rounded-full bg-white/20 flex items-center justify-center mr-3">
                    <span className="text-sm">✓</span>
                  </div>
                  <span>Dashboard analytics & insights</span>
                </div>
                <div className="flex items-center">
                  <div className="w-8 h-8 rounded-full bg-white/20 flex items-center justify-center mr-3">
                    <span className="text-sm">✓</span>
                  </div>
                  <span>Citizen report management</span>
                </div>
                <div className="flex items-center">
                  <div className="w-8 h-8 rounded-full bg-white/20 flex items-center justify-center mr-3">
                    <span className="text-sm">✓</span>
                  </div>
                  <span>Emergency hotline coordination</span>
                </div>
                <div className="flex items-center">
                  <div className="w-8 h-8 rounded-full bg-white/20 flex items-center justify-center mr-3">
                    <span className="text-sm">✓</span>
                  </div>
                  <span>Document request processing</span>
                </div>
              </div>

              <div className="mt-12">
                <p className="text-sm opacity-80">
                  Already have an account?{" "}
                  <Link to="/login" className="underline font-semibold">
                    Sign in here
                  </Link>
                </p>
              </div>
            </div>
          </div>

          <div className="md:w-1/2 p-6">
            {step === "form" && (
              <>
                <h3 className="text-xl font-bold text-gray-800 mb-4">
                  Create Admin Account
                </h3>

                {error && (
                  <div className="mb-4 rounded-lg bg-red-50 border border-red-200 text-red-700 text-sm px-4 py-3">
                    {error}
                  </div>
                )}

                <form onSubmit={handleSignup} className="space-y-3">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Full Name
                    </label>
                    <input
                      type="text"
                      name="fullName"
                      value={formData.fullName}
                      onChange={handleChange}
                      className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition"
                      placeholder="Juan Dela Cruz"
                      required
                    />
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        Email Address
                      </label>
                      <input
                        type="email"
                        name="email"
                        value={formData.email}
                        onChange={handleChange}
                        className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition"
                        placeholder="admin@milaor.gov.ph"
                        required
                      />
                    </div>

                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        Phone Number
                      </label>
                      <input
                        type="tel"
                        name="phone"
                        value={formData.phone}
                        onChange={handleChange}
                        className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition"
                        placeholder="+63 912 345 6789"
                        required
                      />
                    </div>
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Position / Role
                    </label>
                    <select
                      name="position"
                      value={formData.position}
                      onChange={handleChange}
                      className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition"
                      required
                    >
                      <option value="">Select position</option>
                      <option value="admin">System Administrator</option>
                      <option value="supervisor">Supervisor</option>
                      <option value="officer">LGU Officer</option>
                      <option value="manager">Department Manager</option>
                    </select>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        Password
                      </label>
                      <input
                        type="password"
                        name="password"
                        value={formData.password}
                        onChange={handleChange}
                        className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition"
                        placeholder="••••••••"
                        required
                        minLength={8}
                      />
                    </div>

                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        Confirm Password
                      </label>
                      <input
                        type="password"
                        name="confirmPassword"
                        value={formData.confirmPassword}
                        onChange={handleChange}
                        className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition"
                        placeholder="••••••••"
                        required
                        minLength={8}
                      />
                    </div>
                  </div>

                  <label
                    htmlFor="terms"
                    className="flex items-start bg-gray-50 border border-gray-200 rounded-lg p-3 cursor-pointer select-none"
                  >
                    <input
                      type="checkbox"
                      id="terms"
                      checked={agreeTerms}
                      onChange={(e) => setAgreeTerms(e.target.checked)}
                      className="sr-only"
                    />
                    <span
                      className={`h-5 w-5 flex-shrink-0 rounded border-2 flex items-center justify-center mt-0.5 transition-colors ${
                        agreeTerms ? "bg-blue-600 border-blue-600" : "bg-white border-gray-400"
                      }`}
                    >
                      {agreeTerms && (
                        <svg
                          className="w-3.5 h-3.5 text-white"
                          viewBox="0 0 24 24"
                          fill="none"
                          stroke="currentColor"
                          strokeWidth="3"
                        >
                          <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                        </svg>
                      )}
                    </span>
                    <span className="ml-3 text-sm text-gray-700">
                      I agree to the{" "}
                      <span className="text-blue-600 underline">Terms and Conditions</span> and{" "}
                      <span className="text-blue-600 underline">Privacy Policy</span>
                    </span>
                  </label>

                  <button
                    type="submit"
                    disabled={loading}
                    className="w-full bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 disabled:opacity-60 text-white font-semibold py-2.5 px-4 rounded-lg transition duration-200 mt-2"
                  >
                    {loading ? "Creating account…" : "Create Account"}
                  </button>
                </form>

                <div className="mt-6 text-center">
                  <p className="text-xs text-gray-500">
                    By signing up, you agree to comply with LGU Milaor's administrative guidelines.
                  </p>
                </div>
              </>
            )}

            {step === "otp" && (
              <>
                <h3 className="text-2xl font-bold text-gray-800 mb-2">
                  Verify Your Email
                </h3>
                <p className="text-gray-600 text-sm mb-6">
                  We've sent a 6-digit code to <strong>{formData.email}</strong>. Enter it
                  below to activate your account.
                </p>

                {error && (
                  <div className="mb-4 rounded-lg bg-red-50 border border-red-200 text-red-700 text-sm px-4 py-3">
                    {error}
                  </div>
                )}
                {info && (
                  <div className="mb-4 rounded-lg bg-green-50 border border-green-200 text-green-700 text-sm px-4 py-3">
                    {info}
                  </div>
                )}

                <form onSubmit={handleVerifyOtp} className="space-y-6">
                  <div className="grid grid-cols-6 gap-2" onPaste={handleOtpPaste}>
                    {otpDigits.map((digit, idx) => (
                      <input
                        key={idx}
                        ref={(el) => (otpRefs.current[idx] = el)}
                        type="text"
                        inputMode="numeric"
                        maxLength={1}
                        value={digit}
                        onChange={(e) => handleOtpChange(idx, e.target.value)}
                        onKeyDown={(e) => handleOtpKeyDown(idx, e)}
                        className="w-full aspect-square text-center text-lg sm:text-xl font-semibold border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition"
                      />
                    ))}
                  </div>

                  <button
                    type="submit"
                    disabled={loading}
                    className="w-full bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 disabled:opacity-60 text-white font-semibold py-3 px-4 rounded-lg transition duration-200"
                  >
                    {loading ? "Verifying…" : "Verify & Continue"}
                  </button>

                  <div className="text-center text-sm text-gray-600">
                    Didn't get a code?{" "}
                    <button
                      type="button"
                      onClick={handleResend}
                      disabled={resendCooldown > 0}
                      className="text-blue-600 hover:text-blue-800 font-medium disabled:text-gray-400 disabled:cursor-not-allowed"
                    >
                      {resendCooldown > 0 ? `Resend in ${resendCooldown}s` : "Resend code"}
                    </button>
                  </div>

                  <button
                    type="button"
                    onClick={() => setStep("form")}
                    className="w-full text-sm text-gray-500 hover:text-gray-700"
                  >
                    ← Back to sign up form
                  </button>
                </form>
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default SignupPage;
