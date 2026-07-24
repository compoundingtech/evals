import test from "node:test";
import assert from "node:assert/strict";
import {
  welcomeTeam, standupBanner, formalInvite, signoff, closeMeeting, pairGreeting,
} from "../src/app.js";

test("welcomeTeam greets everyone", () => {
  assert.deepEqual(welcomeTeam(["Ana", "Bo"]), ["Hello, Ana!", "Hello, Bo!"]);
});

test("standupBanner: formal chair + a line per attendee", () => {
  assert.equal(
    standupBanner("Lee", ["Ana", "Bo"]),
    "Good day, Chair Lee.\nHello, Ana!\nHello, Bo!",
  );
});

test("formalInvite", () => {
  assert.equal(formalInvite("Ana"), "You are invited. Good day, Dr. Ana.");
});

test("signoff says goodbye", () => {
  assert.equal(signoff("Ana"), "Goodbye, Ana.");
});

test("closeMeeting farewells everyone", () => {
  assert.equal(closeMeeting(["Ana", "Bo"]), "Goodbye, Ana. Goodbye, Bo.");
});

test("pairGreeting", () => {
  assert.equal(pairGreeting("Ana", "Bo"), "Hello, Ana! & Hello, Bo!");
});
