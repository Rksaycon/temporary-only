import { useId, useState } from "react";
// import container from "./container.svg";
// import container2 from "./container-2.svg";
// import icon from "./icon.svg";
// import icon2 from "./icon-2.svg";
// import icon3 from "./icon-3.svg";
// import icon4 from "./icon-4.svg";
// import icon5 from "./icon-5.svg";
// import icon6 from "./icon-6.svg";
// import icon7 from "./icon-7.svg";
// import icon8 from "./icon-8.svg";
// import icon17 from "./icon-17.svg";
// import icon18 from "./icon-18.svg";
// import icon19 from "./icon-19.svg";
// import icon20 from "./icon-20.svg";
// import image from "./image.svg";

const statCards = [
  {
    id: "critical-alerts",
    colClass: "row-[1_/_2] col-[1_/_5]",
    iconWrapClass: "bg-[#ffdad633]",
    iconSrc: icon3,
    iconClassName: "relative w-[22px] h-[19px]",
    label: "CRITICAL ALERTS",
    labelWidth: "w-[113.63px]",
    value: "08",
    valueClass: "text-[#ba1a1a]",
    description: "Requires immediate response",
    trendIconSrc: icon4,
    trendIconClassName: "relative w-[10.67px] h-[10.67px]",
    trendText: "+2 since last hour",
    trendTextClass: "text-[#ba1a1a]",
    trendWidth: "w-[99.58px]",
    orbClass: "bg-[#ba1a1a0d]",
  },
  {
    id: "pending-reports",
    colClass: "row-[1_/_2] col-[5_/_9]",
    iconWrapClass: "bg-[#9ff0fb33]",
    iconSrc: icon5,
    iconClassName: "relative w-[18px] h-5",
    label: "PENDING REPORTS",
    labelWidth: "w-[121.81px]",
    value: "24",
    valueClass: "text-[#00535b]",
    description: "Awaiting administrative review",
    trendIconSrc: icon6,
    trendIconClassName: "relative w-[13.33px] h-2",
    trendText: "12% increase this week",
    trendTextClass: "text-[#00535b]",
    trendWidth: "w-[130.75px]",
    orbClass: "bg-[#00535b0d]",
  },
  {
    id: "requests-today",
    colClass: "row-[1_/_2] col-[9_/_13]",
    iconWrapClass: "bg-[#a9ece54c]",
    iconSrc: icon7,
    iconClassName: "relative w-4 h-5",
    label: "REQUESTS TODAY",
    labelWidth: "w-[116.64px]",
    value: "156",
    valueClass: "text-[#236863]",
    description: "Active document requests",
    trendIconSrc: icon8,
    trendIconClassName: "relative w-[13.33px] h-[13.33px]",
    trendText: "82 processed successfully",
    trendTextClass: "text-[#236863]",
    trendWidth: "w-[150.81px]",
    orbClass: "bg-[#2368630d]",
  },
];

const activities = [
  {
    id: "resident-registered",
    iconBg: "bg-slate-100",
    iconSrc: icon20,
    iconClassName: "relative w-[22px] h-4",
    title: "New Resident Registered:",
    body: " Juan Dela Cruz has submitted a verification request for Barangay San Roque.",
    time: "2 minutes ago",
    timeWidth: "w-[78.3px]",
    badge: "VERIFICATION",
    badgeBg: "bg-[#a9ece533]",
    badgeText: "text-[#236863]",
    badgeWidth: "w-[70.69px]",
    containerClass:
      "gap-4 pt-0 pb-6 px-0 self-stretch flex-[0_0_auto] border-b [border-bottom-style:solid] border-slate-100 relative w-full flex items-start",
    timeGapClass: "gap-[11.99px]",
  },
  {
    id: "emergency-signal",
    iconBg: "bg-[#ffdad61a]",
    iconSrc: icon,
    iconClassName: "relative w-[22px] h-[19px]",
    title: "Emergency Signal:",
    body: " Water level alert triggered at Zone 4 Bridge. Automatic sensors reporting 100cm rise.",
    time: "15 minutes ago",
    timeWidth: "w-[83.72px]",
    badge: "EMERGENCY",
    badgeBg: "bg-[#ffdad633]",
    badgeText: "text-[#ba1a1a]",
    badgeWidth: "w-[64.13px]",
    containerClass:
      "gap-4 pt-0 pb-6 px-0 self-stretch flex-[0_0_auto] border-b [border-bottom-style:solid] border-slate-100 relative w-full flex items-start",
    timeGapClass: "gap-3",
  },
  {
    id: "permit-issued",
    iconBg: "bg-[#9ff0fb33]",
    iconSrc: icon2,
    iconClassName: "relative w-4 h-5",
    title: "Permit Issued:",
    body: " Building permit #2023-045 has been approved by the Planning Office.",
    time: "1 hour ago",
    timeWidth: "w-[56.84px]",
    badge: "OPERATIONS",
    badgeBg: "bg-[#9ff0fb33]",
    badgeText: "text-[#00535b]",
    badgeWidth: "w-[65.53px]",
    containerClass:
      "flex items-start gap-4 relative self-stretch w-full flex-[0_0_auto]",
    timeGapClass: "gap-3",
  },
];

export const DashboardOverviewSection = () => {
  const searchId = useId();
  const titleId = useId();
  const contentId = useId();

  const [searchQuery, setSearchQuery] = useState("");
  const [announcementTitle, setAnnouncementTitle] = useState("");
  const [announcementContent, setAnnouncementContent] = useState("");

  return (
    <section className="flex flex-col items-start relative self-stretch w-full flex-[0_0_auto] bg-transparent">
      <header className="flex h-16 items-center justify-between px-6 py-0 relative self-stretch w-full z-[1] bg-white border-b [border-bottom-style:solid] border-slate-200">
        <div className="flex items-center justify-center pl-0 pr-[212.7px] py-0 relative flex-1 grow">
          <div className="flex flex-col max-w-md items-start relative flex-1 grow">
            <label
              htmlFor={searchId}
              className="flex items-start justify-center pl-10 pr-4 py-2.5 relative self-stretch w-full flex-[0_0_auto] bg-slate-50 rounded-lg overflow-hidden"
            >
              <input
                id={searchId}
                aria-label="Search administrative records"
                className="relative grow border-[none] [background:none] self-stretch mt-[-1.00px] [font-family:'Public_Sans-Regular',Helvetica] font-normal text-gray-500 text-sm tracking-[0] leading-[normal] p-0 placeholder:text-gray-500 focus:outline-none"
                placeholder="Search administrative records..."
                type="search"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
            </label>
            <div className="inline-flex flex-col h-[66.67%] items-start absolute top-[16.67%] left-3 pointer-events-none">
              <img
                className="relative w-[18px] h-[18px]"
                alt=""
                aria-hidden="true"
                src={image}
              />
            </div>
          </div>
        </div>
        <div className="inline-flex items-center gap-6 relative flex-[0_0_auto]">
          <button
            type="button"
            aria-label="Notifications"
            className="relative flex-[0_0_auto] rounded focus:outline-none focus-visible:ring-2 focus-visible:ring-[#00535b] focus-visible:ring-offset-2"
          >
            <img
              className="relative flex-[0_0_auto]"
              alt=""
              aria-hidden="true"
              src={container}
            />
          </button>
          <div
            className="w-[17px] h-8 px-2 py-0 flex flex-col items-start relative"
            aria-hidden="true"
          >
            <div className="relative w-px h-8 bg-slate-200" />
          </div>
          <button
            type="button"
            aria-label="Open admin profile"
            className="inline-flex items-center gap-3 p-2 relative flex-[0_0_auto] rounded-lg text-left focus:outline-none focus-visible:ring-2 focus-visible:ring-[#00535b] focus-visible:ring-offset-2"
          >
            <div className="inline-flex flex-col items-start gap-1 relative flex-[0_0_auto]">
              <div className="flex flex-col items-end relative self-stretch w-full flex-[0_0_auto]">
                <div className="relative flex items-center justify-end w-[90.58px] h-3.5 mt-[-1.00px] [font-family:'Public_Sans-Bold',Helvetica] font-bold text-slate-900 text-sm text-right tracking-[0] leading-[14px] whitespace-nowrap">
                  Admin Profile
                </div>
              </div>
              <div className="flex flex-col items-end relative self-stretch w-full flex-[0_0_auto]">
                <div className="relative flex items-center justify-end w-[94.27px] h-[15px] mt-[-1.00px] [font-family:'Inter-Regular',Helvetica] font-normal text-teal-600 text-[10px] text-right tracking-[0] leading-[15px] whitespace-nowrap">
                  Super Administrator
                </div>
              </div>
            </div>
            <div className="flex flex-col w-10 h-10 items-start justify-center relative rounded-xl overflow-hidden border-2 border-solid border-teal-100">
              <div className="relative flex-1 self-stretch w-full grow bg-[url(/administrator-avatar.png)] bg-cover bg-[50%_50%]" />
            </div>
          </button>
        </div>
      </header>
      <div className="flex flex-col max-w-[1440px] items-start gap-8 p-6 relative w-full flex-[0_0_auto] z-0">
        <div className="flex items-end justify-between relative self-stretch w-full flex-[0_0_auto]">
          <div className="relative w-[489.47px] h-[66.39px]">
            <div className="flex flex-col w-full items-start absolute -top-px left-0">
              <h1 className="relative flex items-center w-[313.53px] h-[39px] mt-[-1.00px] [font-family:'Public_Sans-Bold',Helvetica] font-bold text-[#111c2c] text-[32px] tracking-[0] leading-[38.4px] whitespace-nowrap">
                Dashboard Overview
              </h1>
            </div>
            <div className="flex flex-col w-full items-start absolute top-[42px] left-0">
              <p className="relative flex items-center w-[489.47px] h-6 mt-[-1.00px] [font-family:'Public_Sans-Regular',Helvetica] font-normal text-[#3e494a] text-base tracking-[0] leading-6 whitespace-nowrap">
                Welcome back, Administrator. Here is the latest from Milaor
                today.
              </p>
            </div>
          </div>
          <div className="inline-flex items-start gap-3 relative flex-[0_0_auto]">
            <button
              type="button"
              aria-label="Select report date"
              className="all-[unset] box-border inline-flex items-center gap-2 px-4 py-2 relative flex-[0_0_auto] bg-white rounded-lg border border-solid border-[#bec8ca] shadow-[0px_1px_2px_#0000000d] cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#00535b] focus-visible:ring-offset-2"
            >
              <div className="inline-flex flex-col items-center relative flex-[0_0_auto]">
                <img
                  className="relative w-[13.5px] h-[15px]"
                  alt=""
                  aria-hidden="true"
                  src={icon17}
                />
              </div>
              <div className="relative flex items-center justify-center w-[82.67px] h-3 [font-family:'Inter-SemiBold',Helvetica] font-semibold text-[#111c2c] text-xs text-center tracking-[0.60px] leading-3 whitespace-nowrap">
                Oct 24, 2023
              </div>
            </button>
            <button
              type="button"
              className="all-[unset] box-border gap-2 px-6 py-[9px] relative flex-[0_0_auto] bg-[#00535b] rounded-lg inline-flex items-center cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#00535b] focus-visible:ring-offset-2"
            >
              <div className="absolute w-full h-full top-0 left-0 bg-[#ffffff01] rounded-lg shadow-[0px_2px_4px_-2px_#0000001a,0px_4px_6px_-1px_#0000001a]" />
              <div className="inline-flex flex-col items-center relative flex-[0_0_auto]">
                <img
                  className="relative w-3 h-3"
                  alt=""
                  aria-hidden="true"
                  src={icon18}
                />
              </div>
              <div className="relative flex items-center justify-center w-[87.72px] h-3 mt-[-1.00px] [font-family:'Inter-SemiBold',Helvetica] font-semibold text-white text-xs text-center tracking-[0.60px] leading-3 whitespace-nowrap">
                Export Report
              </div>
            </button>
          </div>
        </div>
        <div className="grid grid-cols-12 grid-rows-[208.39px_421.19px] h-fit gap-6 w-full">
          {statCards.map((card) => (
            <article
              key={card.id}
              className={`relative ${card.colClass} w-full h-fit flex flex-col items-start justify-between p-6 bg-white rounded-lg overflow-hidden border border-solid border-slate-200 shadow-[0px_1px_2px_#0000000d]`}
            >
              <div className="flex flex-col items-start gap-1 relative self-stretch w-full flex-[0_0_auto]">
                <div className="flex items-center gap-[11.99px] relative self-stretch w-full flex-[0_0_auto]">
                  <div
                    className={`inline-flex flex-col items-start p-2 relative flex-[0_0_auto] rounded ${card.iconWrapClass}`}
                  >
                    <img
                      className={card.iconClassName}
                      alt=""
                      aria-hidden="true"
                      src={card.iconSrc}
                    />
                  </div>
                  <div className="inline-flex flex-col items-start relative flex-[0_0_auto]">
                    <div
                      className={`relative flex items-center ${card.labelWidth} h-3 mt-[-1.00px] [font-family:'Inter-SemiBold',Helvetica] font-semibold text-[#3e494a] text-xs tracking-[0.60px] leading-3 whitespace-nowrap`}
                    >
                      {card.label}
                    </div>
                  </div>
                </div>
                <div className="pt-[11px] pb-0 px-0 flex flex-col items-start relative self-stretch w-full flex-[0_0_auto]">
                  <div
                    className={`${card.valueClass} relative flex items-center self-stretch mt-[-1.00px] [font-family:'Inter-Bold',Helvetica] font-bold text-[32px] tracking-[0] leading-[38.4px]`}
                  >
                    {card.value}
                  </div>
                </div>
                <div className="flex flex-col items-start relative self-stretch w-full flex-[0_0_auto]">
                  <div className="relative flex items-center self-stretch mt-[-1.00px] [font-family:'Public_Sans-Regular',Helvetica] font-normal text-[#3e494a] text-sm tracking-[0] leading-5">
                    {card.description}
                  </div>
                </div>
              </div>
              <div className="flex flex-col items-start pt-6 pb-0 px-0 relative self-stretch w-full flex-[0_0_auto]">
                <div className="flex items-center gap-1 relative self-stretch w-full flex-[0_0_auto]">
                  <div className="inline-flex flex-col items-start relative flex-[0_0_auto]">
                    <img
                      className={card.trendIconClassName}
                      alt=""
                      aria-hidden="true"
                      src={card.trendIconSrc}
                    />
                  </div>
                  <div className="inline-flex flex-col items-start relative flex-[0_0_auto]">
                    <div
                      className={`relative flex items-center ${card.trendWidth} h-4 mt-[-1.00px] [font-family:'Public_Sans-SemiBold',Helvetica] font-semibold ${card.trendTextClass} text-xs tracking-[0] leading-4 whitespace-nowrap`}
                    >
                      {card.trendText}
                    </div>
                  </div>
                </div>
              </div>
              <div
                className={`absolute top-[-63px] right-[-63px] w-32 h-32 rounded-xl ${card.orbClass}`}
                aria-hidden="true"
              />
            </article>
          ))}

          <section className="relative row-[2_/_3] col-[1_/_6] w-full h-fit flex flex-col items-start gap-6 pt-6 pb-10 px-6 bg-white rounded-lg border border-solid border-slate-200 shadow-[0px_1px_2px_#0000000d]">
            <div className="flex items-center justify-between pr-[5.68e-14px] pl-0 py-0 relative self-stretch w-full flex-[0_0_auto]">
              <div className="w-[243.22px] relative h-[31.19px]">
                <h2 className="absolute -top-px left-0 w-[243px] h-8 flex items-center [font-family:'Public_Sans-SemiBold',Helvetica] font-semibold text-[#111c2c] text-2xl tracking-[0] leading-[31.2px] whitespace-nowrap">
                  Quick Announcement
                </h2>
              </div>
              <button
                type="button"
                aria-label="Announcement options"
                className="inline-flex flex-col items-start relative flex-[0_0_auto] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#00535b] focus-visible:ring-offset-2 rounded"
              >
                <img
                  className="relative w-5 h-4"
                  alt=""
                  aria-hidden="true"
                  src={icon19}
                />
              </button>
            </div>
            <form className="flex flex-col items-start gap-4 relative self-stretch w-full flex-[0_0_auto]">
              <div className="flex flex-col items-start gap-2 relative self-stretch w-full flex-[0_0_auto]">
                <div className="flex flex-col items-start relative self-stretch w-full flex-[0_0_auto]">
                  <label
                    htmlFor={titleId}
                    className="relative flex items-center self-stretch mt-[-1.00px] [font-family:'Inter-SemiBold',Helvetica] font-semibold text-slate-500 text-xs tracking-[0] leading-4"
                  >
                    ANNOUNCEMENT TITLE
                  </label>
                </div>
                <div className="flex items-start justify-center pt-3.5 pb-[15px] px-4 relative self-stretch w-full flex-[0_0_auto] bg-slate-50 rounded-lg overflow-hidden border border-solid border-slate-200">
                  <div className="flex flex-col items-start relative flex-1 grow">
                    <input
                      id={titleId}
                      type="text"
                      value={announcementTitle}
                      onChange={(e) => setAnnouncementTitle(e.target.value)}
                      placeholder="E.g., Road Maintenance Schedule"
                      className="relative flex items-center self-stretch mt-[-1.00px] [font-family:'Public_Sans-Regular',Helvetica] font-normal text-gray-500 text-base tracking-[0] leading-[normal] bg-transparent border-0 p-0 placeholder:text-gray-500 focus:outline-none"
                    />
                  </div>
                </div>
              </div>
              <div className="flex flex-col items-start gap-2 relative self-stretch w-full flex-[0_0_auto]">
                <div className="flex flex-col items-start relative self-stretch w-full flex-[0_0_auto]">
                  <label
                    htmlFor={contentId}
                    className="relative flex items-center self-stretch mt-[-1.00px] [font-family:'Inter-SemiBold',Helvetica] font-semibold text-slate-500 text-xs tracking-[0] leading-4"
                  >
                    CONTENT
                  </label>
                </div>
                <div className="flex items-start justify-center pt-3 pb-[60px] px-4 relative self-stretch w-full flex-[0_0_auto] bg-slate-50 rounded-lg overflow-hidden border border-solid border-slate-200">
                  <div className="flex flex-col items-start relative flex-1 grow">
                    <textarea
                      id={contentId}
                      value={announcementContent}
                      onChange={(e) => setAnnouncementContent(e.target.value)}
                      placeholder={
                        "Briefly describe the update for the\ncitizens..."
                      }
                      className="relative self-stretch mt-[-1.00px] min-h-[72px] resize-none [font-family:'Public_Sans-Regular',Helvetica] font-normal text-gray-500 text-base tracking-[0] leading-6 bg-transparent border-0 p-0 placeholder:text-gray-500 focus:outline-none"
                    />
                  </div>
                </div>
              </div>
              <div className="flex items-center justify-between pl-0 pr-[0.01px] pt-2 pb-0 relative self-stretch w-full flex-[0_0_auto]">
                <button
                  type="button"
                  aria-label="Add attachment"
                  className="relative flex-[0_0_auto] rounded focus:outline-none focus-visible:ring-2 focus-visible:ring-[#00535b] focus-visible:ring-offset-2"
                >
                  <img
                    className="relative flex-[0_0_auto]"
                    alt=""
                    aria-hidden="true"
                    src={container2}
                  />
                </button>
                <button
                  type="submit"
                  className="all-[unset] box-border flex-col justify-center px-6 py-2 relative flex-[0_0_auto] bg-[#00535b] rounded-lg inline-flex items-center cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#00535b] focus-visible:ring-offset-2"
                >
                  <div className="relative flex items-center justify-center w-[78.73px] h-3 mt-[-1.00px] [font-family:'Inter-SemiBold',Helvetica] font-semibold text-white text-xs text-center tracking-[0.60px] leading-3 whitespace-nowrap">
                    Publish Now
                  </div>
                </button>
              </div>
            </form>
          </section>
          <section className="row-[2_/_3] col-[6_/_13] h-fit flex-col gap-6 pt-6 pb-[41px] px-6 bg-white rounded-lg border border-solid border-slate-200 shadow-[0px_1px_2px_#0000000d] relative w-full flex items-start">
            <div className="flex items-center justify-between pl-0 pr-[0.01px] py-0 relative self-stretch w-full flex-[0_0_auto]">
              <div className="w-[172.27px] relative h-[31.19px]">
                <h2 className="absolute -top-px left-0 w-[172px] h-8 flex items-center [font-family:'Public_Sans-SemiBold',Helvetica] font-semibold text-[#111c2c] text-2xl tracking-[0] leading-[31.2px] whitespace-nowrap">
                  Recent Activity
                </h2>
              </div>
              <button
                type="button"
                className="all-[unset] box-border flex-col justify-center relative flex-[0_0_auto] inline-flex items-center cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#00535b] focus-visible:ring-offset-2 rounded"
              >
                <div className="relative flex items-center justify-center w-[79px] h-4 mt-[-1.00px] [font-family:'Inter-Bold',Helvetica] font-bold text-[#00535b] text-xs text-center tracking-[0] leading-4 whitespace-nowrap">
                  View All Logs
                </div>
              </button>
            </div>
            <div className="flex flex-col items-start gap-6 relative self-stretch w-full flex-[0_0_auto]">
              {activities.map((activity) => (
                <article key={activity.id} className={activity.containerClass}>
                  <div
                    className={`flex w-10 h-10 items-center justify-center relative rounded-xl ${activity.iconBg}`}
                  >
                    <div className="inline-flex flex-col items-start relative flex-[0_0_auto]">
                      <img
                        className={activity.iconClassName}
                        alt=""
                        aria-hidden="true"
                        src={activity.iconSrc}
                      />
                    </div>
                  </div>
                  <div className="flex flex-col items-start gap-2 relative flex-1 grow">
                    <div className="flex flex-col items-start relative self-stretch w-full flex-[0_0_auto]">
                      <p className="relative self-stretch mt-[-1.00px] [font-family:'Public_Sans-Bold',Helvetica] font-normal text-[#111c2c] text-sm tracking-[0] leading-[14px]">
                        <span className="font-bold leading-5">
                          {activity.title}
                        </span>
                        <span className="[font-family:'Public_Sans-Regular',Helvetica]">
                          {activity.body.includes("verification request") ? (
                            <>
                              {" "}
                              Juan Dela Cruz has submitted a
                              <br />
                              verification request for Barangay San Roque.
                            </>
                          ) : activity.body.includes(
                              "Automatic sensors reporting 100cm rise.",
                            ) ? (
                            <>
                              {" "}
                              Water level alert triggered at Zone 4 Bridge.
                              <br />
                              Automatic sensors reporting 100cm rise.
                            </>
                          ) : (
                            <>
                              {" "}
                              Building permit #2023-045 has been approved by the
                              <br />
                              Planning Office.
                            </>
                          )}
                        </span>
                      </p>
                    </div>
                    <div
                      className={`flex items-center ${activity.timeGapClass} relative self-stretch w-full flex-[0_0_auto]`}
                    >
                      <div className="inline-flex flex-col items-start relative flex-[0_0_auto]">
                        <div
                          className={`relative flex items-center ${activity.timeWidth} h-4 mt-[-1.00px] [font-family:'Public_Sans-Regular',Helvetica] font-normal text-slate-400 text-xs tracking-[0] leading-4 whitespace-nowrap`}
                        >
                          {activity.time}
                        </div>
                      </div>
                      <div
                        className={`inline-flex flex-col items-start px-2 py-0.5 relative flex-[0_0_auto] rounded-sm ${activity.badgeBg}`}
                      >
                        <div
                          className={`relative flex items-center ${activity.badgeWidth} h-[15px] mt-[-1.00px] [font-family:'Public_Sans-Bold',Helvetica] font-bold ${activity.badgeText} text-[10px] tracking-[0] leading-[15px] whitespace-nowrap`}
                        >
                          {activity.badge}
                        </div>
                      </div>
                    </div>
                  </div>
                </article>
              ))}
            </div>
          </section>
        </div>
        <section className="flex items-center justify-between pt-10 pb-6 px-6 relative self-stretch w-full flex-[0_0_auto] bg-[#006d77] rounded-lg overflow-hidden">
          <div className="relative max-w-2xl w-[672px] h-[131.19px] z-[2]">
            <div className="flex flex-col w-full items-start absolute -top-px left-0">
              <h2 className="relative flex items-center w-[338.94px] h-8 mt-[-1.00px] [font-family:'Public_Sans-SemiBold',Helvetica] font-semibold text-[#9becf7] text-2xl tracking-[0] leading-[31.2px] whitespace-nowrap">
                Climate Resilience Monitoring
              </h2>
            </div>
            <div className="flex flex-col w-full items-start absolute top-[39px] left-0 opacity-90">
              <p className="relative w-[630.2px] h-12 mt-[-1.00px] [font-family:'Public_Sans-Regular',Helvetica] font-normal text-[#9becf7] text-base tracking-[0] leading-6">
                Live environmental monitoring data for the Milaor region is now
                active. View real-time
                <br />
                rainfall, river levels, and humidity sensors across all zones.
              </p>
            </div>
            <button
              type="button"
              className="all-[unset] box-border justify-center px-6 py-2 absolute top-[103px] left-0 bg-white rounded-lg inline-flex items-center cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white focus-visible:ring-offset-2 focus-visible:ring-offset-[#006d77]"
            >
              <div className="absolute w-full h-full top-0 left-0 bg-[#ffffff01] rounded-lg shadow-[0px_4px_6px_-4px_#0000001a,0px_10px_15px_-3px_#0000001a]" />
              <div className="relative flex items-center justify-center w-[146.03px] h-3 mt-[-1.00px] [font-family:'Inter-SemiBold',Helvetica] font-semibold text-[#00535b] text-xs text-center tracking-[0.60px] leading-3 whitespace-nowrap">
                Open Weather Console
              </div>
            </button>
          </div>
          <div
            className="absolute w-full h-[calc(100%_-_16px)] top-4 left-0 z-[1] [background:radial-gradient(50%_50%_at_1657%_1657%,rgba(255,255,255,1)_2%,rgba(255,255,255,0)_2%)] opacity-10"
            aria-hidden="true"
          />
          <div className="inline-flex flex-col items-start relative flex-[0_0_auto] ml-[-696px] z-0">
            <div className="relative w-64 h-64 bg-[url(/ab6axudlhyox7yixahp9pa0vmd-4wjdlh2kuktb9vclevhil2aicbhw1wsijbgydb4fbhaxoa8hm19atluqb-xgnkboblsrd05qszrolb9-p11wvwnquq3b5zfsov0okfgioju-4ivqism6-crlgavlwsp6pg-dktewmuxe51yxcu0rnqlxtv69ny-i5ln1kimxx4qbgmpgjvf0gvdq3qpocbto6k11pe8akzzbjqc0nvcqamuabveyjc-px07yawevaa-44mjxphbmvpq.png)] bg-cover bg-[50%_50%]" />
          </div>
        </section>
      </div>
    </section>
  );
};
