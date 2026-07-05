const resourceName = typeof GetParentResourceName === "function" ? GetParentResourceName() : "zeekota_hotel";

const state = {
    theme: {
        brand: "Wiwang Hotel",
        subtitle: "Guest Services",
        accent: "#e50914",
        colors: {},
        gradients: {}
    }
};

const promptEl = document.getElementById("prompt");
const promptKeyEl = document.getElementById("prompt-key");
const promptLabelEl = document.getElementById("prompt-label");
const promptGuideEl = document.getElementById("prompt-guide");
const menuEl = document.getElementById("menu");
const menuTitleEl = document.getElementById("menu-title");
const menuSubtitleEl = document.getElementById("menu-subtitle");
const menuItemsEl = document.getElementById("menu-items");
const menuCloseEl = document.getElementById("menu-close");
const toastsEl = document.getElementById("toasts");

function post(name, data = {}) {
    return fetch(`https://${resourceName}/${name}`, {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=UTF-8" },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function applyTheme(theme) {
    state.theme = { ...state.theme, ...(theme || {}) };
    const colors = state.theme.colors || {};
    const gradients = state.theme.gradients || {};
    const root = document.documentElement.style;

    root.setProperty("--accent", colors.Accent || state.theme.accent || "#e50914");
    root.setProperty("--accent-dark", colors.AccentDark || "#7a050b");
    root.setProperty("--accent-soft", colors.AccentSoft || "rgba(229, 9, 20, 0.26)");
    root.setProperty("--bg", colors.Background || "rgba(6, 7, 10, 0.78)");
    root.setProperty("--panel", colors.Panel || "rgba(12, 13, 17, 0.98)");
    root.setProperty("--panel-alt", colors.PanelAlt || "rgba(31, 33, 39, 0.94)");
    root.setProperty("--line", colors.Border || "rgba(255, 255, 255, 0.16)");
    root.setProperty("--text", colors.Text || "#ffffff");
    root.setProperty("--muted", colors.Muted || "#b8bcc7");
    root.setProperty("--danger", colors.Danger || "#ff4655");
    root.setProperty("--success", colors.Success || "#25d17f");
    root.setProperty("--shadow", colors.Shadow || "rgba(0, 0, 0, 0.58)");
    root.setProperty("--prompt-gradient", gradients.Prompt || "linear-gradient(135deg, rgba(229, 9, 20, 0.98), rgba(10, 10, 14, 0.96) 46%, rgba(122, 5, 11, 0.95))");
    root.setProperty("--prompt-key-gradient", gradients.PromptKey || "linear-gradient(180deg, #ffffff, #e9e9ec)");
    root.setProperty("--panel-gradient", gradients.Panel || "linear-gradient(145deg, rgba(7, 8, 12, 0.99), rgba(22, 23, 29, 0.98) 58%, rgba(80, 4, 10, 0.92))");
    root.setProperty("--header-gradient", gradients.Header || "linear-gradient(135deg, rgba(229, 9, 20, 0.95), rgba(22, 23, 29, 0.92))");
    root.setProperty("--item-gradient", gradients.Item || "linear-gradient(135deg, rgba(255, 255, 255, 0.08), rgba(255, 255, 255, 0.035))");
    root.setProperty("--item-hover-gradient", gradients.ItemHover || "linear-gradient(135deg, rgba(229, 9, 20, 0.32), rgba(255, 255, 255, 0.08))");
    root.setProperty("--toast-gradient", gradients.Toast || "linear-gradient(135deg, rgba(8, 9, 12, 0.98), rgba(22, 23, 29, 0.95))");
}

function setPrompt(payload) {
    if (!payload.show) {
        promptEl.classList.add("hidden");
        promptEl.classList.remove("prompt-guide-mode");
        promptGuideEl.innerHTML = "";
        return;
    }

    promptKeyEl.textContent = payload.key || "E";
    promptLabelEl.textContent = payload.label || "Interact";
    promptGuideEl.innerHTML = "";

    if (Array.isArray(payload.guide) && payload.guide.length > 0) {
        payload.guide.forEach((item) => {
            const tile = document.createElement("article");
            tile.className = "guide-tile";

            const image = document.createElement("img");
            image.className = "guide-key-image";
            image.src = item.image || "";
            image.alt = item.key || "Keyboard key";
            tile.appendChild(image);

            const text = document.createElement("div");
            text.className = "guide-text";

            const key = document.createElement("span");
            key.className = "guide-key-text";
            key.textContent = item.key || "";
            text.appendChild(key);

            const action = document.createElement("span");
            action.className = "guide-action";
            action.textContent = item.action || "";
            text.appendChild(action);

            tile.appendChild(text);
            promptGuideEl.appendChild(tile);
        });

        promptEl.classList.add("prompt-guide-mode");
    } else {
        promptEl.classList.remove("prompt-guide-mode");
    }

    promptEl.classList.remove("hidden");
}

function closeMenu() {
    menuEl.classList.add("hidden");
    menuItemsEl.innerHTML = "";
    post("closeMenu");
}

function selectItem(action) {
    if (!action) return;
    post("menuSelect", { action });
}

function createMenuItem(item) {
    const button = document.createElement("button");
    button.className = `menu-item ${item.tone === "danger" ? "danger" : ""}`;
    button.type = "button";

    if (item.disabled) {
        button.disabled = true;
    }

    const title = document.createElement("span");
    title.className = "item-title";
    title.textContent = item.title || "Option";
    button.appendChild(title);

    if (item.description) {
        const description = document.createElement("span");
        description.className = "item-description";
        description.textContent = item.description;
        button.appendChild(description);
    }

    button.addEventListener("click", () => selectItem(item.action));
    return button;
}

function setMenu(payload) {
    if (!payload.show) {
        menuEl.classList.add("hidden");
        return;
    }

    menuTitleEl.textContent = payload.title || state.theme.brand;
    menuSubtitleEl.textContent = payload.subtitle || state.theme.subtitle || "";
    menuItemsEl.innerHTML = "";

    (payload.items || []).forEach((item) => {
        menuItemsEl.appendChild(createMenuItem(item));
    });

    menuEl.classList.remove("hidden");
}

function pushToast(payload) {
    const toast = document.createElement("article");
    toast.className = `toast ${payload.kind || "inform"}`;

    const title = document.createElement("p");
    title.className = "toast-title";
    title.textContent = payload.title || state.theme.brand;
    toast.appendChild(title);

    const message = document.createElement("p");
    message.className = "toast-message";
    message.textContent = payload.message || "";
    toast.appendChild(message);

    toastsEl.appendChild(toast);

    window.setTimeout(() => {
        toast.style.opacity = "0";
        toast.style.transform = "translateX(0.55rem)";
        toast.style.transition = "opacity 160ms ease, transform 160ms ease";
    }, 4200);

    window.setTimeout(() => {
        toast.remove();
    }, 4450);
}

window.addEventListener("message", (event) => {
    const data = event.data || {};

    if (data.type === "theme") {
        applyTheme(data.theme);
    } else if (data.type === "prompt") {
        setPrompt(data);
    } else if (data.type === "menu") {
        setMenu(data);
    } else if (data.type === "toast") {
        pushToast(data);
    }
});

menuCloseEl.addEventListener("click", closeMenu);

window.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
        closeMenu();
    }
});

post("ready");
