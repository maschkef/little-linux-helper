/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import { useEffect, useState, useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import { apiFetch } from '../utils/api.js';

function ConfigChanges() {
  const { t } = useTranslation('common');
  const [changes, setChanges] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const fetchChanges = async () => {
      try {
        setLoading(true);
        setError('');
        const response = await apiFetch('/api/config/changes');
        if (!response.ok) {
          throw new Error(`Request failed with status ${response.status}`);
        }
        const data = await response.json();
        setChanges(Array.isArray(data) ? data : []);
      } catch (err) {
        console.error('Failed to fetch configuration changes:', err);
        setError(t('config.errorLoadingChanges'));
      } finally {
        setLoading(false);
      }
    };

    fetchChanges();
  }, [t]);

  const totalChanges = useMemo(
    () => changes.reduce((acc, entry) => acc + (entry.changes?.length || 0), 0),
    [changes]
  );

  if (loading) {
    return (
      <div className="config-changes loading">
        <div className="loading-text">{t('config.loadingChanges')}</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="config-changes error">
        <div className="error-message">
          <span className="error-icon">⚠️</span>
          {error}
        </div>
      </div>
    );
  }

  if (!totalChanges) {
    return (
      <div className="config-changes empty">
        <h3>{t('config.noChanges')}</h3>
        <p>{t('config.noChangesHelp')}</p>
      </div>
    );
  }

  return (
    <div className="config-changes">
      <div className="config-changes-summary">
        <span className="summary-count">
          {t('config.changeCount', { count: totalChanges })}
        </span>
        <span className="summary-hint">{t('config.changeHint')}</span>
      </div>

      <div className="config-changes-list">
        {changes.map((entry) => (
          <div className="config-change-card" key={entry.filename}>
            <div className="config-change-header">
              <div className="config-change-title">
                <h4>{entry.display_name}</h4>
                <code>{entry.filename}</code>
              </div>
              <span className="change-count">
                {t('config.changeCount', { count: entry.changes.length })}
              </span>
            </div>

            <div className="config-change-table">
              <div className="change-table-header">
                <span>{t('config.key')}</span>
                <span>{t('config.defaultValue')}</span>
                <span>{t('config.currentValue')}</span>
              </div>
              {entry.changes.map((change) => (
                <div className="change-table-row" key={change.key}>
                  <span className="change-key">{change.key}</span>
                  <span className="change-default">
                    {formatValue(change.default, t)}
                  </span>
                  <span className="change-current">
                    {formatValue(change.current, t)}
                  </span>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function formatValue(value, t) {
  if (value === undefined || value === null) {
    return t('config.noValue');
  }
  const trimmed = String(value).trim();
  if (trimmed === '') {
    return t('config.blankValue');
  }
  return trimmed;
}

export default ConfigChanges;
