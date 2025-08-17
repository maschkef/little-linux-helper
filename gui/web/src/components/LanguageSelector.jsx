/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import React from 'react';
import { useTranslation } from 'react-i18next';

const languages = [
  { code: 'en', name: 'English', flag: '🇺🇸' },
  { code: 'de', name: 'Deutsch', flag: '🇩🇪' }
];

function LanguageSelector() {
  const { i18n, t } = useTranslation();

  const changeLanguage = (languageCode) => {
    i18n.changeLanguage(languageCode);
    // Store in localStorage for persistence
    localStorage.setItem('lh-gui-language', languageCode);
  };

  return (
    <div className="language-selector" style={{
      display: 'flex',
      alignItems: 'center',
      gap: '8px',
      color: '#ecf0f1',
      fontSize: '14px'
    }}>
      <span>🌐</span>
      <select 
        value={i18n.language} 
        onChange={(e) => changeLanguage(e.target.value)}
        style={{
          backgroundColor: '#34495e',
          color: '#ecf0f1',
          border: '1px solid #5a6c7d',
          borderRadius: '4px',
          padding: '4px 8px',
          fontSize: '12px',
          outline: 'none',
          cursor: 'pointer'
        }}
      >
        {languages.map((lang) => (
          <option key={lang.code} value={lang.code}>
            {lang.flag} {lang.name}
          </option>
        ))}
      </select>
    </div>
  );
}

export default LanguageSelector;