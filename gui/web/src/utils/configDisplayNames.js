export const CONFIG_DISPLAY_KEYS = {
  'general.d/00-language.conf': 'config.generalLanguage',
  'general.d/10-logging-core.conf': 'config.generalLoggingCore',
  'general.d/20-logging-detail.conf': 'config.generalLoggingDetail',
  'general.d/30-gui.conf': 'config.generalGui',
  'general.d/40-gui-auth.conf': 'config.generalGuiAuth',
  'general.d/90-release.conf': 'config.generalRelease',
  'backup.d/00-storage.conf': 'config.backupStorage',
  'backup.d/05-excludes.conf': 'config.backupExcludes',
  'backup.d/10-retention.conf': 'config.backupRetention',
  'backup.d/20-snapshots.conf': 'config.backupSnapshots',
  'backup.d/30-subvolumes.conf': 'config.backupSubvolumes',
  'docker.d/00-discovery.conf': 'config.dockerDiscovery',
  'docker.d/10-scope.conf': 'config.dockerScope',
  'docker.d/20-warnings.conf': 'config.dockerWarnings',
  'docker.d/30-patterns.conf': 'config.dockerPatterns',
  'general.conf': 'config.generalConfig',
  'backup.conf': 'config.backupConfig',
  'docker.conf': 'config.dockerConfig'
};

export function getConfigDisplayKey(filename) {
  return CONFIG_DISPLAY_KEYS[filename] || null;
}
