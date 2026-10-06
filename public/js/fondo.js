/*  Fondo de estrellas  */
    (() => {
        const canvas = document.getElementById('starfield');
        const thema = localStorage.getItem("theme");
        if (!canvas) return;
        const ctx = canvas.getContext('2d');

        const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

        const PARALLAX = 0.35;

        let W, H, dpr, stars = [];
        let scrollY = window.scrollY || 0;
        let smoothScroll = scrollY; // valor suavizado para evitar saltos

        // 1 estrella por cada ~9000 px² de pantalla
        const DENSITY = 1 / 7000;

        function resize() {
        dpr = Math.min(window.devicePixelRatio || 1, 2);
        W = window.innerWidth;
        H = window.innerHeight;
        canvas.width  = W * dpr;
        canvas.height = H * dpr;
        ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

        const count = Math.max(80, Math.floor(W * H * DENSITY));
        stars = new Array(count).fill(0).map(makeStar);
        }

        function makeStar() {
        return {
            // x,y "de reposo" dentro del viewport (se ajustan con el scroll)
            x: Math.random() * W,
            y: Math.random() * H,
            r: Math.random() * 1.3 + 0.2,
            baseA: Math.random() * 0.6 + 0.2,
            phase: Math.random() * Math.PI * 2,
            speed: Math.random() * 0.015 + 0.005,
            // deriva propia, muy lenta
            vx: (Math.random() - 0.5) * 0.04,
            vy: (Math.random() - 0.5) * 0.04,
        };
        }

        // Seguimos el scroll real
        window.addEventListener('scroll', () => {
        scrollY = window.scrollY || window.pageYOffset || 0;
        }, { passive: true });

        let t = 0;
        function draw() {
        ctx.clearRect(0, 0, W, H);

        // Suavizado del scroll para un movimiento más fluido (lerp)
        smoothScroll += (scrollY - smoothScroll) * 0.12;
        const offsetY = -smoothScroll * PARALLAX;

        for (let i = 0; i < stars.length; i++) {
            const s = stars[i];

            // Posición base + deriva propia
            s.x += s.vx;
            s.y += s.vy;

            // Wrap horizontal para la deriva propia
            if (s.x < -2) s.x = W + 2;
            if (s.x > W + 2) s.x = -2;
            if (s.y < -2) s.y = H + 2;
            if (s.y > H + 2) s.y = -2;

            // Aplicamos el parallax y envolvemos en [0, H)
            let baseY = ((s.y + offsetY) % H + H) % H;

            const alpha = s.baseA * (0.6 + 0.4 * Math.sin(t * s.speed + s.phase));

            for (const dy of [baseY - H, baseY, baseY + H]) {
            if (dy < -10 || dy > H + 10) continue;

            // Halo sutil para estrellas grandes
            if (s.r > 1.0) {
                ctx.beginPath();
                ctx.arc(s.x, dy, s.r * 2.5, 0, Math.PI * 2);

                if(thema==="dark") ctx.fillStyle = `rgba(140, 180, 255, ${alpha * 0.15})`;
                else ctx.fillStyle = `rgba(0, 0, 0, ${alpha * 0.15})`;
                ctx.fillStyle = `rgba(140, 180, 255, ${alpha * 0.15})`;
                ctx.fill();
            }

            ctx.beginPath();
            ctx.arc(s.x, dy, s.r, 0, Math.PI * 2);
            if(thema==="dark") ctx.fillStyle = `rgba(255, 255, 255, ${alpha})`;
            else ctx.fillStyle = `rgba(0, 0, 0, ${alpha})`;
            ctx.fillStyle = `rgba(255, 255, 255, ${alpha})`;
            ctx.fill();
            }
        }

        t += 1;
        if (!reduceMotion) requestAnimationFrame(draw);
        }

        window.addEventListener('resize', resize);
        resize();

        if (reduceMotion) {
        // Un solo frame estático
        ctx.clearRect(0, 0, W, H);
        const offsetY = -scrollY * PARALLAX;
        for (const s of stars) {
            const baseY = ((s.y + offsetY) % H + H) % H;
            ctx.beginPath();
            ctx.arc(s.x, baseY, s.r, 0, Math.PI * 2);
            if(thema==="dark") ctx.fillStyle = `rgba(255,255,255,${s.baseA})`;
            else ctx.fillStyle = `rgba(0,0,0,${s.baseA})`;
            ctx.fill();
        }
        } else {
        draw();
        }
    })();