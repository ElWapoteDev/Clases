/* Clases docs — renderiza el markdown de cada tema como una pagina del sitio.
   Fuente unica: los .md del repo. marked esta vendorizado (funciona sin red);
   Shiki resalta via CDN como mejora progresiva. Sin paso de build. */

(function () {
	"use strict";

	var REPO = "https://github.com/ElWapoteDev/Clases";

	var PAGES = [
		{ slug: "intro", file: "README.md", title: "Introducción" },
		{ slug: "installation", file: "INSTALLATION.md", title: "Instalación" },
		{ slug: "typing", file: "TYPING.md", title: "Tipado estricto" },
		{ slug: "api", file: "API.md", title: "API completa" },
		{ slug: "lifecycle", file: "LIFECYCLE.md", title: "Lifecycle y cleanup" },
		{ slug: "mixins", file: "MIXINS.md", title: "Herencia y mixins" },
		{ slug: "roblox", file: "ROBLOX.md", title: "Uso en Roblox" },
		{ slug: "migration", file: "MIGRATION.md", title: "Migración" },
		{ slug: "design", file: "DESIGN.md", title: "Diseño interno" },
		{ slug: "publishing", file: "PUBLISHING.md", title: "Publicación" },
		{ slug: "faq", file: "FAQ.md", title: "FAQ" },
	];

	var FILE_TO_SLUG = {};
	PAGES.forEach(function (p) {
		FILE_TO_SLUG[p.file.toLowerCase()] = p.slug;
	});

	var SHIKI_LANGS = ["luau", "lua", "bash", "sh", "json", "toml", "typescript", "ts", "javascript", "js"];

	function slugify(text) {
		return text
			.toLowerCase()
			.normalize("NFD")
			.replace(/[̀-ͯ]/g, "")
			.replace(/[^a-z0-9]+/g, "-")
			.replace(/^-+|-+$/g, "");
	}

	function wireTheme() {
		var toggle = document.getElementById("theme-toggle");
		if (!toggle) return;
		toggle.addEventListener("click", function () {
			var next = document.documentElement.getAttribute("data-theme") === "light" ? "dark" : "light";
			document.documentElement.setAttribute("data-theme", next);
			try {
				localStorage.setItem("clases-theme", next);
			} catch (e) {}
		});
	}

	function buildSidebar(docFile) {
		var nav = document.getElementById("sidebar-nav");
		if (!nav) return;
		var active = FILE_TO_SLUG[(docFile || "").toLowerCase()];
		PAGES.forEach(function (p) {
			var a = document.createElement("a");
			a.href = p.slug + ".html";
			a.textContent = p.title;
			if (p.slug === active) a.classList.add("active");
			nav.appendChild(a);
		});
	}

	function rewriteLinks(root) {
		root.querySelectorAll("a[href]").forEach(function (a) {
			var href = a.getAttribute("href");
			if (!href || href.charAt(0) === "#" || /^[a-z]+:/i.test(href)) return;

			var clean = href.replace(/^\.\//, "").replace(/^(\.\.\/)+/, "").replace(/^docs\//, "");
			var hashAt = clean.indexOf("#");
			var path = (hashAt >= 0 ? clean.slice(0, hashAt) : clean).toLowerCase();
			var anchor = hashAt >= 0 ? clean.slice(hashAt) : "";

			if (FILE_TO_SLUG[path]) {
				a.setAttribute("href", FILE_TO_SLUG[path] + ".html" + anchor);
			} else {
				// Archivo del repo que no es una pagina de docs: apunta a GitHub.
				a.setAttribute("href", REPO + "/blob/main/" + clean);
			}
		});
	}

	function enhanceHeadings(root) {
		root.querySelectorAll("h2, h3").forEach(function (h) {
			if (!h.id) h.id = slugify(h.textContent);
		});
	}

	function buildToc(root) {
		var toc = document.getElementById("toc-nav");
		var wrap = document.getElementById("doc-toc");
		if (!toc) return;
		var heads = Array.prototype.slice.call(root.querySelectorAll("h2"));
		if (!heads.length) {
			if (wrap) wrap.style.display = "none";
			return;
		}
		var links = {};
		heads.forEach(function (h) {
			var a = document.createElement("a");
			a.href = "#" + h.id;
			a.textContent = h.textContent;
			toc.appendChild(a);
			links[h.id] = a;
		});
		var observer = new IntersectionObserver(
			function (entries) {
				entries.forEach(function (entry) {
					if (entry.isIntersecting) {
						Object.keys(links).forEach(function (k) {
							links[k].classList.remove("active");
						});
						if (links[entry.target.id]) links[entry.target.id].classList.add("active");
					}
				});
			},
			{ rootMargin: "-12% 0px -75% 0px" }
		);
		heads.forEach(function (h) {
			observer.observe(h);
		});
	}

	function wireCopy(btn, code) {
		var done = function () {
			btn.textContent = "Copiado";
			btn.classList.add("copied");
			setTimeout(function () {
				btn.textContent = "Copiar";
				btn.classList.remove("copied");
			}, 1400);
		};
		var fail = function () {
			btn.textContent = "Error";
			setTimeout(function () {
				btn.textContent = "Copiar";
			}, 1400);
		};
		btn.addEventListener("click", function () {
			var text = code ? code.textContent : "";
			if (navigator.clipboard && navigator.clipboard.writeText) {
				navigator.clipboard.writeText(text).then(done).catch(fail);
				return;
			}
			try {
				var ta = document.createElement("textarea");
				ta.value = text;
				ta.style.position = "fixed";
				ta.style.opacity = "0";
				document.body.appendChild(ta);
				ta.select();
				var ok = document.execCommand("copy");
				document.body.removeChild(ta);
				ok ? done() : fail();
			} catch (e) {
				fail();
			}
		});
	}

	function enhanceCode(root) {
		root.querySelectorAll("pre").forEach(function (pre) {
			pre.classList.add("doc-pre");
			var code = pre.querySelector("code");
			var btn = document.createElement("button");
			btn.className = "copy";
			btn.type = "button";
			btn.textContent = "Copiar";
			wireCopy(btn, code);
			pre.appendChild(btn);
		});
	}

	function highlight(root) {
		var blocks = Array.prototype.slice.call(root.querySelectorAll("pre > code"));
		if (!blocks.length) return Promise.resolve();
		return import("https://esm.sh/shiki@3.23.0")
			.then(function (shiki) {
				var codeToHtml = shiki.codeToHtml;
				return Promise.allSettled(
					blocks.map(function (code) {
						var m = (code.className || "").match(/language-([\w-]+)/);
						var lang = m ? m[1] : "text";
						if (lang === "sh") lang = "bash";
						if (SHIKI_LANGS.indexOf(lang) === -1) lang = "text";
						return codeToHtml(code.textContent, {
							lang: lang,
							themes: { light: "github-light", dark: "github-dark" },
							defaultColor: false,
							colorReplacements: { "github-dark": { "#6a737d": "#8b949e" } },
						})
							.then(function (html) {
								var tpl = document.createElement("template");
								tpl.innerHTML = html.trim();
								var sc = tpl.content.querySelector("code");
								if (sc) code.innerHTML = sc.innerHTML;
							})
							.catch(function () {});
					})
				);
			})
			.catch(function () {});
	}

	function render(content, md) {
		var parse = window.marked && (marked.parse || (marked.marked && marked.marked.parse));
		if (typeof parse === "function") {
			content.innerHTML = parse(md, { gfm: true });
			return true;
		}
		// Fallback extremo: marked no cargo. Muestra el texto plano legible.
		content.innerHTML = "";
		var pre = document.createElement("pre");
		pre.className = "doc-pre";
		var code = document.createElement("code");
		code.textContent = md;
		pre.appendChild(code);
		content.appendChild(pre);
		return false;
	}

	function main() {
		wireTheme();
		var docFile = document.body.getAttribute("data-doc");
		buildSidebar(docFile);

		var content = document.getElementById("doc-content");
		if (!content) return;

		fetch(docFile, { cache: "no-cache" })
			.then(function (res) {
				if (!res.ok) throw new Error(String(res.status));
				return res.text();
			})
			.then(function (md) {
				var ok = render(content, md);
				if (!ok) return;
				rewriteLinks(content);
				enhanceHeadings(content);
				buildToc(content);
				enhanceCode(content);
				return highlight(content);
			})
			.catch(function () {
				content.innerHTML =
					'<h1>Documentación</h1><p class="doc-error">No se pudo cargar esta página. ' +
					'Léela en <a href="' +
					REPO +
					"/blob/main/docs/" +
					docFile +
					'">GitHub</a>.</p>';
			});
	}

	if (document.readyState === "loading") {
		document.addEventListener("DOMContentLoaded", main);
	} else {
		main();
	}
})();
