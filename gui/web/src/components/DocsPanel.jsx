/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import React from 'react';
import ReactMarkdown from 'react-markdown';

function DocsPanel({ content }) {
  // Function to remove license header from markdown content
  const stripLicenseHeader = (markdown) => {
    if (!markdown) return '';
    
    // Remove HTML comment license header that appears at the start of documentation files
    const cleanedContent = markdown.replace(/^<!--[\s\S]*?-->\s*/, '');
    
    // Remove any leading whitespace after license removal
    return cleanedContent.trim();
  };

  const cleanContent = stripLicenseHeader(content);

  return (
    <div className="docs-panel">
      <div className="panel-header">Documentation</div>
      
      {content ? (
        <div className="markdown-content">
          <ReactMarkdown>{cleanContent}</ReactMarkdown>
        </div>
      ) : (
        <div className="loading">
          <p>Select a module to view its documentation.</p>
        </div>
      )}
    </div>
  );
}

export default DocsPanel;
