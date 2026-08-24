import type { Dayjs } from "@calcom/dayjs";

// Fixed business hours window (local to the date's own timezone), Monday-Friday.
export const BUSINESS_HOURS_START = 9;
export const BUSINESS_HOURS_END = 18;

/**
 * Whether `date` falls outside the fixed Mon-Fri 9-18 business hours window.
 * `date` must already be converted to the timezone the check should run in
 * (e.g. via `dayjs.tz(timezone)`) since this only reads day-of-week and hour.
 */
export function isOutsideBusinessHours(date: Dayjs): boolean {
  return !date.isBusinessDay() || date.hour() < BUSINESS_HOURS_START || date.hour() >= BUSINESS_HOURS_END;
}
