/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import { useMemo } from 'react';
import { useTranslation } from 'react-i18next';

function ConfigOptionsMenu({
  forms,
  formsLoading,
  formsError,
  onReloadForms,
  selectedForm,
  onSelectForm,
  detail,
  detailLoading,
  values,
  defaults = {},
  onValueChange,
  onResetField = () => {},
  onReset,
  onSave,
  dirty,
  saving,
  success,
  error,
  advancedHidden,
  showAdvanced = false,
}) {
  const { t } = useTranslation('common');

  const groupedForms = useMemo(() => {
    const buckets = new Map();
    forms.forEach((form) => {
      const key = form.config_type || 'other';
      if (!buckets.has(key)) {
        buckets.set(key, []);
      }
      buckets.get(key).push(form);
    });

    return Array.from(buckets.entries()).map(([key, items]) => ({
      key,
      label: getCategoryLabel(key, t),
      items: items.sort((a, b) => {
        const labelA = a.display_key ? t(a.display_key) : a.display_name;
        const labelB = b.display_key ? t(b.display_key) : b.display_name;
        return labelA.localeCompare(labelB);
      }),
    }));
  }, [forms, t]);

  const renderField = (field) => {
    const rawValue = values?.[field.key];
    const value = rawValue !== undefined && rawValue !== null ? String(rawValue) : '';
    let helpText = null;
    if (field.helpKey) {
      helpText = t(field.helpKey, field.help ? { defaultValue: field.help } : {});
    } else if (field.help) {
      helpText = field.help;
    }

    const hasTemplateDefault = Object.prototype.hasOwnProperty.call(defaults, field.key);
    const schemaDefault = field.default;
    const schemaDefaultDefined = schemaDefault !== undefined && schemaDefault !== null && String(schemaDefault) !== '';
    const resolvedDefault = hasTemplateDefault
      ? defaults[field.key]
      : schemaDefaultDefined
        ? String(schemaDefault)
        : undefined;
    const defaultValue = resolvedDefault !== undefined ? String(resolvedDefault) : undefined;
    const hasDefault = defaultValue !== undefined;
    const isDifferent = hasDefault && value !== defaultValue;

    const handleReset = () => {
      if (hasDefault) {
        onResetField(field.key, defaultValue ?? '');
      }
    };

    const labelText = field.labelKey ? t(field.labelKey) : field.label;

    let control = null;
    switch (field.type) {
      case 'toggle':
        control = (
          <input
            id={field.key}
            type="checkbox"
            checked={value.toLowerCase() === 'true'}
            onChange={(e) => onValueChange(field.key, e.target.checked ? 'true' : 'false')}
          />
        );
        break;
      case 'select':
        control = (
          <select
            id={field.key}
            value={value}
            onChange={(e) => onValueChange(field.key, e.target.value)}
          >
            {field.options?.map((option) => (
              <option value={option.value} key={option.value}>
                {option.labelKey ? t(option.labelKey) : option.label}
              </option>
            ))}
          </select>
        );
        break;
      case 'textarea':
        control = (
          <textarea
            id={field.key}
            rows={4}
            value={value}
            onChange={(e) => onValueChange(field.key, e.target.value)}
            placeholder={field.placeholderKey ? t(field.placeholderKey) : field.placeholder}
            spellCheck={false}
          />
        );
        break;
      case 'number':
        control = (
          <input
            id={field.key}
            type="number"
            value={value}
            onChange={(e) => onValueChange(field.key, e.target.value)}
            min={field.min !== undefined ? field.min : undefined}
            max={field.max !== undefined ? field.max : undefined}
          />
        );
        break;
      default:
        control = (
          <input
            id={field.key}
            type="text"
            value={value}
            onChange={(e) => onValueChange(field.key, e.target.value)}
            placeholder={field.placeholderKey ? t(field.placeholderKey) : field.placeholder}
            spellCheck={false}
          />
        );
        break;
    }

    return (
      <div className={`config-field ${field.type === 'toggle' ? 'field-toggle' : ''}`} key={field.key}>
        <div className="field-header">
          <label htmlFor={field.key}>{labelText}</label>
          {hasDefault && (
            <button
              type="button"
              className="reset-field-button"
              onClick={handleReset}
              disabled={!isDifferent}
            >
              {t('config.resetDefault')}
            </button>
          )}
        </div>
        <div className="field-control">
          {control}
        </div>
        {helpText && <div className="field-help">{helpText}</div>}
      </div>
    );
  };

  if (formsLoading) {
    return (
      <div className="config-options loading">
        <div className="loading-text">{t('common.loading')}</div>
      </div>
    );
  }

  if (formsError) {
    return (
      <div className="config-options error">
        <div className="error-message">
          <span className="error-icon">⚠️</span>
          {formsError}
        </div>
        <button className="retry-button" onClick={onReloadForms}>
          {t('common.retry')}
        </button>
      </div>
    );
  }

  if (!forms.length) {
    return (
      <div className="config-options empty">
        <p>{t('config.noFormsAvailable')}</p>
      </div>
    );
  }

  const visibleGroups = (detail?.groups || []).filter(
    (group) => showAdvanced || !group.advanced
  );

  return (
    <div className="config-options">
      <div className="config-options-sidebar">
        {groupedForms.map((group) => (
          <div className="config-options-group" key={group.key}>
            <div className="config-options-group-title">{group.label}</div>
            <ul className="config-options-list">
              {group.items.map((form) => (
                <li key={form.filename}>
                  <button
                    className={`config-options-item ${form.filename === selectedForm ? 'active' : ''}`}
                    onClick={() => onSelectForm(form.filename)}
                  >
                    {form.display_key ? t(form.display_key) : form.display_name}
                    {form.advanced && <span className="badge-advanced">{t('config.advancedBadge')}</span>}
                  </button>
                </li>
              ))}
            </ul>
          </div>
        ))}
        {advancedHidden && (
          <div className="config-options-hint">
            {t('config.enableAdvancedToggle')}
          </div>
        )}
      </div>

      <div className="config-options-editor">
        {detailLoading && (
          <div className="config-options-placeholder">
            <div className="loading-text">{t('common.loading')}</div>
          </div>
        )}

        {!detailLoading && !detail && (
          <div className="config-options-placeholder">
            <p>{t('config.selectFormPrompt')}</p>
          </div>
        )}

        {!detailLoading && detail && (
          <>
            <div className="config-options-header">
              <h3>{detail.display_key ? t(detail.display_key) : detail.display_name}</h3>
              {(detail.description_key || detail.description) && (
                <p className="config-options-description">
                  {detail.description_key ? t(detail.description_key) : detail.description}
                </p>
              )}
            </div>

            {error && (
              <div className="error-message">
                <span className="error-icon">⚠️</span>
                {error}
              </div>
            )}

            {success && (
              <div className="success-message">
                <span className="success-icon">✅</span>
                {success}
              </div>
            )}

            <div className="config-options-groups">
              {visibleGroups.map((group, index) => {
                const visibleFields = group.fields.filter(
                  (field) => showAdvanced || !field.advanced
                );
                if (visibleFields.length === 0) {
                  return null;
                }
                return (
                  <div className="config-options-section" key={`${group.title || 'group'}-${index}`}>
                    {group.title && (
                      <h4>
                        {group.titleKey ? t(group.titleKey) : group.title}
                      </h4>
                    )}
                    {group.description && (
                      <p className="section-description">
                        {group.descriptionKey ? t(group.descriptionKey) : group.description}
                      </p>
                    )}
                    <div className="config-fields">
                      {visibleFields.map(renderField)}
                    </div>
                  </div>
                );
              })}
            </div>

            <div className="config-options-actions">
              <button
                className="reset-button"
                onClick={onReset}
                disabled={!dirty && !error}
              >
                {t('config.reset')}
              </button>
              <button
                className="save-button"
                onClick={onSave}
                disabled={!dirty || saving}
              >
                {saving ? t('common.saving') : t('common.save')}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

function getCategoryLabel(key, t) {
  switch (key) {
    case 'general':
      return t('config.groupGeneral');
    case 'backup':
      return t('config.groupBackup');
    case 'docker':
      return t('config.groupDocker');
    default:
      return t('config.groupOther');
  }
}

export default ConfigOptionsMenu;
