import type { Dayjs } from "@calcom/dayjs";
import { formatToLocalizedDate, formatToLocalizedTime, formatToLocalizedTimezone } from "@calcom/lib/dayjs";
import type { TFunction } from "i18next";

export type BuildBookingSummaryTextInput = {
  title: string;
  date: Dayjs;
  /** Duration in minutes, used to compute the end time. Omit/0 to show only the start time. */
  duration?: number;
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
  date,
  duration,
  timeZone,
  location,
  language,
  is24h,
  t,
}: BuildBookingSummaryTextInput): string {
  const formattedDate = formatToLocalizedDate(date, language, "full", timeZone);
  const startTime = formatToLocalizedTime({ date, locale: language, hour12: !is24h, timeZone });
  const time =
    duration && duration > 0
      ? `${startTime} - ${formatToLocalizedTime({
          date: date.add(duration, "minute"),
          locale: language,
          hour12: !is24h,
          timeZone,
        })}`
      : startTime;
  const formattedTimezone = formatToLocalizedTimezone(date, language, timeZone) ?? timeZone;

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
