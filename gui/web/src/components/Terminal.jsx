/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import React, { useState, useEffect, useRef } from 'react';
import { useTranslation } from 'react-i18next';
import AnsiToHtml from 'ansi-to-html';
import TerminalInput from './TerminalInput.jsx';
import { useSession } from '../contexts/SessionContext';

function Terminal() {
  const { t } = useTranslation('common');
  const { activeSessionId, getActiveSession, getSessionOutput, sendInput, stopSession } = useSession();
  const [localOutput, setLocalOutput] = useState('');
  const outputRef = useRef(null);
  const terminalInputRef = useRef(null);
  const ansiConverter = useRef(new AnsiToHtml());

  useEffect(() => {
    // Listen for terminal output events from WebSocket (for active session only)
    const handleOutput = (event) => {
      if (activeSessionId) {
        const newOutput = event.detail;
        setLocalOutput(prev => prev + newOutput);
      }
    };

    window.addEventListener('terminal-output', handleOutput);
    
    return () => {
      window.removeEventListener('terminal-output', handleOutput);
    };
  }, [activeSessionId]);

  useEffect(() => {
    // Load session output when active session changes
    if (activeSessionId) {
      const sessionOutput = getSessionOutput(activeSessionId);
      setLocalOutput(sessionOutput.join(''));
    } else {
      setLocalOutput(t('terminal.noActiveSession') + '\n');
    }
  }, [activeSessionId, getSessionOutput]);

  useEffect(() => {
    // Auto-scroll to bottom when new output is added
    if (outputRef.current) {
      outputRef.current.scrollTop = outputRef.current.scrollHeight;
    }
  }, [localOutput]);

  const handleSendInput = async (input) => {
    if (activeSessionId && input.trim()) {
      try {
        await sendInput(activeSessionId, input);
        // Add input to local display
        setLocalOutput(prev => prev + `> ${input}\n`);
      } catch (error) {
        console.error('Failed to send input:', error);
        setLocalOutput(prev => prev + `Error sending input: ${error.message}\n`);
      }
    }
  };

  const handleTerminalClick = () => {
    // Focus the input field when terminal is clicked
    if (terminalInputRef.current && isActive) {
      terminalInputRef.current.focus();
    }
  };

  const activeSession = getActiveSession();
  const isActive = activeSession?.status === 'running';
  
  return (
    <div className="terminal-panel">
      <div 
        className="terminal-output" 
        ref={outputRef}
        onClick={handleTerminalClick}
        style={{ cursor: isActive ? 'text' : 'default' }}
        dangerouslySetInnerHTML={{ 
          __html: localOutput ? ansiConverter.current.toHtml(localOutput) : 'Waiting for module output...' 
        }}
      />
      
      {/* Terminal input at bottom of terminal panel */}
      {isActive && (
        <div style={{ 
          padding: '0.5rem', 
          backgroundColor: '#2d2d30', 
          borderTop: '1px solid #333',
          marginTop: 'auto'
        }}>
          <TerminalInput 
            ref={terminalInputRef}
            sessionId={activeSessionId}
            onSendInput={handleSendInput}
            onStopSession={stopSession}
            isActive={isActive}
          />
        </div>
      )}
    </div>
  );
}

export default Terminal;
