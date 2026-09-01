import dayjs from "@calcom/dayjs";
import { describe, expect, it } from "vitest";
import { isOutsideBusinessHours } from "./isOutsideBusinessHours";

// 2026-09-01 is a Tuesday (a business day).
const tuesday = (hour: number) => dayjs.utc("2026-09-01T00:00:00.000Z").hour(hour);
// 2026-09-05 is a Saturday.
const saturday = (hour: number) => dayjs.utc("2026-09-05T00:00:00.000Z").hour(hour);

describe("isOutsideBusinessHours", () => {
  it("returns false for a time within 9-18 on a weekday", () => {
    expect(isOutsideBusinessHours(tuesday(9))).toBe(false);
    expect(isOutsideBusinessHours(tuesday(13))).toBe(false);
    expect(isOutsideBusinessHours(tuesday(17))).toBe(false);
  });

  it("returns true for a time before 9 on a weekday", () => {
    expect(isOutsideBusinessHours(tuesday(8))).toBe(true);
  });

  it("returns true for a time at or after 18 on a weekday", () => {
    expect(isOutsideBusinessHours(tuesday(18))).toBe(true);
    expect(isOutsideBusinessHours(tuesday(22))).toBe(true);
  });

  it("returns true for any time on a weekend day, even within 9-18", () => {
    expect(isOutsideBusinessHours(saturday(12))).toBe(true);
  });
});
