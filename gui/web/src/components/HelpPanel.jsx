/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import React from 'react';
import { useTranslation } from 'react-i18next';

function HelpPanel({ module }) {
  const { t } = useTranslation(['common', 'help']);
  
  if (!module) {
    return (
      <div className="help-panel">
        <div className="panel-header">{t('app.moduleHelp')}</div>
        <p>{t('help.selectModulePrompt')}</p>
      </div>
    );
  }

  // Get translated help content for the module
  const getModuleHelp = (moduleId) => {
    try {
      // Check if help content exists for this module
      const overviewKey = `help:${moduleId}.overview`;
      const optionsKey = `help:${moduleId}.options`;
      const notesKey = `help:${moduleId}.notes`;
      
      // Use exists check with returnObjects: false to avoid errors
      const helpExists = t(overviewKey, { defaultValue: null, returnObjects: false });
      
      if (!helpExists || helpExists === overviewKey) {
        console.warn(`[HelpPanel] No help content found for module: ${moduleId}`);
        return {
          overview: t('help.noHelpAvailable', { defaultValue: 'Help information not available for this module.' }),
          options: [],
          notes: []
        };
      }

      // Safely get options and notes with fallbacks
      let options = [];
      let notes = [];
      
      try {
        const optionsResult = t(optionsKey, { defaultValue: [], returnObjects: true });
        options = Array.isArray(optionsResult) ? optionsResult : [];
      } catch (error) {
        console.warn(`[HelpPanel] Failed to load options for module ${moduleId}:`, error);
        options = [];
      }
      
      try {
        const notesResult = t(notesKey, { defaultValue: [], returnObjects: true });
        notes = Array.isArray(notesResult) ? notesResult : [];
      } catch (error) {
        console.warn(`[HelpPanel] Failed to load notes for module ${moduleId}:`, error);
        notes = [];
      }

      return {
        overview: t(overviewKey, { defaultValue: `Help overview for ${moduleId}` }),
        options: options,
        notes: notes
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

  const help = getModuleHelp(module.id);

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

  return (
    <div className="help-panel">
      <div className="panel-header">{t('app.moduleHelp')}: {module.name}</div>
      
      <div style={{ marginBottom: '1rem' }}>
        <h4 style={{ margin: '0 0 0.5rem 0', color: '#5e97cfff' }}>{t('help.overview', { defaultValue: 'Overview' })}</h4>
        <p style={{ margin: 0, fontSize: '1.0rem', lineHeight: '1.4' }}>
          {help.overview}
        </p>
      </div>

      {help.options && help.options.length > 0 && (
        <div style={{ marginBottom: '1rem' }}>
          <h4 style={{ margin: '0 0 0.5rem 0', color: '#5e97cfff' }}>{t('help.availableOptions', { defaultValue: 'Available Options' })}</h4>
          <ul style={{ margin: 0, paddingLeft: '1.2rem', fontSize: '0.9rem' }}>
            {help.options.map((option, index) => (
              <li key={index} style={{ marginBottom: '0.3rem' }}>
                {typeof option === 'string' ? option : `[Invalid option format: ${JSON.stringify(option)}]`}
              </li>
            ))}
          </ul>
        </div>
      )}

      {help.notes && help.notes.length > 0 && (
        <div>
          <h4 style={{ margin: '0 0 0.5rem 0', color: '#5e97cfff' }}>{t('help.importantNotes', { defaultValue: 'Important Notes' })}</h4>
          <ul style={{ margin: 0, paddingLeft: '1.2rem', fontSize: '0.9rem' }}>
            {help.notes.map((note, index) => (
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
    </div>
  );
}

export default HelpPanel;
