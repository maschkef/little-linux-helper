/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import ConfigFileEditor from './ConfigFileEditor.jsx';
import ConfigFileList from './ConfigFileList.jsx';
import ConfigBackupManager from './ConfigBackupManager.jsx';
import { apiFetch } from '../utils/api.js';

function ConfigPanel() {
  const { t } = useTranslation('common');
  const [configFiles, setConfigFiles] = useState([]);
  const [selectedFile, setSelectedFile] = useState(null);
  const [activeTab, setActiveTab] = useState('editor'); // editor, backups
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    fetchConfigFiles();
  }, []);

  const fetchConfigFiles = async () => {
    try {
      setLoading(true);
      const response = await apiFetch('/api/config/files');
      if (response.ok) {
        const data = await response.json();
        setConfigFiles(data);
        if (data.length > 0 && !selectedFile) {
          setSelectedFile(data[0].filename);
        }
      } else {
        setError(t('config.errorLoadingFiles'));
      }
    } catch (err) {
      setError(t('config.errorLoadingFiles'));
      console.error('Failed to fetch config files:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleFileSelect = (filename) => {
    setSelectedFile(filename);
    setActiveTab('editor');
  };

  const handleFileSaved = () => {
    // Refresh file list to update last modified times
    fetchConfigFiles();
  };

  if (loading) {
    return (
      <div className="config-panel loading">
        <div className="loading-text">{t('common.loading')}</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="config-panel error">
        <div className="error-text">{error}</div>
        <button onClick={fetchConfigFiles} className="retry-button">
          {t('common.retry')}
        </button>
      </div>
    );
  }

  return (
    <div className="config-panel">
      <div className="config-panel-header">
        <h2>{t('config.title')}</h2>
        <div className="config-tabs">
          <button
            className={`tab-button ${activeTab === 'editor' ? 'active' : ''}`}
            onClick={() => setActiveTab('editor')}
          >
            {t('config.editor')}
          </button>
          <button
            className={`tab-button ${activeTab === 'backups' ? 'active' : ''}`}
            onClick={() => setActiveTab('backups')}
          >
            {t('config.backups')}
          </button>
        </div>
      </div>

      <div className="config-panel-content">
        {activeTab === 'editor' && (
          <div className="config-editor-container">
            <div className="config-sidebar">
              <ConfigFileList
                files={configFiles}
                selectedFile={selectedFile}
                onFileSelect={handleFileSelect}
              />
            </div>
            <div className="config-editor">
              {selectedFile && (
                <ConfigFileEditor
                  filename={selectedFile}
                  onFileSaved={handleFileSaved}
                />
              )}
            </div>
          </div>
        )}

        {activeTab === 'backups' && (
          <ConfigBackupManager onBackupDeleted={fetchConfigFiles} />
        )}
      </div>
    </div>
  );
}

export default ConfigPanel;
