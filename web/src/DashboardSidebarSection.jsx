// import icon9 from "./icon-9.svg";
// import icon10 from "./icon-10.svg";
// import icon11 from "./icon-11.svg";
// import icon12 from "./icon-12.svg";
// import icon13 from "./icon-13.svg";
// import icon14 from "./icon-14.svg";
// import icon15 from "./icon-15.svg";

const primaryNavItems = [
  {
    label: "Dashboard",
    icon: icon9,
    iconClassName: "relative w-[18px] h-[18px]",
    textWidthClassName: "w-[68.7px]",
    active: true,
  },
  {
    label: "Announcements",
    icon: icon10,
    iconClassName: "relative w-5 h-4",
    textWidthClassName: "w-[103.28px]",
    active: false,
  },
  {
    label: "Emergency Command",
    icon: icon11,
    iconClassName: "relative w-[20.05px] h-[20.05px]",
    textWidthClassName: "w-[138.16px]",
    active: false,
  },
  {
    label: "Resident Reports",
    icon: icon12,
    iconClassName: "relative w-[18px] h-5",
    textWidthClassName: "w-[108.56px]",
    active: false,
  },
  {
    label: "Document Requests",
    icon: icon13,
    iconClassName: "relative w-4 h-5",
    textWidthClassName: "w-[127.05px]",
    active: false,
  },
];

const secondaryNavItems = [
  {
    label: "Support",
    icon: icon14,
    iconClassName: "relative w-5 h-5",
    textWidthClassName: "w-[50.86px]",
  },
  {
    label: "Logout",
    icon: icon15,
    iconClassName: "relative w-[18px] h-[18px]",
    textWidthClassName: "w-[44.09px]",
  },
];

export const DashboardSidebarSection = () => {
  return (
    <aside
      className="flex flex-col w-64 h-[1214px] items-start px-0 py-4 absolute top-0 left-0 bg-white border-r [border-right-style:solid] border-slate-200"
      aria-label="Dashboard sidebar"
    >
      <div className="pt-0 pb-8 px-6 self-stretch w-full flex-[0_0_auto] flex flex-col items-start relative">
        <div className="flex items-center gap-3 relative self-stretch w-full flex-[0_0_auto]">
          <div className="flex w-10 h-10 items-center justify-center relative bg-[#006d77] rounded-lg">
            <div className="relative max-w-10 w-8 h-8 bg-[url(/ab6axub3afisb-zwiyw9swkbhr46zai1srgckvqivkon6ehqyjyjyzacn4x3tusjtcocqstcf-4i2ka2wv-zcqmrqpgd5seijxh-4dqdv-dlyponyfrdhizcjbjamczx8i4tlkmahcvifjit6q7cyaszccmommarx1fqgh6atref93gprevn5psnb0zut-u9gfpp77suleehbv11vsrwsqppeyffs6f-mp5yr7uijc-31uh3m82lgkhea9ejiezpt93rzhw5kqnyqisybq.png)] bg-cover bg-[50%_50%]" />
          </div>
          <div className="inline-flex flex-col items-start relative flex-[0_0_auto]">
            <div className="flex flex-col items-start relative self-stretch w-full flex-[0_0_auto]">
              <div className="relative flex items-center w-[104.42px] h-7 mt-[-1.00px] [font-family:'Public_Sans-Black',Helvetica] font-black text-teal-700 text-xl tracking-[-0.50px] leading-7 whitespace-nowrap">
                Milaor LGU
              </div>
            </div>
            <div className="flex flex-col items-start relative self-stretch w-full flex-[0_0_auto]">
              <div className="relative flex items-center w-[115.11px] h-4 mt-[-1.00px] [font-family:'Public_Sans-Regular',Helvetica] font-normal text-slate-500 text-xs tracking-[0] leading-4 whitespace-nowrap">
                Administrative Panel
              </div>
            </div>
          </div>
        </div>
      </div>
      <nav
        className="flex flex-col items-start justify-center pt-2 pb-0 px-0 relative flex-1 self-stretch w-full grow"
        aria-label="Primary"
      >
        <div className="flex flex-col items-center gap-1 px-2 py-0 relative flex-1 self-stretch w-full grow">
          {primaryNavItems.map((item) =>
            item.active ? (
              <a
                key={item.label}
                href="#"
                aria-current="page"
                className="bg-teal-50 border-r-4 [border-right-style:solid] border-teal-700 flex items-center gap-3 p-3 relative self-stretch w-full flex-[0_0_auto] focus:outline-none focus-visible:ring-2 focus-visible:ring-teal-700 focus-visible:ring-offset-2"
              >
                <div className="inline-flex flex-col items-start relative flex-[0_0_auto]">
                  <img
                    className={item.iconClassName}
                    alt=""
                    src={item.icon}
                    aria-hidden="true"
                  />
                </div>
                <div className="inline-flex flex-col items-start relative flex-[0_0_auto]">
                  <div
                    className={`relative flex items-center ${item.textWidthClassName} h-3 mt-[-1.00px] [font-family:'Inter-SemiBold',Helvetica] font-semibold text-teal-700 text-xs tracking-[0.60px] leading-3 whitespace-nowrap`}
                  >
                    {item.label}
                  </div>
                </div>
              </a>
            ) : (
              <a
                key={item.label}
                href="#"
                className="flex w-[223px] items-center gap-3 p-3 relative flex-[0_0_auto] rounded focus:outline-none focus-visible:ring-2 focus-visible:ring-teal-700 focus-visible:ring-offset-2"
              >
                <div className="inline-flex flex-col items-start relative flex-[0_0_auto]">
                  <img
                    className={item.iconClassName}
                    alt=""
                    src={item.icon}
                    aria-hidden="true"
                  />
                </div>
                <div className="inline-flex flex-col items-start relative flex-[0_0_auto]">
                  <div
                    className={`relative flex items-center ${item.textWidthClassName} h-3 mt-[-1.00px] [font-family:'Inter-SemiBold',Helvetica] font-semibold text-slate-600 text-xs tracking-[0.60px] leading-3 whitespace-nowrap`}
                  >
                    {item.label}
                  </div>
                </div>
              </a>
            ),
          )}
        </div>
      </nav>
      <div className="pt-2 pb-0 px-0 self-stretch w-full flex-[0_0_auto] flex flex-col items-start relative">
        <nav
          className="flex flex-col items-start pt-4 pb-0 px-4 relative self-stretch w-full flex-[0_0_auto] border-t [border-top-style:solid] border-slate-100"
          aria-label="Secondary"
        >
          {secondaryNavItems.map((item) => (
            <a
              key={item.label}
              href="#"
              className="rounded flex items-center gap-3 p-3 relative self-stretch w-full flex-[0_0_auto] focus:outline-none focus-visible:ring-2 focus-visible:ring-teal-700 focus-visible:ring-offset-2"
            >
              <div className="inline-flex flex-col items-start relative flex-[0_0_auto]">
                <img
                  className={item.iconClassName}
                  alt=""
                  src={item.icon}
                  aria-hidden="true"
                />
              </div>
              <div className="inline-flex flex-col items-start relative flex-[0_0_auto]">
                <div
                  className={`relative flex items-center ${item.textWidthClassName} h-3 mt-[-1.00px] [font-family:'Inter-SemiBold',Helvetica] font-semibold text-slate-600 text-xs tracking-[0.60px] leading-3 whitespace-nowrap`}
                >
                  {item.label}
                </div>
              </div>
            </a>
          ))}
        </nav>
      </div>
    </aside>
  );
};
