// Shared helpers for authenticated API requests

const SAFE_METHODS = new Set(['GET', 'HEAD', 'OPTIONS']);

export function getCookie(name) {
  return document.cookie
    .split('; ')
    .find((row) => row.startsWith(`${name}=`))
    ?.split('=')[1] ?? '';
}

function redirectToLogin() {
  if (window.location.pathname !== '/login') {
    window.location.replace('/login');
  }
}

export async function apiFetch(input, init = {}) {
  const options = { credentials: 'same-origin', ...init };
  const headers = new Headers(options.headers || {});
  const method = (options.method || 'GET').toUpperCase();

  const csrfToken = getCookie('csrf_');
  if (csrfToken && !SAFE_METHODS.has(method)) {
    headers.set('X-CSRF-Token', csrfToken);
  }

  options.headers = headers;

  try {
    const response = await fetch(input, options);
    if (response.status === 401) {
      redirectToLogin();
    }
    return response;
  } catch (error) {
    // Bubble network errors to the caller for existing handling
    throw error;
  }
}

