/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';

function ConfigBackupManager({ onBackupDeleted }) {
  const { t } = useTranslation('common');
  const [backups, setBackups] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [deletingBackups, setDeletingBackups] = useState(new Set());

  useEffect(() => {
    fetchBackups();
  }, []);

  const fetchBackups = async () => {
    try {
      setLoading(true);
      setError('');
      const response = await fetch('/api/config/backups');
      if (response.ok) {
        const data = await response.json();
        // Sort backups by creation date, newest first
        const sortedBackups = data.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
        setBackups(sortedBackups);
      } else {
        setError(t('config.errorLoadingBackups'));
      }
    } catch (err) {
      setError(t('config.errorLoadingBackups'));
      console.error('Failed to fetch backups:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleDeleteBackup = async (backupId) => {
    if (!window.confirm(t('config.confirmDeleteBackup'))) {
      return;
    }

    try {
      setDeletingBackups(prev => new Set(prev).add(backupId));
      const response = await fetch(`/api/config/backups/${backupId}`, {
        method: 'DELETE',
      });
      
      if (response.ok) {
        setBackups(prev => prev.filter(backup => backup.id !== backupId));
        onBackupDeleted && onBackupDeleted();
      } else {
        const errorData = await response.json();
        alert(t('config.errorDeletingBackup') + ': ' + (errorData.error || 'Unknown error'));
      }
    } catch (err) {
      console.error('Failed to delete backup:', err);
      alert(t('config.errorDeletingBackup'));
    } finally {
      setDeletingBackups(prev => {
        const next = new Set(prev);
        next.delete(backupId);
        return next;
      });
    }
  };

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    return date.toLocaleString();
  };

  const formatFileSize = (filePath) => {
    // This would normally require a separate API call or file info
    // For now, we'll just show a placeholder
    return t('config.backupSize');
  };

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

  const groupBackupsByFile = (backups) => {
    const grouped = {};
    backups.forEach(backup => {
      if (!grouped[backup.filename]) {
        grouped[backup.filename] = [];
      }
      grouped[backup.filename].push(backup);
    });
    return grouped;
  };

  if (loading) {
    return (
      <div className="config-backup-manager loading">
        <div className="loading-text">{t('common.loading')}</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="config-backup-manager error">
        <div className="error-text">{error}</div>
        <button onClick={fetchBackups} className="retry-button">
          {t('common.retry')}
        </button>
      </div>
    );
  }

  const groupedBackups = groupBackupsByFile(backups);

  return (
    <div className="config-backup-manager">
      <div className="backup-manager-header">
        <h3>{t('config.backupManager')}</h3>
        <button onClick={fetchBackups} className="refresh-button">
          {t('common.refresh')}
        </button>
      </div>

      {backups.length === 0 ? (
        <div className="no-backups">
          <div className="no-backups-message">
            {t('config.noBackups')}
          </div>
        </div>
      ) : (
        <div className="backup-groups">
          {Object.entries(groupedBackups).map(([filename, fileBackups]) => (
            <div key={filename} className="backup-group">
              <div className="backup-group-header">
                <h4>{getFileDisplayName(filename)}</h4>
                <span className="backup-count">
                  {t('config.backupCount', { count: fileBackups.length })}
                </span>
              </div>
              
              <div className="backup-list">
                {fileBackups.map((backup) => (
                  <div key={backup.id} className="backup-item">
                    <div className="backup-info">
                      <div className="backup-file">
                        <code>{backup.backup_file}</code>
                      </div>
                      <div className="backup-details">
                        <span className="backup-date">
                          {t('config.created')}: {formatDate(backup.created_at)}
                        </span>
                      </div>
                    </div>
                    
                    <div className="backup-actions">
                      <button
                        onClick={() => handleDeleteBackup(backup.id)}
                        className="delete-backup-button"
                        disabled={deletingBackups.has(backup.id)}
                        title={t('config.deleteBackup')}
                      >
                        {deletingBackups.has(backup.id) ? t('common.deleting') : '🗑️'}
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      )}

      <div className="backup-manager-footer">
        <div className="backup-info">
          <p>{t('config.backupInfo')}</p>
          <p>{t('config.backupWarning')}</p>
        </div>
      </div>
    </div>
  );
}

export default ConfigBackupManager;
