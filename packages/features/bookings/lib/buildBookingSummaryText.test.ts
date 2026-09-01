import dayjs from "@calcom/dayjs";
import type { TFunction } from "i18next";
import { describe, expect, it } from "vitest";
import { buildBookingSummaryText } from "./buildBookingSummaryText";

const t = ((key: string) => key) as unknown as TFunction;

describe("buildBookingSummaryText", () => {
  const date = dayjs.utc("2026-09-01T14:30:00.000Z");

  it("includes the title as the first line", () => {
    const summary = buildBookingSummaryText({
      title: "30min between John and Jane",
      date,
      duration: 30,
      timeZone: "UTC",
      language: "en",
      is24h: true,
      t,
    });

    expect(summary.split("\n")[0]).toBe("30min between John and Jane");
  });

  it("formats date, time and timezone lines using the provided labels", () => {
    const summary = buildBookingSummaryText({
      title: "30min between John and Jane",
      date,
      duration: 30,
      timeZone: "UTC",
      language: "en",
      is24h: true,
      t,
    });

    const lines = summary.split("\n");
    expect(lines[1]).toMatch(/^date: /);
    expect(lines[2]).toBe("time: 14:30 - 15:00");
    expect(lines[3]).toBe("timezone: Coordinated Universal Time");
  });

  it("shows only the start time when no duration is provided", () => {
    const summary = buildBookingSummaryText({
      title: "30min between John and Jane",
      date,
      timeZone: "UTC",
      language: "en",
      is24h: true,
      t,
    });

    const timeLine = summary.split("\n").find((line) => line.startsWith("time: "));
    expect(timeLine).toBe("time: 14:30");
  });

  it("appends a location line when a location is provided", () => {
    const summary = buildBookingSummaryText({
      title: "30min between John and Jane",
      date,
      duration: 30,
      timeZone: "UTC",
      language: "en",
      is24h: true,
      location: "Google Meet",
      t,
    });

    expect(summary.split("\n")).toContain("location: Google Meet");
  });

  it("omits the location line when no location is provided", () => {
    const summary = buildBookingSummaryText({
      title: "30min between John and Jane",
      date,
      duration: 30,
      timeZone: "UTC",
      language: "en",
      is24h: true,
      t,
    });

    expect(summary).not.toMatch(/^location: /m);
  });

  it("respects 12h formatting when is24h is false", () => {
    const summary = buildBookingSummaryText({
      title: "30min between John and Jane",
      date,
      duration: 30,
      timeZone: "UTC",
      language: "en",
      is24h: false,
      t,
    });

    const timeLine = summary.split("\n").find((line) => line.startsWith("time: "));
    expect(timeLine).toBe("time: 2:30 PM - 3:00 PM");
  });
});
