import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { useTheme } from "./ThemeContext";
import { useAuth } from "./AuthContext";
import { supabase } from "./supabaseClient";

const AdminProfilePage = () => {
  const { currentTheme, changeTheme, themes } = useTheme();
  const { user, profile, signOut } = useAuth();
  const navigate = useNavigate();

  const [activeTab, setActiveTab] = useState("profile");

  const [editMode, setEditMode] = useState(false);
  const [editedProfile, setEditedProfile] = useState({
    name: "",
    phone: "",
    address: "",
    barangay: "",
  });
  const [savingProfile, setSavingProfile] = useState(false);
  const [profileError, setProfileError] = useState("");
  const [profileSuccess, setProfileSuccess] = useState("");

  const [passwordData, setPasswordData] = useState({
    newPassword: "",
    confirmPassword: "",
  });
  const [passwordSaving, setPasswordSaving] = useState(false);
  const [passwordError, setPasswordError] = useState("");
  const [passwordSuccess, setPasswordSuccess] = useState("");

  // Local-only UI preferences — there's no notification-preferences table
  // in the schema yet, so these don't persist to Supabase.
  const [notifications, setNotifications] = useState({
    emailAlerts: true,
    emergencyAlerts: true,
    reportUpdates: true,
    documentRequests: false,
  });

  useEffect(() => {
    if (profile) {
      setEditedProfile({
        name: profile.name || "",
        phone: profile.phone || "",
        address: profile.address || "",
        barangay: profile.barangay || "",
      });
    }
  }, [profile]);

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setEditedProfile((prev) => ({ ...prev, [name]: value }));
  };

  const handleProfileUpdate = async (e) => {
    e.preventDefault();
    setProfileError("");
    setProfileSuccess("");
    setSavingProfile(true);
    try {
      const { error } = await supabase
        .from("profiles")
        .update({
          name: editedProfile.name,
          phone: editedProfile.phone,
          address: editedProfile.address,
          barangay: editedProfile.barangay,
        })
        .eq("id", user.id);

      if (error) throw error;
      setProfileSuccess("Profile updated.");
      setEditMode(false);
    } catch (err) {
      setProfileError(err.message || "Failed to update profile.");
    } finally {
      setSavingProfile(false);
    }
  };

  const handlePasswordInputChange = (e) => {
    const { name, value } = e.target;
    setPasswordData((prev) => ({ ...prev, [name]: value }));
  };

  const handlePasswordChange = async (e) => {
    e.preventDefault();
    setPasswordError("");
    setPasswordSuccess("");

    if (passwordData.newPassword.length < 6) {
      setPasswordError("Password must be at least 6 characters.");
      return;
    }
    if (passwordData.newPassword !== passwordData.confirmPassword) {
      setPasswordError("New passwords do not match!");
      return;
    }

    setPasswordSaving(true);
    try {
      const { error } = await supabase.auth.updateUser({
        password: passwordData.newPassword,
      });
      if (error) throw error;
      setPasswordSuccess("Password changed successfully.");
      setPasswordData({ newPassword: "", confirmPassword: "" });
    } catch (err) {
      setPasswordError(err.message || "Failed to change password.");
    } finally {
      setPasswordSaving(false);
    }
  };

  const handleNotificationToggle = (key) => {
    setNotifications((prev) => ({ ...prev, [key]: !prev[key] }));
  };

  const handleLogout = async () => {
    await signOut();
    navigate("/login");
  };

  const displayName = profile?.name || "Admin User";
  const email = user?.email || profile?.email || "—";
  const avatarUrl =
    profile?.avatar_url ||
    `https://api.dicebear.com/7.x/initials/svg?seed=${encodeURIComponent(displayName)}&backgroundColor=0056A3&textColor=ffffff`;
  const joinDate = user?.created_at
    ? new Date(user.created_at).toLocaleDateString("en-PH", {
        year: "numeric",
        month: "long",
        day: "numeric",
      })
    : "—";

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-gray-800 dark:text-white">
            Admin Profile & Settings
          </h1>
          <p className="text-gray-600 dark:text-gray-400">
            Manage your account — backed by the same Supabase `profiles` table as the mobile app
          </p>
        </div>
        <button
          onClick={handleLogout}
          className="px-4 py-2 border border-red-300 dark:border-red-700 text-red-600 dark:text-red-400 rounded-lg hover:bg-red-50 dark:hover:bg-red-900/20"
        >
          Log Out
        </button>
      </div>

      {/* Tabs */}
      <div className="border-b dark:border-gray-700">
        <div className="flex space-x-4">
          {["profile", "security", "notifications"].map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`px-4 py-2 font-medium capitalize ${
                activeTab === tab
                  ? "border-b-2 border-blue-600 text-blue-600 dark:text-blue-400"
                  : "text-gray-600 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-300"
              }`}
            >
              {tab === "profile" ? "Profile" : tab === "security" ? "Security" : "Notifications"}
            </button>
          ))}
        </div>
      </div>

      {/* Profile Tab */}
      {activeTab === "profile" && (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Profile Card */}
          <div className="lg:col-span-1">
            <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm p-6 border dark:border-gray-700">
              <div className="flex flex-col items-center">
                <img
                  src={avatarUrl}
                  alt="Profile"
                  className="w-32 h-32 rounded-full border-4 border-white dark:border-gray-800 shadow-lg"
                />
                <h3 className="text-xl font-bold text-gray-800 dark:text-white mt-4">
                  {displayName}
                </h3>
                <p className="text-gray-600 dark:text-gray-400">{email}</p>
                {editedProfile.barangay && (
                  <p className="text-sm text-gray-500 dark:text-gray-500 mt-2">
                    {editedProfile.barangay}
                  </p>
                )}
                <button
                  onClick={() => {
                    setEditMode(true);
                    setProfileSuccess("");
                    setProfileError("");
                  }}
                  className="mt-4 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg"
                >
                  Edit Profile
                </button>
              </div>

              <div className="mt-6 space-y-3">
                <div className="flex items-center">
                  <span className="text-gray-500 dark:text-gray-400 w-24">Email:</span>
                  <span className="text-gray-800 dark:text-white break-all">{email}</span>
                </div>
                <div className="flex items-center">
                  <span className="text-gray-500 dark:text-gray-400 w-24">Phone:</span>
                  <span className="text-gray-800 dark:text-white">
                    {editedProfile.phone || "—"}
                  </span>
                </div>
                <div className="flex items-center">
                  <span className="text-gray-500 dark:text-gray-400 w-24">Address:</span>
                  <span className="text-gray-800 dark:text-white">
                    {editedProfile.address || "—"}
                  </span>
                </div>
                <div className="flex items-center">
                  <span className="text-gray-500 dark:text-gray-400 w-24">Joined:</span>
                  <span className="text-gray-800 dark:text-white">{joinDate}</span>
                </div>
              </div>
            </div>

            {/* Theme Settings */}
            <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm p-6 border dark:border-gray-700 mt-6">
              <h4 className="font-semibold text-gray-800 dark:text-white mb-4">
                Theme Preferences
              </h4>
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-gray-700 dark:text-gray-300">Current Theme:</span>
                  <span className="font-medium capitalize">{currentTheme.name}</span>
                </div>
                <div className="grid grid-cols-2 gap-2">
                  {Object.keys(themes).map((theme) => (
                    <button
                      key={theme}
                      onClick={() => changeTheme(theme)}
                      className={`p-3 rounded-lg border ${
                        currentTheme.name === theme
                          ? "border-blue-600 ring-2 ring-blue-200 dark:ring-blue-800"
                          : "border-gray-300 dark:border-gray-600"
                      }`}
                    >
                      <div className="flex items-center">
                        <div
                          className="w-4 h-4 rounded-full mr-2"
                          style={{ backgroundColor: themes[theme].primary }}
                        />
                        <span className="text-sm capitalize">{theme}</span>
                      </div>
                    </button>
                  ))}
                </div>
                <p className="text-xs text-gray-500 dark:text-gray-400 mt-2">
                  This is a display preference for this browser only — it isn't stored in
                  Supabase or synced to the mobile app.
                </p>
              </div>
            </div>
          </div>

          {/* Edit Form / Info */}
          <div className="lg:col-span-2">
            {profileError && (
              <div className="mb-4 rounded-lg bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-700 dark:text-red-300 text-sm px-4 py-3">
                {profileError}
              </div>
            )}
            {profileSuccess && !editMode && (
              <div className="mb-4 rounded-lg bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 text-green-700 dark:text-green-300 text-sm px-4 py-3">
                {profileSuccess}
              </div>
            )}

            {editMode ? (
              <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm p-6 border dark:border-gray-700">
                <h3 className="text-lg font-semibold text-gray-800 dark:text-white mb-4">
                  Edit Profile Information
                </h3>
                <form onSubmit={handleProfileUpdate} className="space-y-4">
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                      <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                        Full Name
                      </label>
                      <input
                        type="text"
                        name="name"
                        value={editedProfile.name}
                        onChange={handleInputChange}
                        className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-800 dark:text-white"
                        required
                      />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                        Phone Number
                      </label>
                      <input
                        type="tel"
                        name="phone"
                        value={editedProfile.phone}
                        onChange={handleInputChange}
                        className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-800 dark:text-white"
                      />
                    </div>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                      <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                        Address
                      </label>
                      <input
                        type="text"
                        name="address"
                        value={editedProfile.address}
                        onChange={handleInputChange}
                        className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-800 dark:text-white"
                      />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                        Barangay
                      </label>
                      <input
                        type="text"
                        name="barangay"
                        value={editedProfile.barangay}
                        onChange={handleInputChange}
                        className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-800 dark:text-white"
                      />
                    </div>
                  </div>

                  <p className="text-xs text-gray-500 dark:text-gray-400">
                    Email is managed by Supabase Auth and can't be changed here.
                  </p>

                  <div className="flex justify-end space-x-3">
                    <button
                      type="button"
                      onClick={() => setEditMode(false)}
                      className="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-gray-700 dark:text-gray-300"
                    >
                      Cancel
                    </button>
                    <button
                      type="submit"
                      disabled={savingProfile}
                      className="bg-blue-600 hover:bg-blue-700 disabled:opacity-60 text-white font-semibold py-2 px-4 rounded-lg transition"
                    >
                      {savingProfile ? "Saving…" : "Save Changes"}
                    </button>
                  </div>
                </form>
              </div>
            ) : (
              <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm p-6 border dark:border-gray-700">
                <h3 className="text-lg font-semibold text-gray-800 dark:text-white mb-2">
                  Account Details
                </h3>
                <p className="text-sm text-gray-600 dark:text-gray-400">
                  Your name, phone, address, and barangay are stored in the same `profiles`
                  table used by the mobile app. Click "Edit Profile" to update them.
                </p>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Security Tab */}
      {activeTab === "security" && (
        <div className="max-w-md">
          <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm p-6 border dark:border-gray-700">
            <h3 className="text-lg font-semibold text-gray-800 dark:text-white mb-4">
              Change Password
            </h3>

            {passwordError && (
              <div className="mb-4 rounded-lg bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-700 dark:text-red-300 text-sm px-4 py-3">
                {passwordError}
              </div>
            )}
            {passwordSuccess && (
              <div className="mb-4 rounded-lg bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 text-green-700 dark:text-green-300 text-sm px-4 py-3">
                {passwordSuccess}
              </div>
            )}

            <form onSubmit={handlePasswordChange} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  New Password
                </label>
                <input
                  type="password"
                  name="newPassword"
                  value={passwordData.newPassword}
                  onChange={handlePasswordInputChange}
                  className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-800 dark:text-white"
                  minLength={6}
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Confirm New Password
                </label>
                <input
                  type="password"
                  name="confirmPassword"
                  value={passwordData.confirmPassword}
                  onChange={handlePasswordInputChange}
                  className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-800 dark:text-white"
                  minLength={6}
                  required
                />
              </div>
              <button
                type="submit"
                disabled={passwordSaving}
                className="w-full bg-blue-600 hover:bg-blue-700 disabled:opacity-60 text-white font-semibold py-2 px-4 rounded-lg transition"
              >
                {passwordSaving ? "Updating…" : "Update Password"}
              </button>
            </form>
          </div>
        </div>
      )}

      {/* Notifications Tab */}
      {activeTab === "notifications" && (
        <div className="max-w-2xl">
          <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm p-6 border dark:border-gray-700">
            <h3 className="text-lg font-semibold text-gray-800 dark:text-white mb-2">
              Notification Preferences
            </h3>
            <p className="text-sm text-gray-500 dark:text-gray-400 mb-4">
              These are local display preferences for this browser — there's no
              notification-settings table in Supabase yet, so they aren't saved or synced.
            </p>
            <div className="space-y-4">
              {Object.entries(notifications).map(([key, value]) => (
                <div key={key} className="flex items-center justify-between">
                  <span className="text-gray-700 dark:text-gray-300 capitalize">
                    {key.replace(/([A-Z])/g, " $1")}
                  </span>
                  <button
                    onClick={() => handleNotificationToggle(key)}
                    className={`w-11 h-6 rounded-full transition relative ${
                      value ? "bg-blue-600" : "bg-gray-300 dark:bg-gray-600"
                    }`}
                  >
                    <span
                      className={`absolute top-0.5 w-5 h-5 bg-white rounded-full transition ${
                        value ? "left-5" : "left-0.5"
                      }`}
                    />
                  </button>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default AdminProfilePage;
