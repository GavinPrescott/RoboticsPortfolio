/* journey.js — About Me page: highlights the map pin + timeline entry for the
   section you're reading, and draws the route up to that point. */
(function () {
	var eras = Array.prototype.slice.call(document.querySelectorAll('.era[id^="era-"]'));
	var items = Array.prototype.slice.call(document.querySelectorAll('.journey-timeline li'));
	var pins = Array.prototype.slice.call(document.querySelectorAll('.journey-map .pin'));
	var segs = Array.prototype.slice.call(document.querySelectorAll('.journey-map .seg'));
	if (!eras.length || !items.length) return;

	function setActive(n) {
		var visitedPlaces = {};
		items.forEach(function (li) {
			var e = +li.dataset.era;
			li.classList.toggle('active', e === n);
			li.classList.toggle('visited', e < n);
			if (e <= n) visitedPlaces[li.dataset.place] = true;
		});
		var activePlace = (items[n - 1] || {}).dataset ? items[n - 1].dataset.place : null;
		pins.forEach(function (p) {
			p.classList.toggle('active', p.dataset.place === activePlace);
			p.classList.toggle('visited', !!visitedPlaces[p.dataset.place]);
		});
		segs.forEach(function (s) { s.classList.toggle('done', +s.dataset.to <= n); });
	}

	// The active era is the last one whose top has scrolled past 40% of the screen.
	function update() {
		var line = window.innerHeight * 0.4, n = 0;
		eras.forEach(function (el, i) { if (el.getBoundingClientRect().top < line) n = i + 1; });
		// At the very bottom of the page, the last era is always the active one
		if (window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 4) n = eras.length;
		setActive(n);
	}
	var ticking = false;
	window.addEventListener('scroll', function () {
		if (!ticking) { ticking = true; requestAnimationFrame(function () { update(); ticking = false; }); }
	}, { passive: true });
	window.addEventListener('resize', update);

	// Smooth-scroll when a timeline entry is clicked
	items.forEach(function (li) {
		li.querySelector('a').addEventListener('click', function (ev) {
			var t = document.querySelector(this.getAttribute('href'));
			if (t) { ev.preventDefault(); t.scrollIntoView({ behavior: 'smooth', block: 'start' }); history.replaceState(null, '', this.getAttribute('href')); }
		});
	});
	update();
})();
