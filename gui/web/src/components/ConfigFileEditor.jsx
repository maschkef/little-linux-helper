/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';

function ConfigFileEditor({ filename, onFileSaved }) {
  const { t } = useTranslation('common');
  const [content, setContent] = useState('');
  const [exampleContent, setExampleContent] = useState('');
  const [hasExample, setHasExample] = useState(false);
  const [showExample, setShowExample] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [isDirty, setIsDirty] = useState(false);
  const [createBackup, setCreateBackup] = useState(true);

  useEffect(() => {
    if (filename) {
      loadConfigFile();
    }
  }, [filename]);

  const loadConfigFile = async () => {
    try {
      setLoading(true);
      setError('');
      setSuccess('');
      setIsDirty(false);
      
      // Load main config file
      const response = await fetch(`/api/config/${filename}`);
      if (response.ok) {
        const data = await response.json();
        setContent(data.content);
        setHasExample(data.has_example);
        
        // Load example file if it exists
        if (data.has_example) {
          loadExampleFile();
        }
      } else {
        setError(t('config.errorLoadingFile'));
      }
    } catch (err) {
      setError(t('config.errorLoadingFile'));
      console.error('Failed to load config file:', err);
    } finally {
      setLoading(false);
    }
  };

  const loadExampleFile = async () => {
    try {
      const response = await fetch(`/api/config/${filename}/example`);
      if (response.ok) {
        const data = await response.json();
        setExampleContent(data.content);
      }
    } catch (err) {
      console.error('Failed to load example file:', err);
    }
  };

  const handleContentChange = (e) => {
    setContent(e.target.value);
    setIsDirty(true);
    setError('');
    setSuccess('');
  };

  const handleSave = async () => {
    try {
      setSaving(true);
      setError('');
      setSuccess('');
      
      const response = await fetch(`/api/config/${filename}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          content: content,
          create_backup: createBackup,
        }),
      });
      
      if (response.ok) {
        const result = await response.json();
        setSuccess(
          result.backup_created 
            ? t('config.savedWithBackup', { backup: result.backup_created })
            : t('config.savedSuccess')
        );
        setIsDirty(false);
        onFileSaved && onFileSaved();
      } else {
        const errorData = await response.json();
        setError(errorData.error || t('config.errorSaving'));
      }
    } catch (err) {
      setError(t('config.errorSaving'));
      console.error('Failed to save config file:', err);
    } finally {
      setSaving(false);
    }
  };

  const handleReset = () => {
    if (isDirty && !window.confirm(t('config.confirmReset'))) {
      return;
    }
    loadConfigFile();
  };

  const toggleExample = () => {
    setShowExample(!showExample);
  };

  if (loading) {
    return (
      <div className="config-file-editor loading">
        <div className="loading-text">{t('common.loading')}</div>
      </div>
    );
  }

  const getFileDisplayName = (filename) => {
    switch (filename) {
      case 'general.conf':
        return t('config.generalConfig');
      case 'backup.conf':
        return t('config.backupConfig');
      case 'docker.conf':
        return t('config.dockerConfig');
      default:
        return filename;
    }
  };

  return (
    <div className="config-file-editor">
      <div className="editor-header">
        <h3>{getFileDisplayName(filename)}</h3>
        <div className="editor-controls">
          {hasExample && (
            <button
              onClick={toggleExample}
              className={`example-toggle ${showExample ? 'active' : ''}`}
            >
              {showExample ? t('config.hideExample') : t('config.showExample')}
            </button>
          )}
          <label className="backup-checkbox">
            <input
              type="checkbox"
              checked={createBackup}
              onChange={(e) => setCreateBackup(e.target.checked)}
            />
            {t('config.createBackup')}
          </label>
        </div>
      </div>

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

      <div className={`editor-content ${showExample ? 'split-view' : 'single-view'}`}>
        <div className="config-editor-section">
          <div className="section-header">
            <h4>{t('config.currentConfig')}</h4>
            {isDirty && <span className="dirty-indicator">●</span>}
          </div>
          <textarea
            className="config-textarea"
            value={content}
            onChange={handleContentChange}
            placeholder={t('config.configPlaceholder')}
            spellCheck={false}
          />
        </div>

        {showExample && hasExample && (
          <div className="example-editor-section">
            <div className="section-header">
              <h4>{t('config.exampleConfig')}</h4>
              <span className="readonly-indicator">{t('config.readOnly')}</span>
            </div>
            <textarea
              className="config-textarea readonly"
              value={exampleContent}
              readOnly
              spellCheck={false}
            />
          </div>
        )}
      </div>

      <div className="editor-footer">
        <div className="editor-actions">
          <button
            onClick={handleReset}
            className="reset-button"
            disabled={!isDirty}
          >
            {t('config.reset')}
          </button>
          <button
            onClick={handleSave}
            className="save-button"
            disabled={!isDirty || saving}
          >
            {saving ? t('common.saving') : t('common.save')}
          </button>
        </div>
        
        <div className="editor-info">
          <span className="file-info">
            {t('config.editingFile')}: <code>{filename}</code>
          </span>
          {isDirty && (
            <span className="unsaved-changes">
              {t('config.unsavedChanges')}
            </span>
          )}
        </div>
      </div>
    </div>
  );
}

export default ConfigFileEditor;
