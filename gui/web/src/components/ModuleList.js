/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import React from 'react';

function ModuleList({ groupedModules, selectedModule, onModuleSelect, sessionStatus }) {
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
            onClick={() => {
              if (sessionStatus !== 'running') {
                onModuleSelect(module);
              }
            }}
            style={{
              cursor: sessionStatus === 'running' ? 'not-allowed' : 'pointer',
              opacity: sessionStatus === 'running' && selectedModule?.id !== module.id ? 0.5 : 1
            }}
          >
            <div className="module-name">
              {module.name}
              {module.submodule_count > 0 && (
                <span className="submodule-badge">
                  {module.submodule_count} options
                </span>
              )}
            </div>
            <p className="module-description">{module.description}</p>
          </li>
          
          {/* Child modules (submodules) */}
          {childModules.map((subModule) => (
            <li
              key={subModule.id}
              className={`module-item submodule ${
                selectedModule?.id === subModule.id ? 'active' : ''
              }`}
              onClick={() => {
                if (sessionStatus !== 'running') {
                  onModuleSelect(subModule);
                }
              }}
              style={{
                cursor: sessionStatus === 'running' ? 'not-allowed' : 'pointer',
                opacity: sessionStatus === 'running' && selectedModule?.id !== subModule.id ? 0.5 : 1,
                paddingLeft: '2rem', // Indent submodules
                borderLeft: '2px solid #007acc' // Visual indicator
              }}
            >
              <div className="module-name">↳ {subModule.name}</div>
              <p className="module-description">{subModule.description}</p>
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
            <li className="module-category">{category}</li>
            {renderModules(modules)}
          </React.Fragment>
        ))}
      </ul>
    </div>
  );
}

export default ModuleList;
