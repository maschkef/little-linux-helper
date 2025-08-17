/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import React, { useState, useRef, useImperativeHandle, forwardRef } from 'react';
import { useTranslation } from 'react-i18next';

const TerminalInput = forwardRef(({ sessionId, onSendInput, onStopSession, isActive }, ref) => {
  const { t } = useTranslation('common');
  const [input, setInput] = useState('');
  const inputRef = useRef(null);

  // Expose focus method to parent component
  useImperativeHandle(ref, () => ({
    focus: () => {
      if (inputRef.current && isActive) {
        inputRef.current.focus();
      }
    }
  }));

  console.log('TerminalInput render - isActive:', isActive, 'sessionId:', sessionId);

  const handleInputSubmit = (e) => {
    e.preventDefault();
    console.log('TerminalInput input submit:', input, 'isActive:', isActive);
    if (input.trim() && isActive) {
      // Send input to backend
      console.log('Sending input to backend:', input);
      onSendInput(input);
      
      // Clear input field
      setInput('');
    } else {
      console.log('Input not sent - input:', input.trim(), 'isActive:', isActive);
    }
  };


  const handleStopSession = () => {
    if (isActive && sessionId && onStopSession) {
      onStopSession(sessionId);
    }
  };

  const handleKeyPress = (e) => {
    if (e.key === 'Enter') {
      handleInputSubmit(e);
    }
  };

  return (
    <form onSubmit={handleInputSubmit} style={{ display: 'flex', width: '100%', alignItems: 'center', gap: '0.5rem' }}>
        <input
          ref={inputRef}
          type="text"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyPress={handleKeyPress}
          placeholder={isActive ? t('terminal.inputPlaceholder') : t('terminal.startModulePrompt')}
          disabled={!isActive}
          style={{ 
            flex: 1,
            backgroundColor: '#1e1e1e',
            border: '1px solid #464647',
            color: '#d4d4d4',
            padding: '0.5rem',
            borderRadius: '4px',
            fontFamily: 'Courier New, monospace',
            opacity: isActive ? 1 : 0.6,
            cursor: isActive ? 'text' : 'not-allowed',
            fontSize: '0.9rem',
            height: '36px'
          }}
        />
        <button 
          type="submit" 
          disabled={!isActive || !input.trim()}
          style={{ 
            padding: '0.5rem 1rem',
            backgroundColor: '#007acc',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: (isActive && input.trim()) ? 'pointer' : 'not-allowed',
            opacity: (isActive && input.trim()) ? 1 : 0.6,
            fontSize: '0.9rem',
            height: '36px'
          }}
        >
{t('terminal.send')}
        </button>
        <button 
          type="button"
          onClick={handleStopSession}
          disabled={!isActive}
          style={{ 
            padding: '0.5rem 1rem',
            backgroundColor: '#dc3545',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: isActive ? 'pointer' : 'not-allowed',
            opacity: isActive ? 1 : 0.6,
            fontSize: '0.9rem',
            height: '36px',
            fontWeight: '500'
          }}
          title={t('terminal.stopTooltip')}
        >
{t('terminal.stop')}
        </button>
    </form>
  );
});

TerminalInput.displayName = 'TerminalInput';

export default TerminalInput;