/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import React, { useState, useRef, useCallback, useEffect } from 'react';

function ResizablePanels({ children, panelWidths, onPanelWidthChange }) {
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

  return (
    <div ref={containerRef} className="panels" style={{ 
      display: 'flex', 
      height: 'calc(100% - 70px)', // Only account for session controls
      boxSizing: 'border-box' 
    }}>
      {/* Terminal Panel */}
      <div style={{ width: `${terminalWidth}%`, display: 'flex', flexDirection: 'column', height: '100%', boxSizing: 'border-box' }}>
        {children[0]}
      </div>
      
      {/* Resizer between terminal and help */}
      <div 
        className="panel-resizer"
        onMouseDown={handleMouseDown('terminal-help')}
      />
      
      {/* Help Panel */}
      <div style={{ width: `${helpWidth}%`, display: 'flex', flexDirection: 'column', height: '100%', boxSizing: 'border-box' }}>
        {children[1]}
      </div>
      
      {/* Resizer between help and docs */}
      <div 
        className="panel-resizer"
        onMouseDown={handleMouseDown('help-docs')}
      />
      
      {/* Docs Panel */}
      <div style={{ width: `${docsWidth}%`, display: 'flex', flexDirection: 'column', height: '100%', boxSizing: 'border-box' }}>
        {children[2]}
      </div>
    </div>
  );
}

export default ResizablePanels;