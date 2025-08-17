/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import ModuleList from './components/ModuleList.jsx';
import Terminal from './components/Terminal.jsx';
import HelpPanel from './components/HelpPanel.jsx';
import DocsPanel from './components/DocsPanel.jsx';
import DocumentBrowser from './components/DocumentBrowser.jsx';
import ResizablePanels from './components/ResizablePanels.jsx';
import SessionDropdown from './components/SessionDropdown.jsx';
import LanguageSelector from './components/LanguageSelector.jsx';
import ErrorBoundary from './components/ErrorBoundary.jsx';
import { SessionProvider, useSession } from './contexts/SessionContext.jsx';
import './i18n'; // Initialize i18n

function AppContent() {
  const { t } = useTranslation('common');
  const [modules, setModules] = useState([]);
  const [selectedModule, setSelectedModule] = useState(null);
  const [moduleDocs, setModuleDocs] = useState('');
  const [panelWidths, setPanelWidths] = useState({ terminal: 50, help: 25, docs: 25 });
  const [showHelpPanel, setShowHelpPanel] = useState(true);
  const [showDocsPanel, setShowDocsPanel] = useState(false);
  const [docBrowserMode, setDocBrowserMode] = useState(false);
  const [showSidebar, setShowSidebar] = useState(true);
  const [showTerminalPanels, setShowTerminalPanels] = useState(true);
  
  const { startNewSession, sessions } = useSession();

  useEffect(() => {
    // Load modules on component mount
    fetchModules();
  }, []);

  useEffect(() => {
    // Load documentation when module is selected
    if (selectedModule) {
      fetchModuleDocs(selectedModule.id);
    }
  }, [selectedModule]);

  const fetchModules = async () => {
    try {
      const response = await fetch('/api/modules');
      const data = await response.json();
      setModules(data);
    } catch (error) {
      console.error('Failed to fetch modules:', error);
    }
  };

  const fetchModuleDocs = async (moduleId) => {
    console.log('fetchModuleDocs called with moduleId:', moduleId);
    try {
      console.log('Making API call to:', `/api/modules/${moduleId}/docs`);
      const response = await fetch(`/api/modules/${moduleId}/docs`);
      console.log('API response status:', response.status, response.ok);
      if (response.ok) {
        const data = await response.json();
        console.log('API response data type:', typeof data, 'content length:', data.content?.length);
        setModuleDocs(data.content);
        console.log('Successfully set module docs');
      } else {
        console.log('API response not OK, setting not available message');
        setModuleDocs(t('docs.notAvailable'));
      }
    } catch (error) {
      console.error('Failed to fetch module docs:', error);
      setModuleDocs(t('docs.errorLoading'));
    }
  };

  const handleModuleSelect = (module) => {
    console.log('handleModuleSelect called with module:', module);
    try {
      console.log('Setting selected module:', module.id, module.name);
      setSelectedModule(module);
      console.log('Successfully set selected module');
    } catch (error) {
      console.error('Error selecting module:', error);
    }
  };

  const startModule = async (module) => {
    try {
      await startNewSession(module);
    } catch (error) {
      console.error('Error starting module:', error);
    }
  };

  // Group modules by category
  const groupedModules = modules.reduce((acc, module) => {
    if (!acc[module.category]) {
      acc[module.category] = [];
    }
    acc[module.category].push(module);
    return acc;
  }, {});

  // const activeSession = getActiveSession(); // Currently unused but kept for future use

  return (
    <ErrorBoundary>
    <div className="app">
      <header className="header">
        <div className="header-content">
          <div style={{ flex: 1 }}></div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
            <h1>{t('app.title')}</h1>
            <img src="/header-logo.svg" alt="Little Linux Helper" className="header-logo" />
          </div>
          <div style={{ flex: 1, display: 'flex', justifyContent: 'flex-end' }}>
            <LanguageSelector />
          </div>
        </div>
      </header>
      
      <div className="main-content" style={{ display: 'flex' }}>
        {showSidebar && (
          <div className="sidebar">
            <ModuleList 
              groupedModules={groupedModules}
              selectedModule={selectedModule}
              onModuleSelect={handleModuleSelect}
              onModuleStart={startModule}
            />
          </div>
        )}
        
        <div className="content-area" style={{ flex: 1 }}>
          <div className="session-controls">
            <div className="session-info-section">
              {selectedModule && (
                <span>{t('session.currentModule')} <strong>{t(`modules.names.${selectedModule.id}`, { defaultValue: selectedModule.name })}</strong></span>
              )}
              {!selectedModule && (
                <span>{t('session.selectModule')}</span>
              )}
            </div>
            
            <div className="session-management">
              {sessions.size > 0 && (
                <SessionDropdown />
              )}
              
              {/* New Session button */}
              <button 
                className="new-session-btn"
                onClick={() => {
                  if (selectedModule) {
                    startModule(selectedModule);
                  } else {
                    alert(t('session.selectModuleFirst'));
                  }
                }}
                disabled={!selectedModule}
                title={t('session.startNewSessionTooltip')}
              >
{t('session.newSession')}
              </button>
            </div>
            
            {/* Panel toggle buttons */}
            <div className="panel-toggles">
              <button 
                className={showSidebar ? 'active' : ''}
                onClick={() => setShowSidebar(!showSidebar)}
                style={{ marginRight: '8px' }}
              >
{showSidebar ? t('panels.hideModules') : t('panels.showModules')}
              </button>
              <button 
                className={showTerminalPanels ? 'active' : ''}
                onClick={() => setShowTerminalPanels(!showTerminalPanels)}
                style={{ marginRight: '8px' }}
              >
{showTerminalPanels ? t('panels.hideTerminal') : t('panels.showTerminal')}
              </button>
              <button 
                className={showHelpPanel ? 'active' : ''}
                onClick={() => setShowHelpPanel(!showHelpPanel)}
              >
{showHelpPanel ? t('panels.hideHelp') : t('panels.showHelp')}
              </button>
              <button 
                className={showDocsPanel ? 'active' : ''}
                onClick={() => setShowDocsPanel(!showDocsPanel)}
              >
{showDocsPanel ? t('panels.hideDocs') : t('panels.showDocs')}
              </button>
              {showDocsPanel && (
                <div className="doc-mode-toggle" style={{
                  display: 'flex',
                  alignItems: 'center',
                  marginLeft: '10px',
                  fontSize: '12px',
                  color: '#ecf0f1'
                }}>
                  <span style={{ marginRight: '8px' }}>{t('panels.docBrowser')}</span>
                  <label className="toggle-switch" style={{
                    position: 'relative',
                    display: 'inline-block',
                    width: '40px',
                    height: '20px'
                  }}>
                    <input
                      type="checkbox"
                      checked={docBrowserMode}
                      onChange={(e) => setDocBrowserMode(e.target.checked)}
                      style={{ opacity: 0, width: 0, height: 0 }}
                    />
                    <span style={{
                      position: 'absolute',
                      cursor: 'pointer',
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      backgroundColor: docBrowserMode ? '#007bff' : '#ccc',
                      borderRadius: '20px',
                      transition: 'background-color 0.2s',
                      '&:before': {
                        content: '""',
                        position: 'absolute',
                        height: '16px',
                        width: '16px',
                        left: docBrowserMode ? '22px' : '2px',
                        bottom: '2px',
                        backgroundColor: 'white',
                        borderRadius: '50%',
                        transition: 'left 0.2s'
                      }
                    }} className="slider">
                      <span style={{
                        content: '""',
                        position: 'absolute',
                        height: '16px',
                        width: '16px',
                        left: docBrowserMode ? '22px' : '2px',
                        bottom: '2px',
                        backgroundColor: 'white',
                        borderRadius: '50%',
                        transition: 'left 0.2s'
                      }}></span>
                    </span>
                  </label>
                </div>
              )}
            </div>
          </div>
          
          {showTerminalPanels ? (
            <ResizablePanels 
              panelWidths={panelWidths}
              onPanelWidthChange={setPanelWidths}
              showHelpPanel={showHelpPanel}
              showDocsPanel={showDocsPanel}
            >
              <Terminal key="main-terminal" />
              
              <HelpPanel 
                module={selectedModule}
              />
              
              {docBrowserMode ? (
                <DocumentBrowser />
              ) : (
                <DocsPanel 
                  content={moduleDocs}
                  selectedModule={selectedModule}
                  onModuleSelect={handleModuleSelect}
                />
              )}
            </ResizablePanels>
          ) : (
            // Full-width documentation view when terminal panels are hidden
            showDocsPanel && (
              <div style={{ 
                height: 'calc(100vh - 160px)', 
                padding: '10px',
                backgroundColor: '#2c3e50',
                borderRadius: '5px'
              }}>
                {docBrowserMode ? (
                  <DocumentBrowser />
                ) : (
                  <DocsPanel 
                    content={moduleDocs}
                    selectedModule={selectedModule}
                    onModuleSelect={handleModuleSelect}
                  />
                )}
              </div>
            )
          )}
        </div>
      </div>
    </div>
    </ErrorBoundary>
  );
}

// Main App component with SessionProvider
function App() {
  return (
    <SessionProvider>
      <AppContent />
    </SessionProvider>
  );
}

export default App;
