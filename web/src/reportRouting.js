// The current operational scope is barangay-only. This value is stored in the
// existing assigned_department column as an internal ownership label; it does
// not imply an integration or confirmed handoff to an external LGU office.
export const BARANGAY_RESPONSE_TEAM = "Barangay Response Team";

export const RESPONSE_DEPARTMENTS = [BARANGAY_RESPONSE_TEAM];

export const departmentForCategory = () => BARANGAY_RESPONSE_TEAM;
