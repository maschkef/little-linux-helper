/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import React, { useState, useEffect } from 'react';
import ModuleList from './components/ModuleList';
import Terminal from './components/Terminal';
import HelpPanel from './components/HelpPanel';
import DocsPanel from './components/DocsPanel';
import ResizablePanels from './components/ResizablePanels';
import SessionDropdown from './components/SessionDropdown';
import { SessionProvider, useSession } from './contexts/SessionContext';

function AppContent() {
  const [modules, setModules] = useState([]);
  const [selectedModule, setSelectedModule] = useState(null);
  const [moduleDocs, setModuleDocs] = useState('');
  const [panelWidths, setPanelWidths] = useState({ terminal: 50, help: 25, docs: 25 });
  const [showHelpPanel, setShowHelpPanel] = useState(true);
  const [showDocsPanel, setShowDocsPanel] = useState(false);
  
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
    try {
      const response = await fetch(`/api/modules/${moduleId}/docs`);
      if (response.ok) {
        const data = await response.json();
        setModuleDocs(data.content);
      } else {
        setModuleDocs('Documentation not available for this module.');
      }
    } catch (error) {
      console.error('Failed to fetch module docs:', error);
      setModuleDocs('Error loading documentation.');
    }
  };

  const handleModuleSelect = (module) => {
    setSelectedModule(module);
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
    <div className="app">
      <header className="header">
        <div className="header-content">
          <h1>Little Linux Helper</h1>
          <img src="/header-logo.svg" alt="Little Linux Helper" className="header-logo" />
        </div>
      </header>
      
      <div className="main-content">
        <div className="sidebar">
          <ModuleList 
            groupedModules={groupedModules}
            selectedModule={selectedModule}
            onModuleSelect={handleModuleSelect}
            onModuleStart={startModule}
          />
        </div>
        
        <div className="content-area">
          <div className="session-controls">
            <div className="session-info-section">
              {selectedModule && (
                <span>Current Module: <strong>{selectedModule.name}</strong></span>
              )}
              {!selectedModule && (
                <span>Select a module from the sidebar to get started</span>
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
                    alert('Please select a module first');
                  }
                }}
                disabled={!selectedModule}
                title="Start new session"
              >
                + New Session
              </button>
            </div>
            
            {/* Panel toggle buttons */}
            <div className="panel-toggles">
              <button 
                className={showHelpPanel ? 'active' : ''}
                onClick={() => setShowHelpPanel(!showHelpPanel)}
              >
                {showHelpPanel ? 'Hide Help' : 'Show Help'}
              </button>
              <button 
                className={showDocsPanel ? 'active' : ''}
                onClick={() => setShowDocsPanel(!showDocsPanel)}
              >
                {showDocsPanel ? 'Hide Docs' : 'Show Docs'}
              </button>
            </div>
          </div>
          
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
            
            <DocsPanel 
              content={moduleDocs}
            />
          </ResizablePanels>
        </div>
      </div>
    </div>
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
