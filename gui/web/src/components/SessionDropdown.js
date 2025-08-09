/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import React, { useState, useRef, useEffect } from 'react';
import { useSession } from '../contexts/SessionContext';
import './SessionDropdown.css';

const SessionDropdown = () => {
  const {
    sessions,
    activeSessionId,
    switchToSession,
    stopSession,
    canCloseSession
  } = useSession();
  
  const [isOpen, setIsOpen] = useState(false);
  const dropdownRef = useRef(null);

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
        setIsOpen(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const formatCreatedAt = (dateString) => {
    const date = new Date(dateString);
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'running': return '#28a745';
      case 'stopped': return '#6c757d';
      default: return '#ffc107';
    }
  };

  const handleSessionSwitch = (sessionId) => {
    switchToSession(sessionId);
    setIsOpen(false);
  };

  const handleSessionClose = async (e, sessionId) => {
    e.stopPropagation();
    if (canCloseSession(sessionId)) {
      try {
        await stopSession(sessionId);
      } catch (error) {
        console.error('Failed to close session:', error);
      }
    }
  };

  const activeSession = activeSessionId ? sessions.get(activeSessionId) : null;

  if (sessions.size === 0) {
    return null;
  }

  return (
    <div className="session-dropdown" ref={dropdownRef}>
      <button 
        className="session-dropdown-trigger"
        onClick={() => setIsOpen(!isOpen)}
      >
        <span className="session-info">
          {activeSession ? (
            <>
              <span className="session-name">{activeSession.module_name}</span>
              <span 
                className="session-status"
                style={{ color: getStatusColor(activeSession.status) }}
              >
                ● {activeSession.status}
              </span>
            </>
          ) : (
            <span className="session-name">No active session</span>
          )}
        </span>
        <span className="session-count">
          {sessions.size} session{sessions.size !== 1 ? 's' : ''}
        </span>
        <span className={`dropdown-arrow ${isOpen ? 'open' : ''}`}>▼</span>
      </button>

      {isOpen && (
        <div className="session-dropdown-menu">
          <div className="session-dropdown-header">
            <span>Active Sessions</span>
          </div>
          
          {Array.from(sessions.values()).map(session => (
            <div
              key={session.id}
              className={`session-item ${session.id === activeSessionId ? 'active' : ''}`}
              onClick={() => handleSessionSwitch(session.id)}
            >
              <div className="session-item-main">
                <div className="session-item-info">
                  <span className="session-item-name">{session.module_name}</span>
                  <span className="session-item-time">
                    Started at {formatCreatedAt(session.created_at)}
                  </span>
                </div>
                <div className="session-item-controls">
                  <span 
                    className="session-item-status"
                    style={{ color: getStatusColor(session.status) }}
                  >
                    ●
                  </span>
                  {canCloseSession(session.id) && (
                    <button
                      className="session-close-btn"
                      onClick={(e) => handleSessionClose(e, session.id)}
                      title="Close session"
                    >
                      ×
                    </button>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default SessionDropdown;