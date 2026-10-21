import { BrowserRouter as Router, Routes, Route, Navigate } from "react-router-dom";
import { ThemeProvider } from "./ThemeContext";
import { AuthProvider, useAuth } from "./AuthContext";
import LoginPage from "./LoginPage";
import SignupPage from "./SignupPage";
import Dashboard from "./Dashboard";
import AnnouncementsPage from "./AnnouncementsPage";
import CitizenReportsPage from "./CitizenReportsPage";
import DocumentRequestsPage from "./DocumentRequestsPage";
import EmergencyHotlinePage from "./EmergencyHotlinePage";
import AdminProfilePage from "./AdminProfilePage";
import Layout from "./Layout";

// Private route component — now backed by a real Supabase auth session
// (shared with the mobile app's Supabase project) instead of a fake
// localStorage flag.
const PrivateRoute = ({ children }) => {
  const { isAuthenticated, loading } = useAuth();

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center text-gray-500">
        Loading…
      </div>
    );
  }

  return isAuthenticated ? children : <Navigate to="/login" />;
};

function AppRoutes() {
  return (
    <Router>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/signup" element={<SignupPage />} />

        {/* Protected routes */}
        <Route path="/" element={
          <PrivateRoute>
            <Layout />
          </PrivateRoute>
        }>
          <Route index element={<Navigate to="/dashboard" />} />
          <Route path="dashboard" element={<Dashboard />} />
          <Route path="announcements" element={<AnnouncementsPage />} />
          <Route path="citizen-reports" element={<CitizenReportsPage />} />
          <Route path="document-requests" element={<DocumentRequestsPage />} />
          <Route path="emergency-hotline" element={<EmergencyHotlinePage />} />
          <Route path="profile" element={<AdminProfilePage />} />
        </Route>
      </Routes>
    </Router>
  );
}

function App() {
  return (
    <AuthProvider>
      <ThemeProvider>
        <AppRoutes />
      </ThemeProvider>
    </AuthProvider>
  );
}

export default App;
