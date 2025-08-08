/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import React, { useState, useEffect, useRef } from 'react';
import ModuleList from './components/ModuleList';
import Terminal from './components/Terminal';
import HelpPanel from './components/HelpPanel';
import DocsPanel from './components/DocsPanel';
import ResizablePanels from './components/ResizablePanels';

function App() {
  const [modules, setModules] = useState([]);
  const [selectedModule, setSelectedModule] = useState(null);
  const [currentSession, setCurrentSession] = useState(null);
  const [sessionStatus, setSessionStatus] = useState('stopped');
  const [moduleDocs, setModuleDocs] = useState('');
  const [panelWidths, setPanelWidths] = useState({ terminal: 50, help: 25, docs: 25 });
  const wsRef = useRef(null);

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

  const startModule = async (module) => {
    console.log('Starting module:', module.id);
    try {
      setSelectedModule(module);
      console.log('Selected module set to:', module);
      
      const response = await fetch(`/api/modules/${module.id}/start`, {
        method: 'POST',
      });
      
      if (response.ok) {
        const data = await response.json();
        console.log('Module started, session data:', data);
        setCurrentSession(data.sessionId);
        setSessionStatus('running');
        console.log('Session status set to running, currentSession:', data.sessionId);
        
        // Connect WebSocket for real-time output
        connectWebSocket(data.sessionId);
      } else {
        console.error('Failed to start module');
      }
    } catch (error) {
      console.error('Error starting module:', error);
    }
  };

  const stopModule = async () => {
    if (currentSession) {
      try {
        await fetch(`/api/sessions/${currentSession}`, {
          method: 'DELETE',
        });
        
        setCurrentSession(null);
        setSessionStatus('stopped');
        
        // Close WebSocket connection
        if (wsRef.current) {
          wsRef.current.close();
        }
      } catch (error) {
        console.error('Error stopping module:', error);
      }
    }
  };

  const sendInput = async (input) => {
    console.log('App sendInput called with:', input, 'currentSession:', currentSession);
    if (currentSession) {
      try {
        const response = await fetch(`/api/sessions/${currentSession}/input`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ data: input }),
        });
        console.log('Input sent, response status:', response.status);
        if (!response.ok) {
          console.error('Failed to send input, response:', await response.text());
        }
      } catch (error) {
        console.error('Error sending input:', error);
      }
    } else {
      console.log('No current session to send input to');
    }
  };

  const connectWebSocket = (sessionId) => {
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//${window.location.host}/ws`;
    
    wsRef.current = new WebSocket(wsUrl);
    
    wsRef.current.onopen = () => {
      // Subscribe to session output
      wsRef.current.send(JSON.stringify({
        type: 'subscribe',
        content: sessionId,
      }));
    };
    
    wsRef.current.onmessage = (event) => {
      const message = JSON.parse(event.data);
      
      if (message.type === 'output') {
        // This will be handled by the Terminal component
        window.dispatchEvent(new CustomEvent('terminal-output', {
          detail: message.content
        }));
      } else if (message.type === 'session_ended') {
        setSessionStatus('stopped');
        setCurrentSession(null);
      }
    };
    
    wsRef.current.onerror = (error) => {
      console.error('WebSocket error:', error);
    };
    
    wsRef.current.onclose = () => {
      console.log('WebSocket connection closed');
    };
  };

  // Group modules by category
  const groupedModules = modules.reduce((acc, module) => {
    if (!acc[module.category]) {
      acc[module.category] = [];
    }
    acc[module.category].push(module);
    return acc;
  }, {});

  return (
    <div className="app">
      <header className="header">
        <h1>Little Linux Helper</h1>
      </header>
      
      <div className="main-content">
        <div className="sidebar">
          <ModuleList 
            groupedModules={groupedModules}
            selectedModule={selectedModule}
            onModuleSelect={startModule}
            sessionStatus={sessionStatus}
          />
        </div>
        
        <div className="content-area">
          <div className="session-controls">
            {selectedModule && (
              <>
                <span>Current Module: <strong>{selectedModule.name}</strong></span>
                <span className={`status-indicator ${sessionStatus}`}>
                  {sessionStatus === 'running' ? 'Running' : 'Stopped'}
                </span>
                {sessionStatus === 'running' && (
                  <button 
                    className="danger"
                    onClick={stopModule}
                  >
                    Stop Module
                  </button>
                )}
              </>
            )}
            {!selectedModule && (
              <span>Select a module from the sidebar to get started</span>
            )}
          </div>
          
          <ResizablePanels 
            panelWidths={panelWidths}
            onPanelWidthChange={setPanelWidths}
          >
            <Terminal 
              key="main-terminal"
              sessionId={currentSession}
              onSendInput={sendInput}
              isActive={sessionStatus === 'running'}
            />
            
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

export default App;
