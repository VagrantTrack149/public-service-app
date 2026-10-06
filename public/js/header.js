(function () {
  let initialized = false;

  async function fillAuth() {
    const desktop = document.getElementById('auth-area');
    const mobile  = document.getElementById('auth-area-mobile');
    if (!desktop && !mobile) return;

    const renderLoggedOut = () => {
      const html = `
        <a href="/login" class="btn btn-outline text-sm">Iniciar sesión</a>
        <a href="/register" class="btn btn-primary text-sm">Registrarse</a>`;
      if (desktop) desktop.innerHTML = html;
      if (mobile)  mobile.innerHTML = html;
    };

    try {
      const res = await fetch('/api/me', { credentials: 'same-origin' });
      if (!res.ok) return renderLoggedOut();
      const u = await res.json();
      const avatar = u.avatar_url
        ? `<img src="${u.avatar_url}" class="w-8 h-8 rounded-full object-cover" alt="">`
        : `<div class="w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold"
                style="background-color: rgb(var(--c-primary)); color:#fff;">
             ${(u.nombre || 'U')[0].toUpperCase()}
           </div>`;
        console.log(avatar)
      const html = `
        <div class="flex items-center gap-2">
          ${avatar}
          <span class="text-sm font-medium max-w-[10rem] truncate">${u.nombre || 'Usuario'}</span>
          <a href="/logout" class="btn btn-outline text-sm">Salir</a>
        </div>`;
      if (desktop) desktop.innerHTML = html;
      if (mobile)  mobile.innerHTML = html;
    } catch {
      renderLoggedOut();
    }
  }

  function initHeader() {
    if (initialized) return;
    const btn = document.getElementById('theme-toggle');
    if (!btn) return;
    initialized = true;

    btn.addEventListener('click', () => {
      const isDark = document.documentElement.classList.toggle('dark');
      localStorage.setItem('theme', isDark ? 'dark' : 'light');
    });

    const mb = document.getElementById('menu-btn');
    const mm = document.getElementById('mobile-menu');
    mb?.addEventListener('click', () => mm?.classList.toggle('hidden'));

    fillAuth();
  }

  window.addEventListener('header:loaded', initHeader);
  document.addEventListener('DOMContentLoaded', initHeader);
})();