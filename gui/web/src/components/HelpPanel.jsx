/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import React, { useCallback, useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';

function HelpPanel({ module }) {
  const { t, i18n } = useTranslation(['common', 'help']);
  const [helpSource, setHelpSource] = useState('automatic');

  const helpBundle = useMemo(() => {
    const activeBundle = i18n.getResourceBundle(i18n.language, 'help');
    if (activeBundle) {
      return activeBundle;
    }

    const fallbackLng = i18n.options?.fallbackLng;
    const fallbackList = Array.isArray(fallbackLng)
      ? fallbackLng
      : fallbackLng
        ? [fallbackLng]
        : [];

    for (const fallback of fallbackList) {
      const bundle = i18n.getResourceBundle(fallback, 'help');
      if (bundle) {
        return bundle;
      }
    }

    return {};
  }, [i18n, i18n.language]);

  const formatHelpLabel = useCallback((helpId) => {
    if (!helpId) {
      return '';
    }

    const translatedName = t(`modules.names.${helpId}`, {
      ns: 'common',
      defaultValue: ''
    });

    if (translatedName) {
      return translatedName;
    }

    return helpId
      .split('_')
      .map((segment) => segment.charAt(0).toUpperCase() + segment.slice(1))
      .join(' ');
  }, [t]);

  const availableHelpOptions = useMemo(() => {
    if (!helpBundle || typeof helpBundle !== 'object') {
      return [];
    }

    return Object.entries(helpBundle)
      .filter(([, value]) => value && typeof value === 'object' && !Array.isArray(value))
      .map(([id]) => ({ id, label: formatHelpLabel(id) || id }))
      .sort((a, b) => a.label.localeCompare(b.label, undefined, { sensitivity: 'base' }));
  }, [helpBundle, formatHelpLabel]);

  const isAutomatic = helpSource === 'automatic';
  const activeHelpId = isAutomatic ? module?.id : helpSource;

  const getModuleHelp = (moduleId) => {
    try {
      const overviewKey = `help:${moduleId}.overview`;
      const optionsKey = `help:${moduleId}.options`;
      const notesKey = `help:${moduleId}.notes`;

      const helpExists = t(overviewKey, { defaultValue: null, returnObjects: false });

      if (!helpExists || helpExists === overviewKey) {
        console.warn(`[HelpPanel] No help content found for module: ${moduleId}`);
        return {
          overview: t('help.noHelpAvailable', { defaultValue: 'Help information not available for this module.' }),
          options: [],
          notes: []
        };
      }

      let options = [];
      let notes = [];

      try {
        const optionsResult = t(optionsKey, { defaultValue: [], returnObjects: true });
        options = Array.isArray(optionsResult) ? optionsResult : [];
      } catch (error) {
        console.warn(`[HelpPanel] Failed to load options for module ${moduleId}:`, error);
      }

      try {
        const notesResult = t(notesKey, { defaultValue: [], returnObjects: true });
        notes = Array.isArray(notesResult) ? notesResult : [];
      } catch (error) {
        console.warn(`[HelpPanel] Failed to load notes for module ${moduleId}:`, error);
      }

      return {
        overview: t(overviewKey, { defaultValue: `Help overview for ${moduleId}` }),
        options,
        notes
      };
    } catch (error) {
      console.error(`[HelpPanel] Error loading help for module ${moduleId}:`, error);
      return {
        overview: `Error loading help for ${moduleId}. Please check the console for details.`,
        options: [],
        notes: []
      };
    }
  };

  const activeHelp = activeHelpId ? getModuleHelp(activeHelpId) : null;
  const selectedManualOption = !isAutomatic && helpSource
    ? availableHelpOptions.find((option) => option.id === helpSource)
    : null;
  const manualLabel = !isAutomatic ? (selectedManualOption?.label || formatHelpLabel(helpSource)) : '';

  const handleHelpSourceChange = (event) => {
    setHelpSource(event.target.value);
  };

  const renderNoteContent = (note, index) => {
    if (typeof note !== 'string') {
      return <span>{`[Invalid note format: ${JSON.stringify(note)}]`}</span>;
    }

    if (!note.includes('```')) {
      return <span style={{ whiteSpace: 'pre-wrap' }}>{note}</span>;
    }

    const segments = note.split('```');

    return (
      <>
        {segments.map((segment, segIndex) => {
          const key = `${index}-seg-${segIndex}`;
          const isCodeBlock = segIndex % 2 === 1;

          if (isCodeBlock) {
            const codeContent = segment.replace(/^\n+/, '').replace(/\n+$/, '');
            return (
              <pre
                key={key}
                style={{
                  backgroundColor: '#1e1e1e22',
                  borderRadius: '4px',
                  padding: '0.5rem',
                  margin: '0.35rem 0',
                  whiteSpace: 'pre',
                  overflowX: 'auto',
                  fontSize: '0.85rem',
                  fontFamily: '"Fira Code", "Source Code Pro", monospace'
                }}
              >
                {codeContent}
              </pre>
            );
          }

          if (segment.trim().length === 0) {
            return null;
          }

          return (
            <span key={key} style={{ whiteSpace: 'pre-wrap' }}>
              {segment}
            </span>
          );
        })}
      </>
    );
  };

  const renderHelpContent = () => {
    if (!activeHelp) {
      return <p>{t('help.noHelpAvailable')}</p>;
    }

    return (
      <>
        <div style={{ marginBottom: '1rem' }}>
          <h4 style={{ margin: '0 0 0.5rem 0', color: '#5e97cfff' }}>
            {t('help.overview', { defaultValue: 'Overview' })}
          </h4>
          <p style={{ margin: 0, fontSize: '1.0rem', lineHeight: '1.4' }}>
            {activeHelp.overview}
          </p>
        </div>

        {activeHelp.options && activeHelp.options.length > 0 && (
          <div style={{ marginBottom: '1rem' }}>
            <h4 style={{ margin: '0 0 0.5rem 0', color: '#5e97cfff' }}>
              {t('help.availableOptions', { defaultValue: 'Available Options' })}
            </h4>
            <ul style={{ margin: 0, paddingLeft: '1.2rem', fontSize: '0.9rem' }}>
              {activeHelp.options.map((option, index) => (
                <li key={index} style={{ marginBottom: '0.3rem' }}>
                  {typeof option === 'string'
                    ? option
                    : `[Invalid option format: ${JSON.stringify(option)}]`}
                </li>
              ))}
            </ul>
          </div>
        )}

        {activeHelp.notes && activeHelp.notes.length > 0 && (
          <div>
            <h4 style={{ margin: '0 0 0.5rem 0', color: '#5e97cfff' }}>
              {t('help.importantNotes', { defaultValue: 'Important Notes' })}
            </h4>
            <ul style={{ margin: 0, paddingLeft: '1.2rem', fontSize: '0.9rem' }}>
              {activeHelp.notes.map((note, index) => (
                <li
                  key={index}
                  style={{
                    marginBottom: '0.45rem',
                    color: '#bb9900ff',
                    whiteSpace: 'pre-wrap'
                  }}
                >
                  {renderNoteContent(note, index)}
                </li>
              ))}
            </ul>
          </div>
        )}
      </>
    );
  };

  const shouldShowModulePrompt = isAutomatic && !module;

  return (
    <div className="help-panel">
      <div className="panel-header">
        {t('app.moduleHelp')}
        {isAutomatic && module ? `: ${module.name}` : ''}
        {!isAutomatic && manualLabel ? `: ${manualLabel}` : ''}
      </div>

      <div style={{ marginBottom: '0.85rem' }}>
        <label
          htmlFor="help-source-select"
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            fontSize: '0.75rem',
            letterSpacing: '0.3px',
            color: '#bbbbbb'
          }}
        >
          <span>{t('help.helpSourceLabel')}</span>
          {!isAutomatic && (
            <span style={{ color: '#8ec07c' }}>{t('help.manualSelectionIndicator')}</span>
          )}
        </label>
        <select
          id="help-source-select"
          value={helpSource}
          onChange={handleHelpSourceChange}
          style={{
            width: '100%',
            marginTop: '0.35rem',
            padding: '0.35rem 0.4rem',
            borderRadius: '4px',
            border: '1px solid #3a5068',
            backgroundColor: '#1f2a38',
            color: '#f0f0f0',
            fontSize: '0.85rem'
          }}
        >
          <option value="automatic">{t('help.automaticOption')}</option>
          {availableHelpOptions.map((option) => (
            <option key={option.id} value={option.id}>
              {option.label}
            </option>
          ))}
        </select>
      </div>

      {shouldShowModulePrompt ? <p>{t('help.selectModulePrompt')}</p> : renderHelpContent()}
    </div>
  );
}

export default HelpPanel;
