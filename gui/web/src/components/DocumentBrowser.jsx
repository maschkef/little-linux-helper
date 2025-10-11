/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import { useState, useEffect, useMemo } from 'react';
import rehypeRaw from 'rehype-raw';
import rehypeSanitize from 'rehype-sanitize';
import { defaultSchema } from 'hast-util-sanitize';
import MarkdownWithStatefulDetails from './MarkdownWithStatefulDetails';

function DocumentBrowser() {
  const [allDocs, setAllDocs] = useState([]);
  const [unlinkedDocPaths, setUnlinkedDocPaths] = useState([]);
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
    'Libraries': false,
    'BTRFS Reference': false,
    'GUI Documentation': false,
    'Development & Tools': false,
    'Project Information': false,
    'Unlinked Documents': true
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
    'Libraries': [
      'lib_common', 'lib_colors', 'lib_config', 'lib_filesystem',
      'lib_i18n', 'lib_logging', 'lib_notifications', 'lib_package_mappings',
      'lib_packages', 'lib_system', 'lib_ui'
    ],
    'BTRFS Reference': [
      'lib_btrfs', 'lib_btrfs_core', 'lib_btrfs_layout'
    ],
    'GUI Documentation': [
      'gui_backend_api', 'gui_frontend_react', 'gui_i18n', 'gui_module_integration', 'gui_customization', 'gui_module_maintenance_guide'
    ],
    'Development & Tools': [
      'DEVELOPER_GUIDE', 'GUI_DEVELOPER_GUIDE'
    ],
    'Project Information': [
      'gui', 'README', 'README_DE', 'gui_README', 'doc_gui_launcher'
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
    'lib_common': 'Common Functions Library',
    'lib_colors': 'Color Functions Library', 
    'lib_config': 'Configuration Library',
    'lib_filesystem': 'Filesystem Library',
    'lib_i18n': 'Internationalization Library',
    'lib_logging': 'Logging Library',
    'lib_notifications': 'Notifications Library',
    'lib_package_mappings': 'Package Mappings Library',
    'lib_packages': 'Package Management Library',
    'lib_system': 'System Information Library',
    'lib_ui': 'User Interface Library',
    'lib_btrfs_core': 'BTRFS Core Library',
    'lib_btrfs_layout': 'BTRFS Layout Reference',
    'DEVELOPER_GUIDE': 'CLI Developer Guide',
    'GUI_DEVELOPER_GUIDE': 'GUI Developer Guide',
    'gui_backend_api': 'GUI Backend API',
    'gui_frontend_react': 'GUI React Frontend',
    'gui_i18n': 'GUI Internationalization',
    'gui_module_integration': 'GUI Module Integration',
    'gui_customization': 'GUI Customization',
    'gui_module_maintenance_guide': 'GUI Module Maintenance',
    'gui': 'GUI Documentation',
    'README': 'Project README',
    'README_DE': 'Project README (German)',
    'gui_README': 'GUI README',
    'doc_gui_launcher': 'GUI Launcher Guide'
  };

  useEffect(() => {
    fetchAllDocuments();
    fetchUnlinkedDocuments();
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

  const fetchUnlinkedDocuments = async () => {
    try {
      const response = await fetch('/api/docs/unlinked');
      if (response.ok) {
        const data = await response.json();
        if (Array.isArray(data)) {
          setUnlinkedDocPaths(data);
        } else {
          setUnlinkedDocPaths([]);
        }
      } else {
        console.error('Failed to fetch unlinked documentation list');
      }
    } catch (error) {
      console.error('Error fetching unlinked documents:', error);
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

    Object.keys(documentCategories).forEach(category => {
      categorized[category] = [];
    });

    const uncategorized = [];

    allDocs.forEach(doc => {
      const docId = doc.id || (doc.filename ? doc.filename.replace('.md', '') : '');
      let placed = false;

      for (const [category, docIds] of Object.entries(documentCategories)) {
        if (docIds.includes(docId)) {
          categorized[category].push({
            ...doc,
            id: docId,
            selectable: true
          });
          placed = true;
          break;
        }
      }

      if (!placed) {
        uncategorized.push({
          ...doc,
          id: docId,
          selectable: Boolean(docId)
        });
      }
    });

    return { categorized, unlinked: uncategorized };
  };

  const { categorized, unlinked } = getCategorizedDocuments();

  const unlinkedEntries = [...unlinked];
  const seenFilenames = new Set(
    unlinkedEntries
      .map((doc) => doc?.filename)
      .filter(Boolean)
  );

  unlinkedDocPaths.forEach((path) => {
    if (!seenFilenames.has(path)) {
      unlinkedEntries.push({
        id: `file:${path}`,
        name: path,
        filename: path,
        selectable: false,
        isFileOnly: true
      });
    }
  });

  const categorizedDocs = { ...categorized };
  if (unlinkedEntries.length > 0) {
    categorizedDocs['Unlinked Documents'] = unlinkedEntries;
  }

  const cleanContent = stripLicenseHeader(docContent);

  const customSanitizeSchema = useMemo(() => ({
    ...defaultSchema,
    tagNames: [
      ...defaultSchema.tagNames,
      'details',
      'summary',
      'img'
    ],
    attributes: {
      ...defaultSchema.attributes,
      img: ['src', 'alt', 'width', 'height', 'align', 'style', 'loading'],
      details: ['open', 'style'],
      summary: ['style'],
      '*': ['className', 'style']
    }
  }), []);

  const markdownRehypePlugins = useMemo(
    () => [rehypeRaw, [rehypeSanitize, customSanitizeSchema]],
    [customSanitizeSchema]
  );

  const markdownComponents = useMemo(() => ({
    img: ({ node, ...props }) => {
      let src = props.src;
      if (src && !src.startsWith('http') && !src.startsWith('/')) {
        if (src.includes('header-logo.svg')) {
          src = '/header-logo.svg';
        } else {
          const normalized = src.replace(/^\.\//, '').replace(/^\/+/, '');
          src = `/${normalized}`;
        }
      }

      return (
        <img
          {...props}
          src={src}
          loading={props.loading || 'lazy'}
          style={{
            maxWidth: '100%',
            height: 'auto',
            ...props.style
          }}
        />
      );
    },
    summary: ({ node, ...props }) => (
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
  }), []);

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
                    {docs.map((doc) => {
                      const displayName = documentNames[doc.id] || doc.name || doc.filename || doc.id;
                      const docKey = doc.id || doc.filename || displayName;

                      if (doc.selectable === false) {
                        return (
                          <div
                            key={docKey}
                            style={{
                              padding: '6px 8px',
                              margin: '2px 0',
                              fontSize: '11px',
                              backgroundColor: '#3a4a5a',
                              color: '#f0f4f8',
                              borderRadius: '3px',
                              display: 'flex',
                              justifyContent: 'space-between',
                              alignItems: 'center'
                            }}
                            title={`${displayName} (not linked in navigation)`}
                          >
                            <span>{displayName}</span>
                            <span style={{ fontSize: '10px', opacity: 0.7 }}>Not linked yet</span>
                          </div>
                        );
                      }

                      return (
                        <button
                          key={docKey}
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
                            opacity: selectedDoc === doc.id ? 1 : 0.85
                          }}
                          title={doc.description || documentNames[doc.id] || doc.id}
                        >
                          {displayName}
                        </button>
                      );
                    })}
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
              <MarkdownWithStatefulDetails
                docId={selectedDoc}
                markdown={cleanContent}
                rehypePlugins={markdownRehypePlugins}
                components={markdownComponents}
              />
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
