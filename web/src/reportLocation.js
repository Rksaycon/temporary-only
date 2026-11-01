const COORDINATE_PATTERN = /^\s*(-?\d{1,2}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)\s*$/;

const clean = (value) => String(value || "").trim();

export const parseReportLocation = (value) => {
  const raw = clean(value);
  let landmark = "";
  let address = "";
  let coordinates = "";

  for (const part of raw.split(" • ").map(clean).filter(Boolean)) {
    const separator = part.indexOf(":");
    const label = separator >= 0 ? part.slice(0, separator).trim().toLowerCase() : "";
    const detail = separator >= 0 ? part.slice(separator + 1).trim() : part;

    if (label === "landmark") landmark = detail;
    else if (label === "address" && COORDINATE_PATTERN.test(detail)) coordinates = detail;
    else if (label === "address") address = detail;
    else if (label === "gps" && COORDINATE_PATTERN.test(detail)) coordinates = detail;
    else if (COORDINATE_PATTERN.test(detail)) coordinates = detail;
    else if (!address) address = detail;
  }

  const display = landmark
    ? `${address || coordinates || "Location not provided"} — near ${landmark}`
    : address || coordinates || "Location not provided";

  return {
    raw,
    landmark,
    address,
    coordinates,
    display,
    mapQuery: coordinates || address || landmark || raw,
  };
};

export const locationGroupingKey = (value) => {
  const details = parseReportLocation(value);
  const coordinateMatch = details.coordinates.match(COORDINATE_PATTERN);
  if (coordinateMatch) {
    return `gps-${Number(coordinateMatch[1]).toFixed(3)}-${Number(coordinateMatch[2]).toFixed(3)}`;
  }
  return details.address || details.landmark || details.raw || "Unknown location";
};
