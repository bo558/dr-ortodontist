/* Dr. Ortodontist — progressive enhancement only. The site is fully usable without JS. */
(function () {
  "use strict";

  var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* Header state on scroll */
  var header = document.querySelector(".site-header");
  function onScroll() {
    if (header) header.classList.toggle("is-scrolled", window.scrollY > 24);
  }
  onScroll();
  window.addEventListener("scroll", onScroll, { passive: true });

  /* Mobile navigation */
  var toggle = document.querySelector(".nav-toggle");
  var panel = document.getElementById("mobile-nav");
  var lastFocus = null;

  function focusables() {
    return panel.querySelectorAll("a[href], button:not([disabled])");
  }
  function openNav() {
    lastFocus = document.activeElement;
    panel.classList.add("is-open");
    panel.removeAttribute("inert");
    panel.setAttribute("aria-hidden", "false");
    toggle.setAttribute("aria-expanded", "true");
    document.body.classList.add("nav-open");
    var items = focusables();
    if (items.length) items[0].focus();
  }
  function closeNav() {
    panel.classList.remove("is-open");
    panel.setAttribute("inert", "");
    panel.setAttribute("aria-hidden", "true");
    toggle.setAttribute("aria-expanded", "false");
    document.body.classList.remove("nav-open");
    if (lastFocus) lastFocus.focus();
  }
  if (toggle && panel) {
    toggle.addEventListener("click", openNav);
    panel.querySelectorAll("[data-nav-close]").forEach(function (el) {
      el.addEventListener("click", closeNav);
    });
    panel.addEventListener("keydown", function (e) {
      if (e.key === "Escape") return closeNav();
      if (e.key !== "Tab") return;
      var items = focusables();
      var first = items[0];
      var last = items[items.length - 1];
      if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
      else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
    });
    window.addEventListener("resize", function () {
      if (window.innerWidth > 1120 && panel.classList.contains("is-open")) closeNav();
    });
  }

  /* Scroll reveal */
  var revealTargets = document.querySelectorAll("[data-reveal], .smile-arc");
  if (reduceMotion || !("IntersectionObserver" in window)) {
    revealTargets.forEach(function (el) { el.classList.add("is-visible"); });
  } else {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          io.unobserve(entry.target);
        }
      });
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.08 });
    revealTargets.forEach(function (el) { io.observe(el); });
  }

  /* Table of contents: highlight the section in view */
  var tocLinks = document.querySelectorAll(".toc a");
  if (tocLinks.length && "IntersectionObserver" in window) {
    var map = {};
    tocLinks.forEach(function (a) { map[a.getAttribute("href").slice(1)] = a; });
    var tocIo = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        tocLinks.forEach(function (a) { a.classList.remove("is-active"); });
        var link = map[entry.target.id];
        if (link) link.classList.add("is-active");
      });
    }, { rootMargin: "-20% 0px -70% 0px" });
    Object.keys(map).forEach(function (id) {
      var el = document.getElementById(id);
      if (el) tocIo.observe(el);
    });
  }

  /* Preview notice (preview builds only): dismiss for this page view */
  var notice = document.querySelector("[data-preview-notice]");
  if (notice) {
    notice.querySelector("[data-preview-notice-close]").addEventListener("click", function () {
      notice.hidden = true;
    });
  }

  /* Appointment form — PREVIEW ONLY.
     Nothing is sent, stored or logged. The form is reset after the notice is shown. */
  var form = document.querySelector("[data-preview-form]");
  if (form) {
    var status = form.querySelector(".form__status");
    form.addEventListener("submit", function (e) {
      e.preventDefault();
      if (!form.checkValidity()) {
        form.reportValidity();
        return;
      }
      form.reset();
      status.classList.add("is-visible");
      status.focus();
    });
  }
})();
