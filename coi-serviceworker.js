/*! coi-serviceworker v0.1.6 - Guido Zuidhof, licensed under MIT */
if(typeof window === 'undefined') {
    self.addEventListener("install", () => self.skipWaiting());
    self.addEventListener("activate", (event) => event.waitUntil(self.clients.claim()));

    self.addEventListener("message", (ev) => {
        if (!ev.data) {
            return;
        } else if (ev.data.type === "deregister") {
            self.registration.unregister().then(() => {
                return self.clients.matchAll();
            }).then(clients => {
                clients.forEach(client => client.navigate(client.url));
            });
        }
    });

    self.addEventListener("fetch", function (event) {
        if (event.request.cache === "only-if-cached" && event.request.mode !== "same-origin") {
            return;
        }

        event.respondWith(
            fetch(event.request)
                .then((response) => {
                    if (response.status === 0) {
                        return response;
                    }

                    const newHeaders = new Headers(response.headers);
                    newHeaders.set("Cross-Origin-Embedder-Policy", "require-corp");
                    newHeaders.set("Cross-Origin-Opener-Policy", "same-origin");

                    return new Response(response.body, {
                        status: response.status,
                        statusText: response.statusText,
                        headers: newHeaders,
                    });
                })
                .catch((e) => console.error(e))
        );
    });

} else {
    (() => {
        const reloadedBySelf = window.sessionStorage.getItem("coiReloadedBySelf");
        window.sessionStorage.removeItem("coiReloadedBySelf");
        const cois = {
            shouldRegister: () => !reloadedBySelf,
            shouldDeregister: () => false,
            doReload: () => window.location.reload(),
            quiet: false,
            ...window.coi
        };

        const n = navigator;
        if (n.serviceWorker && n.serviceWorker.controller) {
            n.serviceWorker.controller.postMessage({ type: "coi-ping" });
        }

        if (cois.shouldRegister()) {
            if (window.isSecureContext) {
                n.serviceWorker.register(window.document.currentScript.src).then(
                    (registration) => {
                        window.sessionStorage.setItem("coiReloadedBySelf", "true");
                        cois.doReload();
                    },
                    (err) => {
                        if (!cois.quiet) console.error("COI Service Worker failed to register:", err);
                    }
                );
            } else {
                if (!cois.quiet) console.log("COI Service Worker requires a secure context (HTTPS)");
            }
        }
    })();
}
