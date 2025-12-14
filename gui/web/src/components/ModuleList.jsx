/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: Apache-2.0

This project is part of the 'little-linux-helper' collection.
Licensed under the Apache License 2.0. See the LICENSE file in the project root for more information.
*/

import React from 'react';
import { useTranslation } from 'react-i18next';

function ModuleList({ groupedModules, categories, selectedModule, onModuleSelect, onModuleStart }) {
  const { t } = useTranslation(['modules', 'common']);

  // Create a category name resolver function
  const getCategoryName = (categoryId) => {
    // Find category in the categories array
    const category = categories?.find(cat => cat.id === categoryId);
    if (category) {
      // Try translation key first
      if (category.name_key) {
        const translated = t(category.name_key, { defaultValue: null });
        if (translated) return translated;
      }
      // Fall back to fallback_name
      if (category.fallback_name) {
        return category.fallback_name;
      }
    }
    // Ultimate fallback: use category ID as display name
    return categoryId;
  };

  // Create a module name resolver function
  const getModuleName = (module) => {
    if (module.name_key) {
      const translated = t(module.name_key, { defaultValue: null });
      if (translated) return translated;
    }
    return module.name || module.id;
  };

  // Create a module description resolver function
  const getModuleDescription = (module) => {
    if (module.description_key) {
      const translated = t(module.description_key, { defaultValue: null });
      if (translated) return translated;
    }
    return module.description || '';
  };
  // Separate parent modules from submodules
  const renderModules = (modules) => {
    const parentModules = modules.filter(module => !module.parent);
    const subModules = modules.filter(module => module.parent);
    
    return parentModules.map((module) => {
      const childModules = subModules.filter(sub => sub.parent === module.id);
      
      return (
        <React.Fragment key={module.id}>
          {/* Parent module */}
          <li
            className={`module-item ${
              selectedModule?.id === module.id ? 'active' : ''
            }`}
            onClick={() => onModuleSelect(module)}
            style={{ cursor: 'pointer' }}
          >
            <div className="module-header">
              <div className="module-name">
                {getModuleName(module)}
                {module.submodule_count > 0 && (
                  <span className="submodule-badge">
                    {module.submodule_count} options
                  </span>
                )}
              </div>
              <button
                className="start-module-btn"
                onClick={(e) => {
                  e.stopPropagation();
                  onModuleStart(module);
                }}
                title="Start new session with this module"
              >
                Start
              </button>
            </div>
            <p className="module-description">{getModuleDescription(module)}</p>
          </li>
          
          {/* Child modules (submodules) */}
          {childModules.map((subModule) => (
            <li
              key={subModule.id}
              className={`module-item submodule ${
                selectedModule?.id === subModule.id ? 'active' : ''
              }`}
              onClick={() => onModuleSelect(subModule)}
              style={{
                cursor: 'pointer',
                paddingLeft: '2rem', // Indent submodules
                borderLeft: '2px solid #007acc' // Visual indicator
              }}
            >
              <div className="module-header">
                <div className="module-name">↳ {getModuleName(subModule)}</div>
                <button
                  className="start-module-btn"
                  onClick={(e) => {
                    e.stopPropagation();
                    onModuleStart(subModule);
                  }}
                  title="Start new session with this module"
                >
                  Start
                </button>
              </div>
              <p className="module-description">{getModuleDescription(subModule)}</p>
            </li>
          ))}
        </React.Fragment>
      );
    });
  };

  return (
    <div>
      <div className="panel-header">Available Modules</div>
      <ul className="module-list">
        {Object.entries(groupedModules).map(([category, modules]) => (
          <React.Fragment key={category}>
            <li className="module-category">{getCategoryName(category)}</li>
            {renderModules(modules)}
          </React.Fragment>
        ))}
      </ul>
    </div>
  );
}

export default ModuleList;
