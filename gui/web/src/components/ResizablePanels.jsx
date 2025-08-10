/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import React, { useState, useRef, useCallback, useEffect } from 'react';

function ResizablePanels({ children, panelWidths, onPanelWidthChange, showHelpPanel = true, showDocsPanel = true }) {
  const [terminalWidth, setTerminalWidth] = useState(panelWidths?.terminal || 50);
  const [helpWidth, setHelpWidth] = useState(panelWidths?.help || 25);
  const [docsWidth, setDocsWidth] = useState(panelWidths?.docs || 25);
  
  // Update local state when props change
  useEffect(() => {
    if (panelWidths) {
      setTerminalWidth(panelWidths.terminal);
      setHelpWidth(panelWidths.help);
      setDocsWidth(panelWidths.docs);
    }
  }, [panelWidths]);
  
  const containerRef = useRef(null);
  const isResizing = useRef(false);
  const resizeType = useRef(null);

  const handleMouseDown = useCallback((type) => (e) => {
    isResizing.current = true;
    resizeType.current = type;
    e.preventDefault();
    
    const handleMouseMove = (e) => {
      if (!isResizing.current || !containerRef.current) return;
      
      const containerRect = containerRef.current.getBoundingClientRect();
      const mouseX = e.clientX - containerRect.left;
      const containerWidth = containerRect.width;
      const percentage = (mouseX / containerWidth) * 100;
      
      if (resizeType.current === 'terminal-help') {
        // Resizing between terminal and help panel
        const newTerminalWidth = Math.max(30, Math.min(70, percentage));
        const remaining = 100 - newTerminalWidth;
        const helpRatio = helpWidth / (helpWidth + docsWidth);
        
        const newHelpWidth = remaining * helpRatio;
        const newDocsWidth = remaining * (1 - helpRatio);
        
        setTerminalWidth(newTerminalWidth);
        setHelpWidth(newHelpWidth);
        setDocsWidth(newDocsWidth);
        
        // Update parent state
        if (onPanelWidthChange) {
          onPanelWidthChange({
            terminal: newTerminalWidth,
            help: newHelpWidth,
            docs: newDocsWidth
          });
        }
      } else if (resizeType.current === 'help-docs') {
        // Resizing between help and docs panel
        const sidebarWidth = 100 - terminalWidth;
        const helpStart = terminalWidth;
        const relativeX = percentage - helpStart;
        const relativePercentage = (relativeX / sidebarWidth) * 100;
        
        const newHelpWidth = Math.max(10, Math.min(90, relativePercentage)) * sidebarWidth / 100;
        const newDocsWidth = sidebarWidth - newHelpWidth;
        
        setHelpWidth(newHelpWidth);
        setDocsWidth(newDocsWidth);
        
        // Update parent state
        if (onPanelWidthChange) {
          onPanelWidthChange({
            terminal: terminalWidth,
            help: newHelpWidth,
            docs: newDocsWidth
          });
        }
      }
    };
    
    const handleMouseUp = () => {
      isResizing.current = false;
      resizeType.current = null;
      document.removeEventListener('mousemove', handleMouseMove);
      document.removeEventListener('mouseup', handleMouseUp);
    };
    
    document.addEventListener('mousemove', handleMouseMove);
    document.addEventListener('mouseup', handleMouseUp);
  }, [helpWidth, docsWidth, terminalWidth, onPanelWidthChange]);

  // Calculate actual widths based on visible panels
  const getActualWidths = () => {
    if (showHelpPanel && showDocsPanel) {
      // All panels visible - use stored widths
      return { terminal: terminalWidth, help: helpWidth, docs: docsWidth };
    } else if (showHelpPanel && !showDocsPanel) {
      // Only help panel visible - terminal + help
      return { terminal: terminalWidth, help: helpWidth + docsWidth, docs: 0 };
    } else if (!showHelpPanel && showDocsPanel) {
      // Only docs panel visible - terminal + docs
      return { terminal: terminalWidth, help: 0, docs: helpWidth + docsWidth };
    } else {
      // No side panels - terminal takes full width
      return { terminal: 100, help: 0, docs: 0 };
    }
  };

  const actualWidths = getActualWidths();

  return (
    <div ref={containerRef} className="panels" style={{ 
      display: 'flex', 
      height: 'calc(100% - 70px)', // Only account for session controls
      boxSizing: 'border-box' 
    }}>
      {/* Terminal Panel */}
      <div style={{ width: `${actualWidths.terminal}%`, display: 'flex', flexDirection: 'column', height: '100%', boxSizing: 'border-box' }}>
        {children[0]}
      </div>
      
      {/* Resizer between terminal and help - only show if help or docs panel is visible */}
      {(showHelpPanel || showDocsPanel) && (
        <div 
          className="panel-resizer"
          onMouseDown={handleMouseDown('terminal-help')}
        />
      )}
      
      {/* Help Panel - only render if visible */}
      {showHelpPanel && (
        <div style={{ width: `${actualWidths.help}%`, display: 'flex', flexDirection: 'column', height: '100%', boxSizing: 'border-box' }}>
          {children[1]}
        </div>
      )}
      
      {/* Resizer between help and docs - only show if both panels are visible */}
      {showHelpPanel && showDocsPanel && (
        <div 
          className="panel-resizer"
          onMouseDown={handleMouseDown('help-docs')}
        />
      )}
      
      {/* Docs Panel - only render if visible */}
      {showDocsPanel && (
        <div style={{ width: `${actualWidths.docs}%`, display: 'flex', flexDirection: 'column', height: '100%', boxSizing: 'border-box' }}>
          {children[2]}
        </div>
      )}
    </div>
  );
}

export default ResizablePanels;