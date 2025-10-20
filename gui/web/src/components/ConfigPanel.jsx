/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import { useState, useEffect, useMemo, useCallback } from 'react';
import { useTranslation } from 'react-i18next';
import ConfigFileEditor from './ConfigFileEditor.jsx';
import ConfigFileList from './ConfigFileList.jsx';
import ConfigOptionsMenu from './ConfigOptionsMenu.jsx';
import ConfigChanges from './ConfigChanges.jsx';
import { apiFetch } from '../utils/api.js';

function ConfigPanel({ devMode = false, onToggleDevMode }) {
  const { t } = useTranslation('common');

  const [activeTab, setActiveTab] = useState('options'); // options, editor, changes

  const [forms, setForms] = useState([]);
  const [formsLoading, setFormsLoading] = useState(true);
  const [formsError, setFormsError] = useState('');
  const [selectedForm, setSelectedForm] = useState(null);
  const [formDetailCache, setFormDetailCache] = useState({});
  const [currentFormDetail, setCurrentFormDetail] = useState(null);
  const [formValues, setFormValues] = useState({});
  const [formOriginalValues, setFormOriginalValues] = useState({});
  const [formDefaults, setFormDefaults] = useState({});
  const [formDirty, setFormDirty] = useState(false);
  const [formSaving, setFormSaving] = useState(false);
  const [formSuccess, setFormSuccess] = useState('');
  const [formError, setFormError] = useState('');
  const [formLoading, setFormLoading] = useState(false);

  const [configFiles, setConfigFiles] = useState([]);
  const [selectedFile, setSelectedFile] = useState(null);
  const [fileListLoading, setFileListLoading] = useState(false);
  const [fileListError, setFileListError] = useState('');
  const [filesFetched, setFilesFetched] = useState(false);

  const visibleForms = useMemo(
    () => forms.filter((form) => devMode || !form.advanced),
    [forms, devMode]
  );
  const advancedFormsHidden = useMemo(
    () => !devMode && forms.length > visibleForms.length,
    [forms, visibleForms, devMode]
  );

  const fetchConfigForms = useCallback(async () => {
    try {
      setFormsLoading(true);
      setFormsError('');
      const response = await apiFetch('/api/config/forms');
      if (!response.ok) {
        throw new Error(`Request failed with status ${response.status}`);
      }
      const data = await response.json();
      setForms(data);
    } catch (err) {
      console.error('Failed to fetch config forms:', err);
      setFormsError(t('config.errorLoadingForms'));
    } finally {
      setFormsLoading(false);
    }
  }, [t]);

  const fetchConfigFiles = useCallback(async () => {
    try {
      setFileListLoading(true);
      setFileListError('');
      const response = await apiFetch('/api/config/files');
      if (!response.ok) {
        throw new Error(`Request failed with status ${response.status}`);
      }
      const data = await response.json();
      setConfigFiles(data);
      if (data.length > 0 && !selectedFile) {
        setSelectedFile(data[0].filename);
      }
      setFilesFetched(true);
    } catch (err) {
      console.error('Failed to fetch config files:', err);
      setFileListError(t('config.errorLoadingFiles'));
    } finally {
      setFileListLoading(false);
    }
  }, [selectedFile, t]);

  const buildInitialValues = useCallback((detail) => {
    const base = { ...(detail?.values || {}) };
    detail?.groups?.forEach((group) => {
      group.fields.forEach((field) => {
        if (base[field.key] === undefined || base[field.key] === null) {
          if (field.default !== undefined) {
            base[field.key] = String(field.default);
          } else if (field.type === 'toggle') {
            base[field.key] = 'false';
          } else {
            base[field.key] = '';
          }
        } else {
          base[field.key] = String(base[field.key]);
        }
      });
    });
    return base;
  }, []);

  const applyDetail = useCallback(
    (detail, { resetMessages = true } = {}) => {
      if (!detail) {
        return;
      }
      const initialValues = buildInitialValues(detail);
      setCurrentFormDetail(detail);
      setFormOriginalValues(initialValues);
      setFormValues({ ...initialValues });
      setFormDefaults(detail.defaults || {});
      setFormDirty(false);
      if (resetMessages) {
        setFormSuccess('');
        setFormError('');
      }
    },
    [buildInitialValues]
  );

  const loadFormDetail = useCallback(
    async (filename) => {
      if (!filename) {
        return;
      }
      setFormLoading(true);
      setFormError('');
      setFormSuccess('');
      try {
        const response = await apiFetch(`/api/config/forms/${filename}`);
        if (!response.ok) {
          throw new Error(`Request failed with status ${response.status}`);
        }
        const data = await response.json();
        setFormDetailCache((prev) => ({ ...prev, [filename]: data }));
        if (filename === selectedForm) {
          applyDetail(data);
        }
      } catch (err) {
        console.error('Failed to fetch config form detail:', err);
        setFormError(t('config.errorLoadingForm'));
      } finally {
        setFormLoading(false);
      }
    },
    [applyDetail, selectedForm, t]
  );

  const hasChanges = useCallback((current, original) => {
    const keys = new Set([...Object.keys(original), ...Object.keys(current)]);
    for (const key of keys) {
      if (String(original[key] ?? '') !== String(current[key] ?? '')) {
        return true;
      }
    }
    return false;
  }, []);

  useEffect(() => {
    fetchConfigForms();
  }, [fetchConfigForms]);

  useEffect(() => {
    if (!devMode && activeTab === 'editor') {
      setActiveTab('options');
    }
  }, [devMode, activeTab]);

  useEffect(() => {
    if (devMode && !filesFetched && activeTab === 'editor') {
      fetchConfigFiles();
    }
  }, [devMode, filesFetched, activeTab, fetchConfigFiles]);

  useEffect(() => {
    if (forms.length === 0) {
      setSelectedForm(null);
      setCurrentFormDetail(null);
      return;
    }

    const candidateList = visibleForms;
    if (candidateList.length === 0) {
      setSelectedForm(null);
      setCurrentFormDetail(null);
      return;
    }

    if (!selectedForm || !candidateList.some((form) => form.filename === selectedForm)) {
      setSelectedForm(candidateList[0].filename);
    }
  }, [forms, visibleForms, selectedForm]);

  useEffect(() => {
    if (!selectedForm) {
      setCurrentFormDetail(null);
      return;
    }

    const cached = formDetailCache[selectedForm];
    if (cached) {
      applyDetail(cached);
      return;
    }

    loadFormDetail(selectedForm);
  }, [selectedForm, formDetailCache, applyDetail, loadFormDetail]);

  const handleFormSelect = (filename) => {
    if (filename === selectedForm) {
      return;
    }
    setSelectedForm(filename);
    setFormSuccess('');
    setFormError('');
  };

  const handleFormValueChange = (key, value) => {
    setFormValues((prev) => {
      const updated = { ...prev, [key]: value };
      setFormDirty(hasChanges(updated, formOriginalValues));
      return updated;
    });
    setFormSuccess('');
  };

  const handleFormReset = () => {
    setFormValues({ ...formOriginalValues });
    setFormDirty(false);
    setFormSuccess('');
    setFormError('');
  };

  const handleFormSave = async () => {
    if (!selectedForm || !currentFormDetail) {
      return;
    }

    setFormSaving(true);
    setFormError('');
    setFormSuccess('');

    try {
      const payloadValues = {};
      currentFormDetail.groups.forEach((group) => {
        group.fields.forEach((field) => {
          if (Object.prototype.hasOwnProperty.call(formValues, field.key)) {
            payloadValues[field.key] = formValues[field.key];
          }
        });
      });

      const response = await apiFetch(`/api/config/forms/${selectedForm}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ values: payloadValues }),
      });

      if (response.ok) {
        const data = await response.json();
        const detail = data.form || currentFormDetail;
        setFormDetailCache((prev) => ({ ...prev, [selectedForm]: detail }));
        applyDetail(detail, { resetMessages: false });
        setFormDirty(false);
        setFormSuccess(t('config.savedSuccess'));
        if (devMode && activeTab === 'editor') {
          fetchConfigFiles();
        }
      } else {
        let errorMessage = t('config.errorSaving');
        try {
          const errorData = await response.json();
          if (errorData?.error) {
            errorMessage = errorData.error;
          }
        } catch (parseErr) {
          // ignore
        }
        setFormError(errorMessage);
      }
    } catch (err) {
      console.error('Failed to save configuration form:', err);
      setFormError(t('config.errorSaving'));
    } finally {
      setFormSaving(false);
    }
  };

  const handleFileSelect = (filename) => {
    setSelectedFile(filename);
  };

  const handleFileSaved = () => {
    fetchConfigFiles();
  };

  const onTabChange = (tab) => {
    setActiveTab(tab);
    if (tab === 'editor' && devMode && !filesFetched) {
      fetchConfigFiles();
    }
  };

  return (
    <div className="config-panel">
      <div className="config-panel-header">
        <h2>{t('config.title')}</h2>
        <div className="config-header-controls">
          {typeof onToggleDevMode === 'function' && (
            <label className="config-dev-toggle">
              <input
                type="checkbox"
                checked={devMode}
                onChange={(e) => onToggleDevMode(e.target.checked)}
              />
              <span>{t('config.devModeToggle')}</span>
            </label>
          )}
        <div className="config-tabs">
          <button
            className={`tab-button ${activeTab === 'options' ? 'active' : ''}`}
            onClick={() => onTabChange('options')}
          >
            {t('config.options')}
          </button>

          {devMode && (
            <button
              className={`tab-button ${activeTab === 'editor' ? 'active' : ''}`}
              onClick={() => onTabChange('editor')}
            >
              {t('config.editor')}
            </button>
          )}

          <button
            className={`tab-button ${activeTab === 'changes' ? 'active' : ''}`}
            onClick={() => onTabChange('changes')}
          >
            {t('config.changes')}
          </button>
        </div>
        </div>
      </div>

      <div className="config-panel-content">
        {activeTab === 'options' && (
          <ConfigOptionsMenu
            forms={visibleForms}
            formsLoading={formsLoading}
            formsError={formsError}
            onReloadForms={fetchConfigForms}
            selectedForm={selectedForm}
            onSelectForm={handleFormSelect}
            detail={currentFormDetail}
            detailLoading={formLoading}
            values={formValues}
            onValueChange={handleFormValueChange}
            onReset={handleFormReset}
            onSave={handleFormSave}
            dirty={formDirty}
            saving={formSaving}
            success={formSuccess}
            error={formError}
            advancedHidden={advancedFormsHidden}
            devMode={devMode}
          />
        )}

        {activeTab === 'editor' && devMode && (
          <div className="config-editor-container">
            {fileListError && (
              <div className="error-message slim">
                <span className="error-icon">⚠️</span>
                {fileListError}
              </div>
            )}
            <div className="config-sidebar">
              {fileListLoading ? (
                <div className="loading-text">{t('common.loading')}</div>
              ) : (
                <ConfigFileList
                  files={configFiles}
                  selectedFile={selectedFile}
                  onFileSelect={handleFileSelect}
                />
              )}
            </div>
            <div className="config-editor">
              {selectedFile && (
                <ConfigFileEditor filename={selectedFile} onFileSaved={handleFileSaved} />
              )}
            </div>
          </div>
        )}

        {activeTab === 'changes' && (
          <ConfigChanges />
        )}
      </div>
    </div>
  );
}

export default ConfigPanel;
