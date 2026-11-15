const states = {
  running: [
    "Cluster running",
    "Azure reports the cluster is running. Individual applications may still be starting or unavailable.",
  ],
  stopped: [
    "Cluster stopped",
    "The AKS environment is paused to control costs. Explore the platform's source below.",
  ],
  absent: [
    "Not provisioned",
    "The disposable AKS environment is currently torn down. This site and the source remain available.",
  ],
  changing: [
    "Cluster changing",
    "Azure is creating, updating or removing the environment. Applications may be unavailable.",
  ],
  degraded: [
    "Cluster needs attention",
    "Azure reports an unsuccessful cluster operation. The platform source remains available below.",
  ],
  unknown: [
    "Status unavailable",
    "We couldn't confirm the current cluster state. Try refreshing in a moment.",
  ],
};

const display = document.querySelector("#status-display");
const heading = document.querySelector("#status-heading");
const description = document.querySelector("#status-description");
const checkedAt = document.querySelector("#checked-at");
const announcement = document.querySelector("#status-announcement");
const refresh = document.querySelector("#refresh");
let pending = false;

async function updateStatus() {
  if (pending) return;
  pending = true;
  refresh.disabled = true;
  display.setAttribute("aria-busy", "true");

  try {
    const response = await fetch("/api/status", {
      cache: "no-store",
      signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) throw new Error("Status unavailable");
    const result = await response.json();
    if (!Object.hasOwn(states, result.state)) throw new Error("Unknown status");
    const timestamp = new Date(result.checked_at);
    if (Number.isNaN(timestamp.getTime()))
      throw new Error("Missing check time");

    display.dataset.state = result.state;
    [heading.textContent, description.textContent] = states[result.state];
    checkedAt.textContent = `Checked ${timestamp.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}`;
    checkedAt.title = timestamp.toLocaleString();
    announcement.textContent = "Cluster power state, not individual application health. Checked when you visit or return to this tab.";
  } catch {
    display.dataset.state = "unknown";
    [heading.textContent, description.textContent] = states.unknown;
    checkedAt.textContent = "No current status";
    checkedAt.removeAttribute("title");
    announcement.textContent =
      "Cluster status is unavailable. This does not mean the cluster is stopped.";
  } finally {
    pending = false;
    refresh.disabled = false;
    display.removeAttribute("aria-busy");
  }
}

refresh.addEventListener("click", updateStatus);
document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible") updateStatus();
});
updateStatus();
