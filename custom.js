/* Server Management Action Buttons
 * Injects Power On / Power Off buttons into each LLM server card
 * Calls Flask API: http://100.115.26.71:9001/<action>/<server_id>
 */

(function () {
  const SERVERS = [
    {
      name: "LLM Server Small",
      id: 2,
      onAction:  "switch_smart_plug_restart",
      offAction: "stop_server",
    },
    {
      name: "LLM Server Medium",
      id: 3,
      onAction:  "wake_server",
      offAction: "stop_server",
    },
    {
      name: "LLM Server Large",
      id: 4,
      onAction:  "wake_server",
      offAction: "stop_server",
    },
  ];

  const API = "http://100.115.26.71:9001";

  function triggerAction(action, serverId, btn) {
    btn.disabled = true;
    btn.textContent = "…";

    fetch(`${API}/${action}/${serverId}`)
      .then((r) => r.json())
      .then((data) => {
        btn.textContent = data.success ? "✓" : "✗";
        setTimeout(() => restoreButton(btn), 2000);
      })
      .catch(() => {
        btn.textContent = "✗";
        setTimeout(() => restoreButton(btn), 2000);
      });
  }

  function restoreButton(btn) {
    btn.disabled = false;
    btn.textContent = btn.dataset.label;
  }

  function makeButton(label, action, serverId) {
    const btn = document.createElement("button");
    btn.textContent = label;
    btn.dataset.label = label;
    btn.title = `${label} — ${action}`;
    btn.style.cssText = `
      font-size: 10px;
      font-weight: 600;
      padding: 2px 7px;
      border-radius: 4px;
      border: none;
      cursor: pointer;
      background: rgba(255,255,255,0.15);
      color: inherit;
      transition: background 0.15s;
    `;
    btn.onmouseenter = () => (btn.style.background = "rgba(255,255,255,0.3)");
    btn.onmouseleave = () => (btn.style.background = "rgba(255,255,255,0.15)");
    btn.onclick = (e) => {
      e.preventDefault();
      e.stopPropagation();
      triggerAction(action, serverId, btn);
    };
    return btn;
  }

  function injectButtons(server) {
    const card = document.querySelector(
      `li.service[data-name="${server.name}"]`
    );
    if (!card || card.dataset.actionsInjected) return;

    const tagsEl = card.querySelector(".service-tags");
    if (!tagsEl) return;

    const wrapper = document.createElement("div");
    wrapper.style.cssText =
      "display:flex; gap:4px; align-items:center; margin-right: 4px;";

    wrapper.appendChild(makeButton("▶ On",  server.onAction,  server.id));
    wrapper.appendChild(makeButton("■ Off", server.offAction, server.id));

    tagsEl.prepend(wrapper);
    card.dataset.actionsInjected = "1";
  }

  function injectAll() {
    SERVERS.forEach(injectButtons);
  }

  // Wait for cards to render, then observe for dynamic updates
  const observer = new MutationObserver(injectAll);
  observer.observe(document.body, { childList: true, subtree: true });
  injectAll();
})();
