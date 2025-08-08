/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import React, { useState, useEffect, useRef } from 'react';
import AnsiToHtml from 'ansi-to-html';
import TerminalInput from './TerminalInput';

function Terminal({ sessionId, onSendInput, isActive }) {
  const [output, setOutput] = useState('');
  const [input, setInput] = useState('');
  const outputRef = useRef(null);
  const ansiConverter = useRef(new AnsiToHtml());

  useEffect(() => {
    console.log('Terminal useEffect: setting up WebSocket listener');
    // Listen for terminal output events from WebSocket
    const handleOutput = (event) => {
      const newOutput = event.detail;
      console.log('Terminal received output:', newOutput.substring(0, 50) + '...');
      setOutput(prev => prev + newOutput);
    };

    window.addEventListener('terminal-output', handleOutput);
    
    return () => {
      console.log('Terminal useEffect cleanup: removing WebSocket listener');
      window.removeEventListener('terminal-output', handleOutput);
    };
  }, []);

  useEffect(() => {
    // Auto-scroll to bottom when new output is added
    if (outputRef.current) {
      outputRef.current.scrollTop = outputRef.current.scrollHeight;
    }
  }, [output]);

  useEffect(() => {
    console.log('Terminal sessionId changed:', sessionId);
    // Clear terminal when session changes
    if (sessionId) {
      console.log('Setting output for new session:', sessionId);
      setOutput('Terminal connected to session: ' + sessionId + '\n');
    } else {
      console.log('No session, clearing output');
      setOutput('No active session. Select a module to start.\n');
    }
  }, [sessionId]);

  const handleInputSubmit = (e) => {
    e.preventDefault();
    console.log('Terminal input submit:', input, 'isActive:', isActive);
    if (input.trim() && isActive) {
      // Add input to terminal display
      setOutput(prev => prev + `> ${input}\n`);
      
      // Send input to backend
      console.log('Sending input to backend:', input);
      onSendInput(input);
      
      // Clear input field
      setInput('');
    } else {
      console.log('Input not sent - input:', input.trim(), 'isActive:', isActive);
    }
  };

  const handleKeyPress = (e) => {
    if (e.key === 'Enter') {
      handleInputSubmit(e);
    }
  };

  console.log('Terminal render - isActive:', isActive, 'sessionId:', sessionId);
  
  return (
    <div className="terminal-panel">
      <div 
        className="terminal-output" 
        ref={outputRef}
        dangerouslySetInnerHTML={{ 
          __html: output ? ansiConverter.current.toHtml(output) : 'Waiting for module output...' 
        }}
      />
      
      {/* Debug info */}
      <div style={{ fontSize: '10px', color: '#666', padding: '2px', backgroundColor: '#333' }}>
        Debug - isActive: {isActive ? 'true' : 'false'}, sessionId: {sessionId || 'none'}, output length: {output.length}
      </div>
      
      {/* Terminal input at bottom of terminal panel */}
      {isActive && (
        <div style={{ 
          padding: '0.5rem', 
          backgroundColor: '#2d2d30', 
          borderTop: '1px solid #333',
          marginTop: 'auto'
        }}>
          <TerminalInput 
            sessionId={sessionId}
            onSendInput={onSendInput}
            isActive={isActive}
          />
        </div>
      )}
    </div>
  );
}

export default Terminal;
