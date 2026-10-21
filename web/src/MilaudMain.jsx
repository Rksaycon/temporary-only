import DashboardOverviewSection from "./DashboardOverviewSection";
import DashboardSidebarSection from "./DashboardSidebarSection";
// import icon16 from "./assets/icon-16.svg";

function MilaudMain() {
  return (
    <main className="flex min-h-screen w-full pl-64 bg-gray-50 relative">
      <DashboardSidebarSection />

      <section className="flex flex-1 flex-col">
        <DashboardOverviewSection />
      </section>

      <button
        type="button"
        className="flex items-center justify-center right-8 bottom-8 bg-teal-700 w-14 h-14 absolute rounded-xl"
      >
        <img src={icon16} className="w-4 h-4" />
      </button>
    </main>
  );
}

export default MilaudMain;