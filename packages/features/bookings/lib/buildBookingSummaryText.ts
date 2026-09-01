import type { Dayjs } from "@calcom/dayjs";
import { formatToLocalizedDate, formatToLocalizedTime, formatToLocalizedTimezone } from "@calcom/lib/dayjs";
import type { TFunction } from "i18next";

export type BuildBookingSummaryTextInput = {
  title: string;
  /** Booking start, already converted to the timezone the summary should be shown in. */
  startDate: Dayjs;
  /** Booking end. Omit to show only the start time. Must be in the same timezone as `startDate`. */
  endDate?: Dayjs;
  timeZone: string;
  location?: string | null;
  language?: string;
  is24h?: boolean;
  t: TFunction;
};

/**
 * Builds a plain-text summary of a booking (title, date, time, timezone and
 * location) suitable for copying to the clipboard.
 */
export function buildBookingSummaryText({
  title,
  startDate,
  endDate,
  timeZone,
  location,
  language,
  is24h,
  t,
}: BuildBookingSummaryTextInput): string {
  const formattedDate = formatToLocalizedDate(startDate, language, "full", timeZone);
  const startTime = formatToLocalizedTime({ date: startDate, locale: language, hour12: !is24h, timeZone });
  const time = endDate
    ? `${startTime} - ${formatToLocalizedTime({
        date: endDate,
        locale: language,
        hour12: !is24h,
        timeZone,
      })}`
    : startTime;
  const formattedTimezone = formatToLocalizedTimezone(startDate, language, timeZone) ?? timeZone;

  const lines = [
    title,
    `${t("date")}: ${formattedDate}`,
    `${t("time")}: ${time}`,
    `${t("timezone")}: ${formattedTimezone}`,
  ];

  if (location) {
    lines.push(`${t("location")}: ${location}`);
  }

  return lines.join("\n");
}
