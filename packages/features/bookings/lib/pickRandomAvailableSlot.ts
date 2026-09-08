import type { Dayjs } from "@calcom/dayjs";
import dayjs from "@calcom/dayjs";
import { isOutsideBusinessHours } from "./isOutsideBusinessHours";

// "Book for me" picks from a future window of already-fetched slots, not the
// event's entire remaining availability, to keep the pick fast and close to
// "now". Kept small and named so it's easy to bump later if that changes.
export const RANDOM_SLOT_WINDOW_DAYS = 7;

export type RandomSlotCandidate = {
  time: string;
  away?: boolean;
  attendees?: number;
};

export type PickRandomAvailableSlotInput = {
  /** Map of "YYYY-MM-DD" -> slots for that day, as returned by the schedule query. */
  slotsByDate: Record<string, RandomSlotCandidate[] | undefined>;
  /** Reference instant the window is measured from. */
  now: Dayjs;
  /** Size of the future window to search, in days. */
  windowDays?: number;
  /** Host/organizer timezone the business-hours preference is evaluated in. */
  timeZone: string;
  /** Seats-per-slot for seated event types, to exclude fully-booked slots. */
  seatsPerTimeSlot?: number | null;
  /** Slots currently held/unavailable (e.g. reserved by another tentative booking). */
  unavailableTimeSlots?: string[];
  /** Injectable random source in [0, 1). Defaults to Math.random; override in tests. */
  random?: () => number;
};

/**
 * Randomly picks one bookable slot within a future window, preferring a slot
 * inside business hours (see `isOutsideBusinessHours`) when at least one is
 * available, and otherwise falling back to any eligible slot in the window.
 *
 * Returns the picked slot's ISO time string, or `null` if nothing is
 * eligible.
 */
export function pickRandomAvailableSlot({
  slotsByDate,
  now,
  windowDays = RANDOM_SLOT_WINDOW_DAYS,
  timeZone,
  seatsPerTimeSlot,
  unavailableTimeSlots = [],
  random = Math.random,
}: PickRandomAvailableSlotInput): string | null {
  const windowEnd = now.add(windowDays, "day");

  const eligible = Object.values(slotsByDate)
    .flatMap((slots) => slots ?? [])
    .filter((slot) => !slot.away)
    .filter((slot) => !unavailableTimeSlots.includes(slot.time))
    .filter((slot) => !(seatsPerTimeSlot && slot.attendees && slot.attendees >= seatsPerTimeSlot))
    .filter((slot) => {
      const time = dayjs.utc(slot.time);
      return time.isAfter(now) && time.isBefore(windowEnd);
    });

  if (eligible.length === 0) return null;

  const withinBusinessHours = eligible.filter(
    (slot) => !isOutsideBusinessHours(dayjs.utc(slot.time).tz(timeZone))
  );

  const pool = withinBusinessHours.length > 0 ? withinBusinessHours : eligible;
  const index = Math.min(pool.length - 1, Math.floor(random() * pool.length));
  return pool[index].time;
}
