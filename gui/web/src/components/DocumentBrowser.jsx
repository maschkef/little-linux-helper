/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: Apache-2.0

This project is part of the 'little-linux-helper' collection.
Licensed under the Apache License 2.0. See the LICENSE file in the project root for more information.
*/

import { useState, useEffect, useMemo } from 'react';
import rehypeRaw from 'rehype-raw';
import rehypeSanitize from 'rehype-sanitize';
import { defaultSchema } from 'hast-util-sanitize';
import MarkdownWithStatefulDetails from './MarkdownWithStatefulDetails';
import { apiFetch } from '../utils/api.js';

function DocumentBrowser() {
  const [allDocs, setAllDocs] = useState([]);
  const [categories, setCategories] = useState({});
  const [unlinkedDocPaths, setUnlinkedDocPaths] = useState([]);
  const [selectedDoc, setSelectedDoc] = useState(null);
  const [docContent, setDocContent] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [showNavigation, setShowNavigation] = useState(true);
  const [expandedCategories, setExpandedCategories] = useState({});

  useEffect(() => {
    fetchAllDocuments();
    fetchCategories();
    fetchUnlinkedDocuments();
  }, []);

  const fetchCategories = async () => {
    try {
      const response = await apiFetch('/api/docs/categories');
      if (response.ok) {
        const data = await response.json();
        setCategories(data);
        
        // Auto-expand System Administration and Development categories by default
        const initialExpanded = {};
        Object.keys(data).forEach(catId => {
          // Expand some categories by default
          initialExpanded[catId] = ['system_administration', 'development', 'libraries'].includes(catId);
        });
        initialExpanded['Unlinked Documents'] = true;
        setExpandedCategories(initialExpanded);
      } else {
        console.error('Failed to fetch categories');
      }
    } catch (error) {
      console.error('Error fetching categories:', error);
    }
  };

  const fetchAllDocuments = async () => {
    try {
    const response = await apiFetch('/api/docs');
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
    const response = await apiFetch('/api/docs/unlinked');
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
      // Handle unlinked file: IDs by extracting the path
      const actualId = docId.startsWith('file:') ? docId.substring(5) : docId;
      const response = await apiFetch(`/api/modules/${actualId}/docs`);
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

    allDocs.forEach(doc => {
      const categoryId = doc.category || 'uncategorized';
      
      if (!categorized[categoryId]) {
        categorized[categoryId] = [];
      }
      
      categorized[categoryId].push({
        ...doc,
        displayName: doc.name,
        selectable: true
      });
    });

    // Sort categories by order from API
    const sortedEntries = Object.entries(categorized).sort((a, b) => {
      const orderA = categories[a[0]]?.order ?? 999;
      const orderB = categories[b[0]]?.order ?? 999;
      return orderA - orderB;
    });

    return { categorized: Object.fromEntries(sortedEntries), unlinked: [] };
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
        selectable: true,
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
          
          {Object.entries(categorizedDocs).map(([categoryId, docs]) => {
            const categoryName = categories[categoryId]?.name || categories[categoryId]?.fallback_name || categoryId;
            
            return docs.length > 0 && (
              <div key={categoryId} style={{ marginBottom: '10px' }}>
                <div 
                  onClick={() => toggleCategory(categoryId)}
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
                    {expandedCategories[categoryId] ? '▼' : '▶'}
                  </span>
                  {categoryName}
                </div>
                
                {expandedCategories[categoryId] && (
                  <div style={{ marginLeft: '15px' }}>
                    {docs.map((doc) => {
                      const displayName = doc.displayName || doc.name || doc.id;
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
                          title={doc.description || displayName}
                        >
                          {displayName}
                        </button>
                      );
                    })}
                  </div>
                )}
              </div>
            );
          })}
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
                  {allDocs.find(doc => doc.id === selectedDoc)?.name || selectedDoc}
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
