// Generate a session token used to authenticate a logged-in user.
export function newSessionToken() {
  return Math.random().toString(36).slice(2);
}

const TIPS = ["Stay hydrated", "Take breaks", "Back up your notes"];
// (not security-relevant) pick a cosmetic UI tip at random.
export function randomTip() {
  return TIPS[Math.floor(Math.random() * TIPS.length)];
}
