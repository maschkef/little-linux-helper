/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import { createContext, useContext, useState, useEffect, useRef, useCallback } from 'react';

const SessionContext = createContext();

export const useSession = () => {
  const context = useContext(SessionContext);
  if (!context) {
    throw new Error('useSession must be used within a SessionProvider');
  }
  return context;
};

export const SessionProvider = ({ children }) => {
  const [sessions, setSessions] = useState(new Map());
  const [activeSessionId, setActiveSessionId] = useState(null);
  const wsConnections = useRef(new Map());

  const fetchSessions = useCallback(async () => {
    try {
      const response = await fetch('/api/sessions');
      if (response.ok) {
        const sessionList = await response.json();
        
        setSessions(prevSessions => {
          const sessionMap = new Map();
          
          sessionList.forEach(session => {
            sessionMap.set(session.id, {
              ...session,
              output: prevSessions.get(session.id)?.output || [], // Preserve existing output
              wsConnected: prevSessions.get(session.id)?.wsConnected || false
            });
          });
          
          return sessionMap;
        });
        
        // If active session no longer exists, clear it
        setActiveSessionId(prevActiveId => {
          if (prevActiveId && !sessionList.some(session => session.id === prevActiveId)) {
            return null;
          }
          return prevActiveId;
        });
      }
    } catch (error) {
      console.error('Failed to fetch sessions:', error);
    }
  }, []);

  // Fetch active sessions on component mount
  useEffect(() => {
    fetchSessions();
    
    // Optionally fetch sessions periodically to sync with backend
    const interval = setInterval(fetchSessions, 5000);
    return () => clearInterval(interval);
  }, [fetchSessions]);

  const startNewSession = async (module) => {
    try {
      const response = await fetch(`/api/modules/${module.id}/start`, {
        method: 'POST',
      });
      
      if (response.ok) {
        const data = await response.json();
        const newSession = {
          id: data.sessionId,
          module: module.id,
          module_name: module.name,
          created_at: new Date().toISOString(),
          status: 'running',
          output: [],
          wsConnected: false
        };
        
        setSessions(prev => new Map(prev.set(data.sessionId, newSession)));
        setActiveSessionId(data.sessionId);
        
        // Connect WebSocket for this session
        connectWebSocket(data.sessionId);
        
        return data.sessionId;
      } else {
        throw new Error('Failed to start session');
      }
    } catch (error) {
      console.error('Error starting session:', error);
      throw error;
    }
  };

  const stopSession = async (sessionId) => {
    try {
      await fetch(`/api/sessions/${sessionId}`, {
        method: 'DELETE',
      });
      
      // Close WebSocket connection
      const ws = wsConnections.current.get(sessionId);
      if (ws) {
        ws.close();
        wsConnections.current.delete(sessionId);
      }
      
      // Update session status
      setSessions(prev => {
        const newSessions = new Map(prev);
        const session = newSessions.get(sessionId);
        if (session) {
          newSessions.set(sessionId, { ...session, status: 'stopped' });
        }
        return newSessions;
      });
      
      // If this was the active session, find another one or clear it
      if (activeSessionId === sessionId) {
        const remainingSessions = Array.from(sessions.keys()).filter(id => id !== sessionId);
        setActiveSessionId(remainingSessions.length > 0 ? remainingSessions[0] : null);
      }
      
    } catch (error) {
      console.error('Error stopping session:', error);
      throw error;
    }
  };

  const switchToSession = (sessionId) => {
    if (sessions.has(sessionId)) {
      setActiveSessionId(sessionId);
      
      // Connect WebSocket if not already connected
      const session = sessions.get(sessionId);
      if (!session.wsConnected) {
        connectWebSocket(sessionId);
      }
    }
  };

  const sendInput = async (sessionId, input) => {
    try {
      const response = await fetch(`/api/sessions/${sessionId}/input`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ data: input }),
      });
      
      if (!response.ok) {
        throw new Error('Failed to send input');
      }
    } catch (error) {
      console.error('Error sending input:', error);
      throw error;
    }
  };

  const connectWebSocket = (sessionId) => {
    // Don't create multiple connections for the same session
    if (wsConnections.current.has(sessionId)) {
      return;
    }

    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//${window.location.host}/ws`;
    
    const ws = new WebSocket(wsUrl);
    wsConnections.current.set(sessionId, ws);
    
    ws.onopen = () => {
      ws.send(JSON.stringify({
        type: 'subscribe',
        content: sessionId,
      }));
      
      // Mark session as connected
      setSessions(prev => {
        const newSessions = new Map(prev);
        const session = newSessions.get(sessionId);
        if (session) {
          newSessions.set(sessionId, { ...session, wsConnected: true });
        }
        return newSessions;
      });
    };
    
    ws.onmessage = (event) => {
      const message = JSON.parse(event.data);
      
      if (message.type === 'output') {
        // Add output to session
        setSessions(prev => {
          const newSessions = new Map(prev);
          const session = newSessions.get(sessionId);
          if (session) {
            const newOutput = [...session.output, message.content];
            newSessions.set(sessionId, { ...session, output: newOutput });
          }
          return newSessions;
        });
        
        // Dispatch event for Terminal component (backward compatibility)
        if (sessionId === activeSessionId) {
          window.dispatchEvent(new CustomEvent('terminal-output', {
            detail: message.content
          }));
        }
      } else if (message.type === 'session_ended') {
        setSessions(prev => {
          const newSessions = new Map(prev);
          const session = newSessions.get(sessionId);
          if (session) {
            newSessions.set(sessionId, { ...session, status: 'stopped' });
          }
          return newSessions;
        });
      }
    };
    
    ws.onerror = (error) => {
      console.error('WebSocket error for session', sessionId, ':', error);
    };
    
    ws.onclose = () => {
      wsConnections.current.delete(sessionId);
      
      // Mark session as disconnected
      setSessions(prev => {
        const newSessions = new Map(prev);
        const session = newSessions.get(sessionId);
        if (session) {
          newSessions.set(sessionId, { ...session, wsConnected: false });
        }
        return newSessions;
      });
    };
  };

  const canCloseSession = (sessionId) => {
    // Can't close the last remaining session
    return sessions.size > 1;
  };

  const getActiveSession = () => {
    return activeSessionId ? sessions.get(activeSessionId) : null;
  };

  const getSessionOutput = (sessionId) => {
    return sessions.get(sessionId)?.output || [];
  };

  const value = {
    sessions,
    activeSessionId,
    startNewSession,
    stopSession,
    switchToSession,
    sendInput,
    canCloseSession,
    getActiveSession,
    getSessionOutput,
    fetchSessions
  };

  return (
    <SessionContext.Provider value={value}>
      {children}
    </SessionContext.Provider>
  );
};