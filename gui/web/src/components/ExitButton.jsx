/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useSession } from '../contexts/SessionContext.jsx';
import { apiFetch } from '../utils/api.js';

const ExitButton = () => {
  const { t } = useTranslation('common');
  const { sessions } = useSession();
  const [showConfirmDialog, setShowConfirmDialog] = useState(false);
  const [isShuttingDown, setIsShuttingDown] = useState(false);
  const [shutdownResponse, setShutdownResponse] = useState(null);

  // Get active sessions
  const activeSessions = Array.from(sessions.values()).filter(session => 
    session.status !== 'stopped'
  );

  const handleExitClick = () => {
    setShowConfirmDialog(true);
  };

  const handleConfirmExit = async (force = false) => {
    setIsShuttingDown(true);
    
    try {
      const url = force ? '/api/shutdown?force=true' : '/api/shutdown';
      const response = await apiFetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
      });

      if (response.ok) {
        const result = await response.json();
        setShutdownResponse(result);

        if (result.activeSessions?.length === 0 || force) {
          setTimeout(() => {
            window.close();
            setTimeout(() => {
              alert(t('exit.browserCloseMessage'));
            }, 1000);
          }, 1500);
        }
      } else if (response.status !== 401) {
        alert(t('exit.shutdownError'));
        setIsShuttingDown(false);
      }
    } catch (error) {
      console.error('Shutdown error:', error);
      alert(t('exit.shutdownError'));
      setIsShuttingDown(false);
    }
  };

  const handleCancel = () => {
    setShowConfirmDialog(false);
    setShutdownResponse(null);
    setIsShuttingDown(false);
  };

  if (showConfirmDialog) {
    return (
      <div className="exit-dialog-overlay" style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        backgroundColor: 'rgba(0, 0, 0, 0.7)',
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        zIndex: 9999
      }}>
        <div className="exit-dialog" style={{
          backgroundColor: '#1a1a1a',
          border: '1px solid #333',
          borderRadius: '8px',
          padding: '24px',
          minWidth: '400px',
          maxWidth: '600px',
          color: '#e0e0e0'
        }}>
          <h3 style={{ 
            margin: '0 0 16px 0', 
            color: '#ff6b6b',
            fontSize: '18px'
          }}>
            {t('exit.confirmTitle')}
          </h3>
          
          <p style={{ margin: '0 0 16px 0' }}>
            {t('exit.confirmMessage')}
          </p>

          {activeSessions.length > 0 && (
            <div style={{
              backgroundColor: '#2a1a1a',
              border: '1px solid #ff6b6b',
              borderRadius: '4px',
              padding: '12px',
              margin: '16px 0'
            }}>
              <h4 style={{ 
                margin: '0 0 8px 0', 
                color: '#ff6b6b',
                fontSize: '14px'
              }}>
                {t('exit.activeSessionsWarning')}
              </h4>
              <ul style={{ margin: '0', paddingLeft: '20px' }}>
                {activeSessions.map(session => (
                  <li key={session.id} style={{ 
                    margin: '4px 0',
                    fontSize: '13px',
                    color: '#ccc'
                  }}>
                    {session.module_name} ({t('exit.startedAt', { 
                      time: new Date(session.created_at).toLocaleTimeString() 
                    })})
                  </li>
                ))}
              </ul>
              <p style={{ 
                margin: '8px 0 0 0',
                fontSize: '13px',
                color: '#ff9999'
              }}>
                {t('exit.sessionsWillBeTerminated')}
              </p>
            </div>
          )}

          {shutdownResponse?.warning && (
            <div style={{
              backgroundColor: '#2a1a00',
              border: '1px solid #ffaa00',
              borderRadius: '4px',
              padding: '12px',
              margin: '16px 0',
              color: '#ffcc66'
            }}>
              {shutdownResponse.warning}
            </div>
          )}

          {isShuttingDown && (
            <div style={{
              textAlign: 'center',
              padding: '16px',
              color: '#4CAF50'
            }}>
              <div style={{ 
                fontSize: '16px',
                marginBottom: '8px'
              }}>
                {t('exit.shuttingDown')}
              </div>
              <div style={{ 
                fontSize: '13px',
                color: '#ccc'
              }}>
                {shutdownResponse?.message}
              </div>
            </div>
          )}

          <div style={{
            display: 'flex',
            justifyContent: 'flex-end',
            gap: '12px',
            marginTop: '24px'
          }}>
            <button
              onClick={handleCancel}
              disabled={isShuttingDown}
              style={{
                padding: '8px 16px',
                backgroundColor: '#333',
                border: '1px solid #555',
                borderRadius: '4px',
                color: '#e0e0e0',
                cursor: isShuttingDown ? 'not-allowed' : 'pointer',
                opacity: isShuttingDown ? 0.5 : 1
              }}
            >
              {t('exit.cancel')}
            </button>
            <button
              onClick={() => handleConfirmExit(true)}
              disabled={isShuttingDown}
              style={{
                padding: '8px 16px',
                backgroundColor: '#ff4444',
                border: '1px solid #ff6666',
                borderRadius: '4px',
                color: 'white',
                cursor: isShuttingDown ? 'not-allowed' : 'pointer',
                opacity: isShuttingDown ? 0.5 : 1
              }}
            >
              {isShuttingDown ? t('exit.shuttingDown') : t('exit.confirmExit')}
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <button
      onClick={handleExitClick}
      className="exit-button"
      title={t('exit.exitTooltip')}
      style={{
        padding: '6px 12px',
        backgroundColor: '#ff4444',
        border: '1px solid #ff6666',
        borderRadius: '4px',
        color: 'white',
        cursor: 'pointer',
        fontSize: '12px',
        marginLeft: '12px'
      }}
    >
      {t('exit.exit')}
    </button>
  );
};

export default ExitButton;
