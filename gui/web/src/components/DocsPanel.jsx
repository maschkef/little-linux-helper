/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import React, { useState } from 'react';
import ReactMarkdown from 'react-markdown';

function DocsPanel({ content, selectedModule, onModuleSelect }) {
  const [currentDoc, setCurrentDoc] = useState('');
  const [isLoadingRelated, setIsLoadingRelated] = useState(false);

  // Mapping of modules to their related documentation
  const relatedDocs = {
    backup: [
      { id: 'mod_btrfs_backup', name: 'BTRFS Backup', description: 'Snapshot-based BTRFS backups' },
      { id: 'mod_btrfs_restore', name: 'BTRFS Restore', description: 'Restore from BTRFS snapshots' },
      { id: 'mod_backup_tar', name: 'TAR Backup', description: 'Archive-based backups' },
      { id: 'mod_restore_tar', name: 'TAR Restore', description: 'Restore from TAR archives' },
      { id: 'mod_backup_rsync', name: 'RSYNC Backup', description: 'Incremental file-based backups' },
      { id: 'mod_restore_rsync', name: 'RSYNC Restore', description: 'Restore from RSYNC backups' }
    ],
    docker: [
      { id: 'mod_docker_setup', name: 'Docker Setup', description: 'Install and configure Docker' },
      { id: 'mod_docker_security', name: 'Docker Security', description: 'Security audit for Docker containers' }
    ],
    packages: [
      { id: 'advanced_log_analyzer', name: 'Advanced Log Analyzer', description: 'Python-based log analysis tool' }
    ]
  };

  const fetchRelatedDoc = async (docId) => {
    setIsLoadingRelated(true);
    try {
      const response = await fetch(`/api/modules/${docId}/docs`);
      if (response.ok) {
        const data = await response.json();
        setCurrentDoc(data.content);
      } else {
        setCurrentDoc('Documentation not available for this related module.');
      }
    } catch (error) {
      console.error('Failed to fetch related doc:', error);
      setCurrentDoc('Error loading related documentation.');
    }
    setIsLoadingRelated(false);
  };

  const handleBackToMain = () => {
    setCurrentDoc('');
  };
  // Function to remove license header from markdown content
  const stripLicenseHeader = (markdown) => {
    if (!markdown) return '';
    
    // Remove HTML comment license header that appears at the start of documentation files
    const cleanedContent = markdown.replace(/^<!--[\s\S]*?-->\s*/, '');
    
    // Remove any leading whitespace after license removal
    return cleanedContent.trim();
  };

  const displayContent = currentDoc || content;
  const cleanContent = stripLicenseHeader(displayContent);
  
  // Get related docs for current module
  const moduleRelatedDocs = selectedModule && relatedDocs[selectedModule.id] ? relatedDocs[selectedModule.id] : [];
  const showRelatedDocs = moduleRelatedDocs.length > 0 && !currentDoc;

  return (
    <div className="docs-panel">
      <div className="panel-header">
        Documentation
        {currentDoc && (
          <button 
            onClick={handleBackToMain} 
            style={{
              marginLeft: '10px',
              fontSize: '12px',
              padding: '2px 8px',
              backgroundColor: '#3498db',
              color: 'white',
              border: 'none',
              borderRadius: '3px',
              cursor: 'pointer'
            }}
          >
            ← Back to Main
          </button>
        )}
      </div>
      
      {showRelatedDocs && (
        <div style={{ 
          padding: '10px', 
          backgroundColor: '#2c3e50', 
          borderBottom: '1px solid #34495e',
          marginBottom: '10px'
        }}>
          <h4 style={{ margin: '0 0 8px 0', fontSize: '14px', color: '#ecf0f1' }}>
            Related Documentation:
          </h4>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px' }}>
            {moduleRelatedDocs.map((relDoc) => (
              <button
                key={relDoc.id}
                onClick={() => fetchRelatedDoc(relDoc.id)}
                disabled={isLoadingRelated}
                style={{
                  padding: '4px 8px',
                  fontSize: '12px',
                  backgroundColor: '#007bff',
                  color: 'white',
                  border: 'none',
                  borderRadius: '4px',
                  cursor: isLoadingRelated ? 'wait' : 'pointer',
                  opacity: isLoadingRelated ? 0.6 : 1
                }}
                title={relDoc.description}
              >
                {relDoc.name}
              </button>
            ))}
          </div>
        </div>
      )}
      
      {displayContent ? (
        <div className="markdown-content">
          {isLoadingRelated ? (
            <p>Loading related documentation...</p>
          ) : (
            <ReactMarkdown>{cleanContent}</ReactMarkdown>
          )}
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
