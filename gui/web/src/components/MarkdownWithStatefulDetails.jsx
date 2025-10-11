/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import { createContext, useContext, useEffect, useMemo, useState } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import rehypeRaw from 'rehype-raw';

/*
  This helper keeps <details> state stable across React re-renders by tracking
  open sections per document. The state is persisted in sessionStorage so the
  browser remembers toggled sections while the GUI stays open.
*/
const DetailsContext = createContext(null);

function readSessionMap(key) {
  if (typeof window === 'undefined') {
    return {};
  }

  try {
    const stored = window.sessionStorage.getItem(key);
    return stored ? JSON.parse(stored) : {};
  } catch (error) {
    console.warn('Unable to read details state from sessionStorage:', error);
    return {};
  }
}

function useSessionMap(key) {
  const [map, setMap] = useState(() => readSessionMap(key));

  useEffect(() => {
    if (typeof window === 'undefined') {
      return;
    }

    try {
      window.sessionStorage.setItem(key, JSON.stringify(map));
    } catch (error) {
      console.warn('Unable to persist details state to sessionStorage:', error);
    }
  }, [key, map]);

  return [map, setMap];
}

function DetailsProvider({ docId, children }) {
  const storageKey = `doc:${docId}:open-details`;
  const [openMap, setOpenMap] = useSessionMap(storageKey);
  const value = useMemo(() => ({ openMap, setOpenMap }), [openMap, setOpenMap]);

  return <DetailsContext.Provider value={value}>{children}</DetailsContext.Provider>;
}

function textFromSummaryNode(node) {
  if (!node?.children) {
    return '';
  }

  const summaryChild = node.children.find((child) => child.tagName === 'summary');
  if (!summaryChild) {
    return '';
  }

  const collect = (child) => {
    if (!child) {
      return '';
    }
    if (child.type === 'text') {
      return child.value;
    }
    if (Array.isArray(child.children)) {
      return child.children.map(collect).join('');
    }
    return '';
  };

  return collect(summaryChild).trim();
}

function slugify(value) {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 80);
}

function getDetailsId(node) {
  const summaryText = textFromSummaryNode(node);
  if (summaryText) {
    return slugify(summaryText);
  }

  const offset = node?.position?.start?.offset;
  if (typeof offset === 'number') {
    return `pos-${offset}`;
  }

  const line = node?.position?.start?.line ?? 0;
  const column = node?.position?.start?.column ?? 0;
  return `details-${line}-${column}`;
}

const defaultDetailsStyle = {
  marginBottom: '10px',
  border: '1px solid #34495e',
  borderRadius: '4px',
  backgroundColor: '#34495e',
};

function StatefulDetails({ node, children, style, open, onToggle, ...rest }) {
  const context = useContext(DetailsContext);
  const memorisedId = useMemo(() => getDetailsId(node), [node]);

  if (!context) {
    return (
      <details
        {...rest}
        style={{ ...defaultDetailsStyle, ...style }}
        open={open}
        onToggle={onToggle}
      >
        {children}
      </details>
    );
  }

  const { openMap, setOpenMap } = context;
  const defaultOpen = open !== undefined ? Boolean(open) : false;
  const isOpen = openMap[memorisedId] ?? defaultOpen;

  const handleToggle = (event) => {
    const element = event.currentTarget;
    setOpenMap((previous) => ({
      ...previous,
      [memorisedId]: element.open,
    }));
    if (typeof onToggle === 'function') {
      onToggle(event);
    }
  };

  return (
    <details
      {...rest}
      open={isOpen}
      onToggle={handleToggle}
      style={{ ...defaultDetailsStyle, ...style }}
    >
      {children}
    </details>
  );
}

export default function MarkdownWithStatefulDetails({
  docId,
  markdown,
  remarkPlugins,
  rehypePlugins,
  components,
}) {
  const finalRemarkPlugins = useMemo(
    () => (remarkPlugins && remarkPlugins.length > 0 ? remarkPlugins : [remarkGfm]),
    [remarkPlugins],
  );

  const finalRehypePlugins = useMemo(
    () => (rehypePlugins && rehypePlugins.length > 0 ? rehypePlugins : [rehypeRaw]),
    [rehypePlugins],
  );

  const mergedComponents = useMemo(() => {
    const { details: _ignored, ...restComponents } = components || {};
    return {
      ...restComponents,
      details: (props) => <StatefulDetails {...props} />,
    };
  }, [components]);

  return (
    <DetailsProvider docId={docId}>
      <ReactMarkdown
        remarkPlugins={finalRemarkPlugins}
        rehypePlugins={finalRehypePlugins}
        components={mergedComponents}
      >
        {markdown}
      </ReactMarkdown>
    </DetailsProvider>
  );
}
