/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import { useState, useEffect, Suspense, lazy } from 'react';
import { useTranslation } from 'react-i18next';
import ModuleList from './components/ModuleList.jsx';
import Terminal from './components/Terminal.jsx';
import HelpPanel from './components/HelpPanel.jsx';
import ResizablePanels from './components/ResizablePanels.jsx';
import SessionDropdown from './components/SessionDropdown.jsx';
import LanguageSelector from './components/LanguageSelector.jsx';
import ExitButton from './components/ExitButton.jsx';
import LogoutButton from './components/LogoutButton.jsx';
import ErrorBoundary from './components/ErrorBoundary.jsx';
import { SessionProvider, useSession } from './contexts/SessionContext.jsx';
import { apiFetch } from './utils/api.js';
import './i18n'; // Initialize i18n

// Lazy load heavy components that are only used conditionally
const DocsPanel = lazy(() => import('./components/DocsPanel.jsx'));
const DocumentBrowser = lazy(() => import('./components/DocumentBrowser.jsx'));
const ConfigPanel = lazy(() => import('./components/ConfigPanel.jsx'));

function AppContent({ standaloneSessionId, isStandalone }) {
  const { t } = useTranslation('common');
  const [modules, setModules] = useState([]);
  const [selectedModule, setSelectedModule] = useState(null);
  const [moduleDocs, setModuleDocs] = useState('');
  const [panelWidths, setPanelWidths] = useState({ terminal: 50, help: 25, docs: 25 });
  const [showHelpPanel, setShowHelpPanel] = useState(true);
  const [showDocsPanel, setShowDocsPanel] = useState(false);
  const [showConfigPanel, setShowConfigPanel] = useState(false);
  const [docBrowserMode, setDocBrowserMode] = useState(false);
  const [showSidebar, setShowSidebar] = useState(true);
  const [showTerminalPanels, setShowTerminalPanels] = useState(true);
  const [lastDocumentationSource, setLastDocumentationSource] = useState('module'); // 'module' or 'session'
  const [showDevControls, setShowDevControls] = useState(() => {
    // Load from localStorage, default to false (hidden)
    const saved = localStorage.getItem('lh-gui-dev-controls');
    return saved === 'true';
  });
  const [toolVersion, setToolVersion] = useState('');
  const [authMode, setAuthMode] = useState('session');
  
  const { startNewSession, sessions, getActiveSession, activeSessionId, switchToSession } = useSession();

  // Track when active session changes (user switched sessions)
  useEffect(() => {
    if (activeSessionId) {
      setLastDocumentationSource('session');
    }
  }, [activeSessionId]);

  useEffect(() => {
    fetchModules();
  }, []);

  useEffect(() => {
    const fetchVersion = async () => {
      try {
        const response = await apiFetch('/api/version');
        if (response.ok) {
          const data = await response.json();
          if (data.release) {
            setToolVersion(data.release);
          }
          if (Object.prototype.hasOwnProperty.call(data, 'auth_mode')) {
            setAuthMode(data.auth_mode || 'session');
          } else {
            setAuthMode('session');
          }
        }
      } catch (error) {
        console.error('Failed to fetch release version:', error);
      }
    };

    fetchVersion();
  }, []);

  useEffect(() => {
    // Load documentation based on last user action
    const activeSession = getActiveSession();
    let moduleToShowDocs = null;
    
    if (lastDocumentationSource === 'session' && activeSession) {
      // User last interacted with session - show active session's module
      moduleToShowDocs = modules.find(m => m.id === activeSession.module);
    } else if (lastDocumentationSource === 'module' && selectedModule) {
      // User last clicked on a module - show selected module
      moduleToShowDocs = selectedModule;
    } else if (selectedModule) {
      // Fallback to selected module
      moduleToShowDocs = selectedModule;
    } else if (activeSession) {
      // Fallback to active session if no module selected
      moduleToShowDocs = modules.find(m => m.id === activeSession.module);
    }
    
    if (moduleToShowDocs) {
      fetchModuleDocs(moduleToShowDocs.id);
    }
  }, [selectedModule, sessions, getActiveSession, modules, lastDocumentationSource]);

  const fetchModules = async () => {
    try {
      const response = await apiFetch('/api/modules');
      if (response.ok) {
        const data = await response.json();
        setModules(data);
      } else if (response.status !== 401) {
        console.error('Failed to fetch modules:', response.status);
      }
    } catch (error) {
      console.error('Failed to fetch modules:', error);
    }
  };

  const fetchModuleDocs = async (moduleId) => {
    try {
      const response = await apiFetch(`/api/modules/${moduleId}/docs`);
      if (response.ok) {
        const data = await response.json();
        setModuleDocs(data.content);
      } else if (response.status !== 401) {
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
      setLastDocumentationSource('module'); // User clicked on module
      console.log('Successfully set selected module');
    } catch (error) {
      console.error('Error selecting module:', error);
    }
  };

  const startModule = async (module) => {
    try {
      await startNewSession(module);
      setLastDocumentationSource('session'); // User started a new session
    } catch (error) {
      console.error('Error starting module:', error);
    }
  };

  const handleOpenTTYTab = () => {
    if (!activeSessionId) {
      return;
    }

    const url = `/?ttySession=${encodeURIComponent(activeSessionId)}&standalone=1`;
    const newTab = window.open(url, '_blank', 'noopener,noreferrer');
    if (!newTab) {
      alert(t('terminal.popupBlocked'));
    }
  };

  useEffect(() => {
    if (!isStandalone || !standaloneSessionId) {
      return;
    }

    if (activeSessionId !== standaloneSessionId && sessions.has(standaloneSessionId)) {
      switchToSession(standaloneSessionId);
    }
  }, [isStandalone, standaloneSessionId, activeSessionId, sessions, switchToSession]);

  if (isStandalone) {
    return (
      <StandaloneTerminalView sessionId={standaloneSessionId} />
    );
  }

  const toggleDevControls = (newValue) => {
    setShowDevControls(newValue);
    localStorage.setItem('lh-gui-dev-controls', newValue.toString());
    
    // If disabling dev controls, also close any open documentation panels
    if (!newValue) {
      setShowDocsPanel(false);
      setDocBrowserMode(false);
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
          <div style={{ flex: 1, display: 'flex', alignItems: 'center' }}>
            {/* Developer Controls Toggle - moved to top left */}
            <div style={{ 
              display: 'flex', 
              alignItems: 'center', 
              gap: '6px',
              opacity: '0.7',
              fontSize: '12px'
            }}>
              <input
                type="checkbox"
                id="dev-controls-toggle"
                checked={showDevControls}
                onChange={(e) => toggleDevControls(e.target.checked)}
                style={{
                  cursor: 'pointer',
                  transform: 'scale(0.9)'
                }}
              />
              <label 
                htmlFor="dev-controls-toggle" 
                style={{ 
                  cursor: 'pointer', 
                  color: '#bbb',
                  userSelect: 'none',
                  fontSize: '11px'
                }}
                title={t('dev.toggleTooltip')}
              >
                🔧 {t('dev.toggle')}
              </label>
            </div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
            <h1>{t('app.title')}</h1>
            <img src="/header-logo.svg" alt="Little Linux Helper" className="header-logo" />
            {toolVersion && (
              <span className="version-badge" title="Release version">
                {toolVersion}
              </span>
            )}
          </div>
          <div style={{ flex: 1, display: 'flex', justifyContent: 'flex-end', alignItems: 'center', gap: '12px' }}>
            <LanguageSelector />
            {authMode !== 'none' && <LogoutButton />}
            <ExitButton />
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

              <button
                className="open-tty-btn primary"
                onClick={handleOpenTTYTab}
                disabled={!activeSessionId}
                title={activeSessionId ? t('terminal.openInNewTabTooltip') : t('terminal.openInNewTabDisabledTooltip')}
              >
                ↗ {t('terminal.openInNewTab')}
              </button>
            </div>
            
            {/* Panel toggle buttons */}
            <div className="panel-toggles">
              {/* Documentation Controls Group - only show when dev controls enabled */}
              {showDevControls && (
                <>
                  <div style={{ 
                    display: 'flex', 
                    alignItems: 'center',
                    gap: '8px',
                    marginRight: '15px',
                    padding: '2px 8px',
                    backgroundColor: 'rgba(255, 255, 255, 0.05)',
                    borderRadius: '6px',
                    border: '1px solid rgba(255, 255, 255, 0.1)'
                  }}>
                    <span style={{ 
                      fontSize: '11px', 
                      color: '#aaa', 
                      textTransform: 'uppercase',
                      letterSpacing: '0.5px',
                      marginRight: '4px'
                    }}>
                      Docs:
                    </span>
                    
                    <button 
                      className={showDocsPanel ? 'active' : ''}
                      onClick={() => setShowDocsPanel(!showDocsPanel)}
                      title={t('panels.developerDocsTooltip')}
                      style={{ 
                        padding: '4px 10px',
                        fontSize: '12px',
                        backgroundColor: showDocsPanel ? '#007acc' : '#4a4a4a',
                        color: 'white',
                        border: '1px solid ' + (showDocsPanel ? '#007acc' : '#666'),
                        borderRadius: '4px',
                        cursor: 'pointer',
                        transition: 'all 0.2s',
                        position: 'relative'
                      }}
                    >
                      {showDocsPanel ? t('panels.hideDeveloperDocs') : t('panels.showDeveloperDocs')}
                      {/* Show which module's docs are loaded */}
                      {(selectedModule || getActiveSession()) && (
                        <span style={{
                          position: 'absolute',
                          top: '-2px',
                          right: '-2px',
                          width: '6px',
                          height: '6px',
                          backgroundColor: lastDocumentationSource === 'session' ? '#4caf50' : '#80ccff',
                          borderRadius: '50%',
                          fontSize: '8px'
                        }} title={`Showing docs for ${
                          lastDocumentationSource === 'session' && getActiveSession() 
                            ? getActiveSession().module 
                            : selectedModule?.id || 'none'
                        }`}></span>
                      )}
                    </button>
                    
                    <button 
                      className={docBrowserMode ? 'active' : ''}
                      onClick={() => setDocBrowserMode(!docBrowserMode)}
                      title={t('panels.comprehensiveDocsTooltip')}
                      style={{ 
                        padding: '4px 10px',
                        fontSize: '12px',
                        backgroundColor: docBrowserMode ? '#007acc' : '#4a4a4a',
                        color: 'white',
                        border: '1px solid ' + (docBrowserMode ? '#007acc' : '#666'),
                        borderRadius: '4px',
                        cursor: 'pointer',
                        transition: 'all 0.2s'
                      }}
                    >
                      {t('panels.comprehensiveDocumentation')}
                    </button>
                  </div>
                </>
              )}
              
              {/* Layout Controls Group */}
              <div style={{ 
                display: 'flex', 
                alignItems: 'center',
                gap: '8px',
                marginRight: '15px'
              }}>
                <span style={{ 
                  fontSize: '11px', 
                  color: '#aaa', 
                  textTransform: 'uppercase',
                  letterSpacing: '0.5px',
                  marginRight: '4px'
                }}>
                  Layout:
                </span>
              
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
              
              {/* Help button only shown when terminal panels are visible */}
              {showTerminalPanels && (
                <button 
                  className={showHelpPanel ? 'active' : ''}
                  onClick={() => setShowHelpPanel(!showHelpPanel)}
                  style={{ marginRight: '8px' }}
                >
                  {showHelpPanel ? t('panels.hideHelp') : t('panels.showHelp')}
                </button>
              )}
              </div>
              
              {/* Configuration Panel Button */}
              <button 
                className={showConfigPanel ? 'active' : ''}
                onClick={() => setShowConfigPanel(!showConfigPanel)}
                style={{ 
                  padding: '4px 12px',
                  fontSize: '12px',
                  backgroundColor: showConfigPanel ? '#007acc' : '#4a4a4a',
                  color: 'white',
                  border: '1px solid ' + (showConfigPanel ? '#007acc' : '#666'),
                  borderRadius: '4px',
                  cursor: 'pointer',
                  transition: 'all 0.2s'
                }}
              >
                ⚙️ {showConfigPanel ? t('panels.hideConfig') : t('panels.showConfig')}
              </button>
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
              
              <Suspense fallback={<div className="loading-panel">Loading documentation...</div>}>
                <DocsPanel 
                  content={moduleDocs}
                  selectedModule={selectedModule}
                  onModuleSelect={handleModuleSelect}
                />
              </Suspense>
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
                <Suspense fallback={<div className="loading-panel">Loading documentation...</div>}>
                  <DocsPanel 
                    content={moduleDocs}
                    selectedModule={selectedModule}
                    onModuleSelect={handleModuleSelect}
                  />
                </Suspense>
              </div>
            )
          )}
        </div>
      </div>

      {/* Configuration Panel Overlay */}
      {showConfigPanel && (
        <div className="config-panel-overlay">
          <div className="config-panel-modal">
            <div className="config-panel-header">
              <h2>{t('config.title')}</h2>
              <button 
                className="close-config-button"
                onClick={() => setShowConfigPanel(false)}
                title={t('common.close')}
              >
                ×
              </button>
            </div>
            <Suspense fallback={<div className="loading-panel">Loading configuration...</div>}>
              <ConfigPanel
                devMode={showDevControls}
                onToggleDevMode={toggleDevControls}
              />
            </Suspense>
          </div>
        </div>
      )}

      {/* Document Browser Overlay */}
      {docBrowserMode && (
        <div className="doc-browser-overlay">
          <div className="doc-browser-modal">
            <div className="doc-browser-header">
              <h2>{t('panels.comprehensiveDocumentation')}</h2>
              <button 
                className="close-doc-browser-button"
                onClick={() => setDocBrowserMode(false)}
                title={t('common.close')}
              >
                ×
              </button>
            </div>
            <Suspense fallback={<div className="loading-panel">Loading document browser...</div>}>
              <DocumentBrowser />
            </Suspense>
          </div>
        </div>
      )}
    </div>
    </ErrorBoundary>
  );
}

// Main App component with SessionProvider
function StandaloneTerminalView({ sessionId }) {
  const { t } = useTranslation('common');
  const { sessions, activeSessionId, switchToSession } = useSession();

  useEffect(() => {
    if (!sessionId) {
      return;
    }

    if (activeSessionId !== sessionId && sessions.has(sessionId)) {
      switchToSession(sessionId);
    }
  }, [sessionId, activeSessionId, sessions, switchToSession]);

  const session = sessionId ? sessions.get(sessionId) : null;

  useEffect(() => {
    if (!sessionId || !session) {
      return undefined;
    }

    const originalTitle = document.title;
    const label = session.module_name || session.module || sessionId;
    document.title = `${label} – Little Linux Helper`;
    return () => {
      document.title = originalTitle;
    };
  }, [sessionId, session?.module_name, session?.module]);

  if (!sessionId) {
    return (
      <div className="standalone-terminal__empty">{t('session.selectModule')}</div>
    );
  }

  if (!sessions.has(sessionId)) {
    return (
      <div className="standalone-terminal__empty">{t('general.loading')}</div>
    );
  }

  const moduleLabel = session?.module_name || session?.module || t('session.activeModule');

  return (
    <div className="standalone-terminal">
      <header className="standalone-terminal__header">
        <div className="standalone-terminal__meta">
          <span className="standalone-terminal__module">{moduleLabel}</span>
          <code className="standalone-terminal__id">{sessionId}</code>
        </div>
        <a href="/" className="standalone-terminal__link">{t('common.close')}</a>
      </header>
      <div className="standalone-terminal__body">
        <Terminal />
      </div>
    </div>
  );
}

function App() {
  const urlParams = new URLSearchParams(window.location.search);
  const standaloneSessionId = urlParams.get('ttySession');
  const standaloneParam = urlParams.get('standalone');
  const isStandalone = standaloneParam === '1' || standaloneParam === 'true';

  return (
    <SessionProvider initialSessionId={standaloneSessionId}>
      <AppContent standaloneSessionId={standaloneSessionId} isStandalone={isStandalone} />
    </SessionProvider>
  );
}

export default App;
