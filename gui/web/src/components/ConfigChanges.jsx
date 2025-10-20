/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import { useEffect, useState, useMemo, useCallback } from 'react';
import { useTranslation } from 'react-i18next';
import { apiFetch } from '../utils/api.js';

function ConfigChanges({
  selectedForm,
  onResetField,
  onReset,
  onSave,
  dirty = false,
  saving = false,
  success = '',
  error = '',
}) {
  const { t } = useTranslation('common');
  const [changes, setChanges] = useState([]);
  const [loading, setLoading] = useState(true);
  const [fetchError, setFetchError] = useState('');

  const fetchChanges = useCallback(async () => {
    try {
      setLoading(true);
      setFetchError('');
      const response = await apiFetch('/api/config/changes');
      if (!response.ok) {
        throw new Error(`Request failed with status ${response.status}`);
      }
      const data = await response.json();
      setChanges(Array.isArray(data) ? data : []);
    } catch (err) {
      console.error('Failed to fetch configuration changes:', err);
      setFetchError(t('config.errorLoadingChanges'));
    } finally {
      setLoading(false);
    }
  }, [t]);

  useEffect(() => {
    fetchChanges();
  }, [fetchChanges]);

  useEffect(() => {
    if (success) {
      fetchChanges();
    }
  }, [success, fetchChanges]);

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

  if (fetchError) {
    return (
      <div className="config-changes error">
        <div className="error-message">
          <span className="error-icon">⚠️</span>
          {fetchError}
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

      {(error || success || typeof onSave === 'function') && (
        <div className="config-changes-controls">
          {error && (
            <div className="error-message">
              <span className="error-icon">⚠️</span>
              {error}
            </div>
          )}
          {success && (
            <div className="success-message">
              <span className="success-icon">✅</span>
              {success}
            </div>
          )}
          {typeof onSave === 'function' && typeof onReset === 'function' && (
            <div className="config-options-actions">
              <button
                className="reset-button"
                onClick={onReset}
                disabled={!dirty && !error}
              >
                {t('config.reset')}
              </button>
              <button
                className="save-button"
                onClick={onSave}
                disabled={!dirty || saving}
              >
                {saving ? t('common.saving') : t('common.save')}
              </button>
            </div>
          )}
        </div>
      )}

      <div className="config-changes-list">
        {changes.map((entry) => (
          <div className="config-change-card" key={entry.filename}>
            <div className="config-change-header">
              <div className="config-change-title">
                <h4>{entry.display_key ? t(entry.display_key) : entry.display_name}</h4>
                <code>{entry.filename}</code>
              </div>
              <span className="change-count">
                {t('config.changeCount', { count: entry.changes.length })}
              </span>
            </div>

            <div className="config-change-table">
              <div
                className={`change-table-header${
                  entry.filename === selectedForm && typeof onResetField === 'function'
                    ? ' has-actions'
                    : ''
                }`}
              >
                <span>{t('config.key')}</span>
                <span>{t('config.defaultValue')}</span>
                <span>{t('config.currentValue')}</span>
                {entry.filename === selectedForm && typeof onResetField === 'function' && (
                  <span>{t('config.actions')}</span>
                )}
              </div>
              {entry.changes.map((change) => (
                <div
                  className={`change-table-row${
                    entry.filename === selectedForm && typeof onResetField === 'function'
                      ? ' has-actions'
                      : ''
                  }`}
                  key={change.key}
                >
                  <span className="change-key">{change.key}</span>
                  <span className="change-default">
                    {formatValue(change.default, t)}
                  </span>
                  <span className="change-current">
                    {formatValue(change.current, t)}
                  </span>
                  {entry.filename === selectedForm && typeof onResetField === 'function' && (
                    <span className="change-actions">
                      <button
                        type="button"
                        className="reset-field-button"
                        onClick={() =>
                          onResetField(
                            change.key,
                            resolveDefaultValue(change.default)
                          )
                        }
                      >
                        {t('config.resetDefault')}
                      </button>
                    </span>
                  )}
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

function resolveDefaultValue(value) {
  if (value === undefined || value === null) {
    return '';
  }
  return String(value);
}

export default ConfigChanges;
