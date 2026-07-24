import { greet, greetAll, farewell, greetFormal } from "../lib/greetkit/index.js";

// Batch-greet a whole team. Uses greetAll — the batch convenience.
export function welcomeTeam(names) {
  return greetAll(names);
}

// Standup banner: a formal greeting for the chair + one greeting per attendee.
export function standupBanner(chair, attendees) {
  const lines = [greetFormal(chair, "Chair")];
  for (const a of attendees) lines.push(greet(a));
  return lines.join("\n");
}

// A formal invitation line.
export function formalInvite(name) {
  return `You are invited. ${greetFormal(name, "Dr.")}`;
}

// Sign off a single person.
export function signoff(name) {
  return farewell(name);
}

// Close a meeting: a farewell to everyone.
export function closeMeeting(names) {
  return names.map((n) => farewell(n)).join(" ");
}

// A two-person greeting (control: greet is unchanged in 2.0.0).
export function pairGreeting(a, b) {
  return `${greet(a)} & ${greet(b)}`;
}
