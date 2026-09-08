import dayjs from "@calcom/dayjs";
import { describe, expect, it } from "vitest";
import { pickRandomAvailableSlot } from "./pickRandomAvailableSlot";

// 2026-09-01 is a Tuesday.
const now = dayjs.utc("2026-09-01T08:00:00.000Z");

describe("pickRandomAvailableSlot", () => {
  it("returns null when there are no slots at all", () => {
    const result = pickRandomAvailableSlot({ slotsByDate: {}, now, timeZone: "UTC" });
    expect(result).toBeNull();
  });

  it("returns null when every slot is outside the future window", () => {
    const result = pickRandomAvailableSlot({
      slotsByDate: {
        "2026-09-01": [{ time: "2026-09-01T07:00:00.000Z" }], // in the past relative to `now`
        "2026-09-20": [{ time: "2026-09-20T10:00:00.000Z" }], // beyond the default 7-day window
      },
      now,
      timeZone: "UTC",
    });
    expect(result).toBeNull();
  });

  it("ignores out-of-office (away) slots", () => {
    const result = pickRandomAvailableSlot({
      slotsByDate: { "2026-09-02": [{ time: "2026-09-02T10:00:00.000Z", away: true }] },
      now,
      timeZone: "UTC",
    });
    expect(result).toBeNull();
  });

  it("ignores slots passed in as unavailable", () => {
    const result = pickRandomAvailableSlot({
      slotsByDate: { "2026-09-02": [{ time: "2026-09-02T10:00:00.000Z" }] },
      now,
      timeZone: "UTC",
      unavailableTimeSlots: ["2026-09-02T10:00:00.000Z"],
    });
    expect(result).toBeNull();
  });

  it("ignores fully-booked seated slots", () => {
    const result = pickRandomAvailableSlot({
      slotsByDate: { "2026-09-02": [{ time: "2026-09-02T10:00:00.000Z", attendees: 5 }] },
      now,
      timeZone: "UTC",
      seatsPerTimeSlot: 5,
    });
    expect(result).toBeNull();
  });

  it("prefers a slot within business hours over one outside, regardless of random draw", () => {
    const slotsByDate = {
      "2026-09-02": [
        { time: "2026-09-02T05:00:00.000Z" }, // 05:00 UTC -> outside business hours
        { time: "2026-09-02T10:00:00.000Z" }, // 10:00 UTC -> within business hours
      ],
    };
    // random() always returns a value that would pick index 0 if both were in the pool.
    const result = pickRandomAvailableSlot({ slotsByDate, now, timeZone: "UTC", random: () => 0 });
    expect(result).toBe("2026-09-02T10:00:00.000Z");
  });

  it("falls back to any eligible slot when none are within business hours", () => {
    const slotsByDate = {
      "2026-09-02": [{ time: "2026-09-02T05:00:00.000Z" }], // outside business hours, only option
    };
    const result = pickRandomAvailableSlot({ slotsByDate, now, timeZone: "UTC", random: () => 0 });
    expect(result).toBe("2026-09-02T05:00:00.000Z");
  });

  it("respects a custom window size", () => {
    const slotsByDate = { "2026-09-10": [{ time: "2026-09-10T10:00:00.000Z" }] };
    expect(pickRandomAvailableSlot({ slotsByDate, now, timeZone: "UTC", windowDays: 7 })).toBeNull();
    expect(pickRandomAvailableSlot({ slotsByDate, now, timeZone: "UTC", windowDays: 10 })).toBe(
      "2026-09-10T10:00:00.000Z"
    );
  });

  it("uses the injected random source to pick among an all-business-hours pool", () => {
    const slotsByDate = {
      "2026-09-02": [{ time: "2026-09-02T09:00:00.000Z" }, { time: "2026-09-02T10:00:00.000Z" }],
    };
    expect(pickRandomAvailableSlot({ slotsByDate, now, timeZone: "UTC", random: () => 0 })).toBe(
      "2026-09-02T09:00:00.000Z"
    );
    expect(pickRandomAvailableSlot({ slotsByDate, now, timeZone: "UTC", random: () => 0.99 })).toBe(
      "2026-09-02T10:00:00.000Z"
    );
  });
});
