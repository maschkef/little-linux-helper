/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { getCookie } from '../utils/api.js';

const Login = () => {
  const { t } = useTranslation();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (event) => {
    event.preventDefault();
    if (submitting) {
      return;
    }

    setError('');
    setSubmitting(true);

    try {
      const response = await fetch('/api/login', {
        method: 'POST',
        credentials: 'same-origin',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': getCookie('csrf_') || '',
        },
        body: JSON.stringify({
          user: username,
          pass: password,
        }),
      });

      if (response.status === 204) {
        window.location.replace('/');
        return;
      }

      switch (response.status) {
        case 401:
          setError(t('auth.invalidCredentials'));
          break;
        case 429:
          setError(t('auth.rateLimited'));
          break;
        default:
          setError(t('auth.unknownError'));
      }
    } catch (err) {
      console.error('Login request failed', err);
      setError(t('auth.networkError'));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="login-page">
      <div className="login-card">
        <h1 className="login-title">{t('auth.title')}</h1>
        <p className="login-subtitle">{t('auth.subtitle')}</p>

        <form onSubmit={handleSubmit} className="login-form">
          <label className="login-label">
            {t('auth.username')}
            <input
              type="text"
              autoComplete="username"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              disabled={submitting}
              required
            />
          </label>

          <label className="login-label">
            {t('auth.password')}
            <input
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              disabled={submitting}
              required
            />
          </label>

          {error && <div className="login-error">{error}</div>}

          <button type="submit" className="login-button" disabled={submitting}>
            {submitting ? t('auth.signingIn') : t('auth.submit')}
          </button>
        </form>

        <p className="login-footer">{t('auth.footer')}</p>
      </div>
    </div>
  );
};

export default Login;
