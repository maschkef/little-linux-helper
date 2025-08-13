/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import { useState, useEffect } from 'react';
import ReactMarkdown from 'react-markdown';
import rehypeRaw from 'rehype-raw';
import rehypeSanitize from 'rehype-sanitize';
import { defaultSchema } from 'hast-util-sanitize';

function DocumentBrowser() {
  const [allDocs, setAllDocs] = useState([]);
  const [selectedDoc, setSelectedDoc] = useState(null);
  const [docContent, setDocContent] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [showNavigation, setShowNavigation] = useState(true);
  const [expandedCategories, setExpandedCategories] = useState({
    'System Administration': true,
    'Backup & Recovery': false,
    'Docker & Containers': false,
    'Logs & Analysis': false,
    'System Maintenance': false,
    'Development & Libraries': false,
    'Project Information': false
  });

  // Document categorization mapping
  const documentCategories = {
    'System Administration': [
      'mod_system_info', 'mod_security', 'mod_disk', 'mod_packages', 'mod_energy'
    ],
    'Backup & Recovery': [
      'mod_backup', 'mod_btrfs_backup', 'mod_btrfs_restore', 'mod_backup_tar', 
      'mod_restore_tar', 'mod_backup_rsync', 'mod_restore_rsync'
    ],
    'Docker & Containers': [
      'mod_docker', 'mod_docker_setup', 'mod_docker_security'
    ],
    'Logs & Analysis': [
      'mod_logs', 'advanced_log_analyzer'
    ],
    'System Maintenance': [
      'mod_restarts'
    ],
    'Development & Libraries': [
      'lib_btrfs', 'DEVELOPER_GUIDE'
    ],
    'Project Information': [
      'gui', 'README', 'gui_README'
    ]
  };

  // Friendly names for documents
  const documentNames = {
    'mod_system_info': 'System Information',
    'mod_security': 'Security Analysis',
    'mod_disk': 'Disk Management',
    'mod_packages': 'Package Management',
    'mod_energy': 'Energy Management',
    'mod_backup': 'General Backup',
    'mod_btrfs_backup': 'BTRFS Backup',
    'mod_btrfs_restore': 'BTRFS Restore',
    'mod_backup_tar': 'TAR Backup',
    'mod_restore_tar': 'TAR Restore',
    'mod_backup_rsync': 'RSYNC Backup',
    'mod_restore_rsync': 'RSYNC Restore',
    'mod_docker': 'Docker Management',
    'mod_docker_setup': 'Docker Setup',
    'mod_docker_security': 'Docker Security',
    'mod_logs': 'Log Analysis',
    'advanced_log_analyzer': 'Advanced Log Analyzer',
    'mod_restarts': 'System Restarts',
    'lib_btrfs': 'BTRFS Library',
    'DEVELOPER_GUIDE': 'Developer Guide',
    'gui': 'GUI Documentation',
    'README': 'Project README',
    'gui_README': 'GUI README'
  };

  useEffect(() => {
    fetchAllDocuments();
  }, []);

  const fetchAllDocuments = async () => {
    try {
      const response = await fetch('/api/docs');
      if (response.ok) {
        const data = await response.json();
        setAllDocs(data);
      } else {
        console.error('Failed to fetch documents list');
      }
    } catch (error) {
      console.error('Error fetching documents:', error);
    }
  };

  const fetchDocument = async (docId) => {
    setIsLoading(true);
    try {
      const response = await fetch(`/api/modules/${docId}/docs`);
      if (response.ok) {
        const data = await response.json();
        setDocContent(data.content);
        setSelectedDoc(docId);
      } else {
        setDocContent('Documentation not available for this document.');
      }
    } catch (error) {
      console.error('Failed to fetch document:', error);
      setDocContent('Error loading documentation.');
    }
    setIsLoading(false);
  };

  const stripLicenseHeader = (markdown) => {
    if (!markdown) return '';
    const cleanedContent = markdown.replace(/^<!--[\s\S]*?-->\s*/, '');
    return cleanedContent.trim();
  };

  const toggleCategory = (category) => {
    setExpandedCategories(prev => ({
      ...prev,
      [category]: !prev[category]
    }));
  };

  const getCategorizedDocuments = () => {
    const categorized = {};
    
    // Initialize categories
    Object.keys(documentCategories).forEach(category => {
      categorized[category] = [];
    });

    // Categorize available documents
    allDocs.forEach(doc => {
      let placed = false;
      for (const [category, docIds] of Object.entries(documentCategories)) {
        // Check both doc.id and doc.filename (without .md extension) for matching
        const docIdToCheck = doc.id || (doc.filename ? doc.filename.replace('.md', '') : '');
        if (docIds.includes(docIdToCheck) || docIds.includes(doc.id)) {
          categorized[category].push({
            ...doc,
            id: docIdToCheck || doc.id // Ensure we have a consistent ID
          });
          placed = true;
          break;
        }
      }
      // If not categorized, add to Project Information
      if (!placed) {
        categorized['Project Information'].push(doc);
      }
    });

    return categorized;
  };

  const categorizedDocs = getCategorizedDocuments();
  const cleanContent = stripLicenseHeader(docContent);

  // Custom sanitize schema to allow HTML elements used in README files
  const customSanitizeSchema = {
    ...defaultSchema,
    tagNames: [
      ...defaultSchema.tagNames,
      'details',
      'summary',
      'img'
    ],
    attributes: {
      ...defaultSchema.attributes,
      img: ['src', 'alt', 'width', 'height', 'align', 'style'],
      details: ['open', 'style'],
      summary: ['style'],
      '*': ['className', 'style'] // Allow style attributes for custom styling
    }
  };

  return (
    <div className="document-browser" style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      {/* Header with navigation toggle */}
      <div style={{
        display: 'flex',
        alignItems: 'center',
        padding: '8px 10px',
        backgroundColor: '#34495e',
        borderBottom: '1px solid #2c3e50'
      }}>
        <button
          onClick={() => setShowNavigation(!showNavigation)}
          style={{
            padding: '4px 8px',
            fontSize: '12px',
            backgroundColor: '#007bff',
            color: 'white',
            border: 'none',
            borderRadius: '3px',
            cursor: 'pointer',
            marginRight: '10px'
          }}
        >
          {showNavigation ? '◄ Hide Nav' : '► Show Nav'}
        </button>
        <h4 style={{ margin: '0', color: '#ecf0f1', fontSize: '14px' }}>
          Documentation Browser
        </h4>
      </div>
      
      <div className="browser-layout" style={{ display: 'flex', height: 'calc(100% - 40px)' }}>
        {/* Document Navigation */}
        {showNavigation && (
          <div className="doc-navigation" style={{
            width: '280px',
            borderRight: '1px solid #34495e',
            padding: '10px',
            overflowY: 'auto',
            backgroundColor: '#2c3e50',
            maxHeight: '100%',
            height: '100%'
          }}>
          
          {Object.entries(categorizedDocs).map(([category, docs]) => (
            docs.length > 0 && (
              <div key={category} style={{ marginBottom: '10px' }}>
                <div 
                  onClick={() => toggleCategory(category)}
                  style={{
                    cursor: 'pointer',
                    padding: '5px',
                    backgroundColor: '#34495e',
                    borderRadius: '3px',
                    marginBottom: '5px',
                    fontSize: '12px',
                    color: '#ecf0f1',
                    fontWeight: 'bold',
                    display: 'flex',
                    alignItems: 'center'
                  }}
                >
                  <span style={{ marginRight: '5px' }}>
                    {expandedCategories[category] ? '▼' : '▶'}
                  </span>
                  {category}
                </div>
                
                {expandedCategories[category] && (
                  <div style={{ marginLeft: '15px' }}>
                    {docs.map((doc) => (
                      <button
                        key={doc.id}
                        onClick={() => fetchDocument(doc.id)}
                        style={{
                          display: 'block',
                          width: '100%',
                          padding: '6px 8px',
                          margin: '2px 0',
                          fontSize: '11px',
                          backgroundColor: selectedDoc === doc.id ? '#007bff' : '#3498db',
                          color: 'white',
                          border: 'none',
                          borderRadius: '3px',
                          cursor: 'pointer',
                          textAlign: 'left',
                          opacity: selectedDoc === doc.id ? 1 : 0.8
                        }}
                        title={doc.description || documentNames[doc.id] || doc.id}
                      >
                        {documentNames[doc.id] || doc.name || doc.id}
                      </button>
                    ))}
                  </div>
                )}
              </div>
            )
          ))}
          </div>
        )}

        {/* Document Content */}
        <div className="doc-content" style={{
          flex: 1,
          padding: '15px',
          overflowY: 'auto',
          height: '100%',
          maxHeight: '100%'
        }}>
          {isLoading ? (
            <p>Loading documentation...</p>
          ) : selectedDoc ? (
            <div className="markdown-content">
              <div style={{ 
                marginBottom: '15px', 
                paddingBottom: '10px', 
                borderBottom: '1px solid #34495e' 
              }}>
                <h3 style={{ margin: '0', color: '#ecf0f1', fontSize: '16px' }}>
                  {documentNames[selectedDoc] || selectedDoc}
                </h3>
              </div>
              <ReactMarkdown 
              key={selectedDoc} // Prevent unnecessary re-renders
              rehypePlugins={[rehypeRaw, [rehypeSanitize, customSanitizeSchema]]}
              components={{
                img: ({node, ...props}) => {
                  // Handle image paths for README files
                  let src = props.src;
                  if (src && !src.startsWith('http') && !src.startsWith('/')) {
                    // Special handling for header logo in README files
                    if (src.includes('header-logo.svg')) {
                      src = '/header-logo.svg';
                    } else {
                      src = '/' + src;
                    }
                  }
                  return (
                    <img 
                      {...props} 
                      src={src}
                      style={{
                        maxWidth: '100%',
                        height: 'auto',
                        ...props.style
                      }}
                    />
                  );
                },
                details: ({node, ...props}) => {
                  // Use a controlled component approach to prevent auto-closing
                  return (
                    <details 
                      {...props}
                      style={{
                        marginBottom: '10px',
                        border: '1px solid #34495e',
                        borderRadius: '4px',
                        backgroundColor: '#34495e'
                      }}
                    />
                  );
                },
                summary: ({node, ...props}) => (
                  <summary 
                    {...props}
                    style={{
                      padding: '8px 12px',
                      cursor: 'pointer',
                      fontWeight: 'bold',
                      backgroundColor: '#2c3e50',
                      borderRadius: '3px',
                      outline: 'none',
                      ...props.style
                    }}
                  />
                )
              }}
            >
              {cleanContent}
            </ReactMarkdown>
            </div>
          ) : (
            <div className="no-selection" style={{
              textAlign: 'center',
              color: '#7f8c8d',
              marginTop: '50px'
            }}>
              <p>Select a document from the navigation to view its contents.</p>
              <p style={{ fontSize: '12px', marginTop: '20px' }}>
                Browse through categorized documentation independent of the current module.
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default DocumentBrowser;