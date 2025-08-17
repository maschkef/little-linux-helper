/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import LanguageDetector from 'i18next-browser-languagedetector';

// Import translation files
import enCommon from './locales/en/common.json';
import deCommon from './locales/de/common.json';
import enHelp from './locales/en/help.json';
import deHelp from './locales/de/help.json';

const resources = {
  en: {
    common: enCommon,
    help: enHelp
  },
  de: {
    common: deCommon,
    help: deHelp
  }
};

i18n
  .use(LanguageDetector)
  .use(initReactI18next)
  .init({
    resources,
    fallbackLng: 'en',
    debug: process.env.NODE_ENV === 'development',

    // Detection options
    detection: {
      order: ['localStorage', 'navigator', 'htmlTag'],
      caches: ['localStorage'],
      lookupLocalStorage: 'lh-gui-language'
    },

    // Namespace configuration
    defaultNS: 'common',
    ns: ['common', 'help'],

    interpolation: {
      escapeValue: false // React already does escaping
    },

    // Fallback configuration
    fallbackNS: 'common',
    
    // Load namespaces on demand
    load: 'languageOnly', // Load 'en' instead of 'en-US'
    
    // React specific options
    react: {
      useSuspense: false
    },

    // Missing key handling
    saveMissing: true,
    missingKeyHandler: (lng, ns, key, fallbackValue) => {
      console.warn(`[i18n] Missing translation key: "${key}" in namespace "${ns}" for language "${lng}"`);
      console.log(`[i18n] Fallback value: "${fallbackValue}"`);
    },

    // Return key if translation is missing (instead of empty string)
    returnEmptyString: false,
    returnNull: false,
    
    // Custom key separator to avoid conflicts
    keySeparator: '.',
    nsSeparator: ':'
  });

export default i18n;