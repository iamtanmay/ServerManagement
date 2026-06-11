/* Server Management Action Buttons
 * Injects Power On / Power Off buttons into each LLM server card
 * Calls Flask API: http://100.115.26.71:9001/<action>/<server_id>
 */

(function () {
  const SERVERS = [
    {
      name: "Matter Smart Plug",
      id: 1,
      onAction:  "switch_smart_plug_on",
      offAction: "switch_smart_plug_off",
    },
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

function injectMyCustomFooter() {
    if (document.getElementById("my-custom-homelab-footer")) return;

    const layoutContainer = document.querySelector('main') || document.body;
    if (!layoutContainer) return;

    const footerDiv = document.createElement("div");
    footerDiv.id = "my-custom-homelab-footer";
    footerDiv.style.cssText = "text-align: center; margin: 20px auto; padding: 10px; width: 100%; max-width: 600px; position: relative; z-index: 9999; clear: both;";

    const meterImg = document.createElement("img");
    const baseImgUrl = "http://192.168.1.101:9001/power_meter2.jpg";
    meterImg.src = baseImgUrl;
    meterImg.alt = "Power Meter Status";
    meterImg.style.cssText = "display: block; width: 60%; height: auto; align-self: flex-start; justify-self: start; margin-left: -500; margin-right: auto; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.5);";


    const imgLink = document.createElement("a");
    imgLink.href = "http://192.168.1.101:9001/power_meter.jpg";
    imgLink.target = "_blank"; // This opens it in a new tab
    imgLink.appendChild(meterImg);

    footerDiv.appendChild(imgLink);
    layoutContainer.prepend(footerDiv);

    setInterval(() => {
      const uniqueToken = Date.now();
      meterImg.src = `${baseImgUrl}?t=${uniqueToken}`;
    }, 10000);
  }

  // Check until page layout is ready, then add the footer elements
  const footerCheckInterval = setInterval(() => {
    const target = document.querySelector('main') || document.getElementById("layout");
    if (target) {
      injectMyCustomFooter();
      clearInterval(footerCheckInterval);
    }
  }, 1000);

  // Wait for cards to render, then observe for dynamic updates
  const observer = new MutationObserver(injectAll);
  observer.observe(document.body, { childList: true, subtree: true });
  injectAll();

  if (document.readyState === "complete" || document.readyState === "interactive") {
    injectMyCustomFooter();
  } else {
    window.addEventListener("DOMContentLoaded", injectMyCustomFooter);
  }

})();


