/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { apiFetch } from '../utils/api.js';

const LogoutButton = () => {
  const { t } = useTranslation('auth');
  const [isLoggingOut, setIsLoggingOut] = useState(false);

  const handleLogout = async () => {
    if (isLoggingOut) {
      return;
    }

    setIsLoggingOut(true);
    try {
      await apiFetch('/api/logout', { method: 'POST' });
    } catch (error) {
      console.error('Failed to logout:', error);
    } finally {
      window.location.replace('/login');
    }
  };

  return (
    <button
      type="button"
      className="logout-button"
      onClick={handleLogout}
      disabled={isLoggingOut}
    >
      {t('logout')}
    </button>
  );
};

export default LogoutButton;

