/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import { useTranslation } from 'react-i18next';

function ConfigFileList({ files, selectedFile, onFileSelect }) {
  const { t } = useTranslation('common');

  const formatLastModified = (dateString) => {
    if (!dateString) return t('config.never');
    const date = new Date(dateString);
    return date.toLocaleString();
  };

  return (
    <div className="config-file-list">
      <h3>{t('config.configFiles')}</h3>
      <div className="file-list">
        {files.map((file) => (
          <div
            key={file.filename}
            className={`file-item ${selectedFile === file.filename ? 'selected' : ''}`}
            onClick={() => onFileSelect(file.filename)}
          >
            <div className="file-info">
              <div className="file-name">{file.display_name}</div>
              <div className="file-details">
                <span className="filename">{file.filename}</span>
                {file.has_example && (
                  <span className="has-example" title={t('config.hasExample')}>
                    📋
                  </span>
                )}
              </div>
              <div className="last-modified">
                {t('config.lastModified')}: {formatLastModified(file.last_modified)}
              </div>
            </div>
          </div>
        ))}
      </div>
      
      <div className="file-list-footer">
        <p className="help-text">{t('config.selectFileHelp')}</p>
      </div>
    </div>
  );
}

export default ConfigFileList;
