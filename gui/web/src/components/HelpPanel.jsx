/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: Apache-2.0

This project is part of the 'little-linux-helper' collection.
Licensed under the Apache License 2.0. See the LICENSE file in the project root for more information.
*/

import React, { useCallback, useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';

function HelpPanel({ module, modules }) {
  const { t, i18n } = useTranslation(['common', 'modules', 'help']);
  const [helpSource, setHelpSource] = useState('automatic');

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
    if (!modules || modules.length === 0) {
      return [];
    }

    // Get modules that:
    // 1. Are enabled
    // 2. Are exposed to GUI
    // 3. Have help metadata defined in registry
    return modules
      .filter(mod => {
        // Check if module is enabled (defaults to true if not specified)
        const isEnabled = mod.enabled !== false;
        // Check if module is exposed to GUI (defaults to true if not specified)
        const isExposedToGui = !mod.expose || mod.expose.gui !== false;
        // Check if module has help metadata
        const hasHelp = mod.help && mod.help.overview_key;
        
        return isEnabled && isExposedToGui && hasHelp;
      })
      .map(mod => ({ 
        id: mod.id, 
        label: mod.name || formatHelpLabel(mod.id)
      }))
      .sort((a, b) => a.label.localeCompare(b.label, undefined, { sensitivity: 'base' }));
  }, [modules, formatHelpLabel]);

  const isAutomatic = helpSource === 'automatic';
  const activeHelpId = isAutomatic ? module?.id : helpSource;

  const getModuleHelp = (moduleId) => {
    try {
      // Find module in registry to get help keys
      const registryModule = modules?.find(m => m.id === moduleId);
      
      if (!registryModule || !registryModule.help) {
        console.warn(`[HelpPanel] No help metadata in registry for module: ${moduleId}`);
        return {
          overview: t('help.noHelpAvailable', { defaultValue: 'Help information not available for this module.' }),
          options: [],
          notes: []
        };
      }

      const { overview_key, options_key, notes_key } = registryModule.help;

      // Translation keys are at the root level in modules namespace (not nested under modules.)
      const overview = t(overview_key, { 
        ns: 'modules',
        defaultValue: `Help overview for ${moduleId}` 
      });

      let options = [];
      let notes = [];

      if (options_key) {
        try {
          const optionsResult = t(options_key, { 
            ns: 'modules',
            defaultValue: [], 
            returnObjects: true 
          });
          options = Array.isArray(optionsResult) ? optionsResult : [];
        } catch (error) {
          console.warn(`[HelpPanel] Failed to load options for module ${moduleId}:`, error);
        }
      }

      if (notes_key) {
        try {
          const notesResult = t(notes_key, { 
            ns: 'modules',
            defaultValue: [], 
            returnObjects: true 
          });
          notes = Array.isArray(notesResult) ? notesResult : [];
        } catch (error) {
          console.warn(`[HelpPanel] Failed to load notes for module ${moduleId}:`, error);
        }
      }

      return {
        overview,
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
